#!/bin/bash
#shellcheck disable=SC2312  # Consider invoking this command separately to avoid masking its return value
#shellcheck disable=SC2154  # $VAR is referenced but not assigned

global_MACOS_VSN=$1
global_INSTALL_DIR=${RUNNER_TEMP}/otp

# Helper functions

cd_install_dir() {
    cd "${global_INSTALL_DIR}" || exit
}

set_initial_dir() {
    global_INITIAL_DIR=${PWD}
}

cd_initial_dir() {
    cd "${global_INITIAL_DIR}" || exit
}

set_kerl_dir() {
    global_KERL_DIR=${PWD}
}

cd_kerl_dir() {
    cd "${global_KERL_DIR}" || exit
}

prepare_git_tag() {
    local otp_vsn=$1

    # The format used for the Git tags
    global_GIT_TAG=macos64-${global_MACOS_VSN}/OTP-${otp_vsn}
}

prepare_filename_no_ext() {
    local otp_vsn=$1

    # The format used for the generated filenames
    global_FILENAME_NO_EXT=macos64-${global_MACOS_VSN}-OTP-${otp_vsn}
}

prepare_filename_tar_gz() {
    local otp_vsn=$1

    prepare_filename_no_ext "${otp_vsn}"
    global_FILENAME_TAR_GZ=${global_FILENAME_NO_EXT}.tar.gz
}

prepare_filename_sha256_txt() {
    local otp_vsn=$1

    prepare_filename_no_ext "${otp_vsn}"
    global_FILENAME_SHA256_TXT=${global_FILENAME_NO_EXT}.sha256.txt
}

prepare_tar_gz_path() {
    local otp_vsn=$1

    prepare_filename_tar_gz "${otp_vsn}"
    global_TAR_GZ_PATH=${global_INSTALL_DIR}/${global_FILENAME_TAR_GZ}
}

prepare_sha256_txt_path() {
    local otp_vsn=$1

    prepare_filename_sha256_txt "${otp_vsn}"
    global_SHA256_TXT_PATH=${global_INSTALL_DIR}/${global_FILENAME_SHA256_TXT}
}

# Workflow groups

homebrew_install() {
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}
echo "::group::Homebrew: install"
homebrew_install
set_initial_dir
echo "::endgroup::"

kerl_checkout() {
    git clone https://github.com/kerl/kerl
    cd kerl || exit
}
echo "::group::kerl: checkout"
kerl_checkout
set_kerl_dir
echo "::endgroup::"

kerl_configure() {
    ./kerl update releases

    MAKEFLAGS="-j$(getconf _NPROCESSORS_ONLN)"
    export MAKEFLAGS

    KERL_BUILD_DOCS=yes
    export KERL_BUILD_DOCS

    echo OpenSSL is "$(openssl version)"
}
echo "::group::kerl: configure"
cd_kerl_dir
kerl_configure
echo "::endgroup::"

pick_otp_vsn() {
    global_OTP_VSN=undefined
    while read -r release; do
        prepare_git_tag "${release}"

        if grep "${global_GIT_TAG} " _RELEASES; then
            continue
        fi

        global_OTP_VSN=${release}
        break
    done < <(./kerl update releases | tail -n 70)
    if [[ "${global_OTP_VSN}" == "undefined" ]]; then
        echo "  nothing to build. Exiting..."
        echo "::endgroup::"
        exit 0
    fi
    echo "  picked OTP ${global_OTP_VSN}"
}
echo "::group::Erlang/OTP: pick version to build"
cd_kerl_dir
pick_otp_vsn
echo "::endgroup::"

kerl_build_install() {
    KERL_DEBUG=true ./kerl build-install "${global_OTP_VSN}" "${global_OTP_VSN}" "${global_INSTALL_DIR}"
}
echo "::group::kerl: build-install"
cd_kerl_dir
kerl_build_install
echo "::endgroup::"

kerl_test() {
    ./bin/erl -s crypto -s init stop
    ./bin/erl_call
}
echo "::group::kerl: test build result"
cd_install_dir
kerl_test
echo "::endgroup::"

release_prepare() {
    prepare_filename_tar_gz "${global_OTP_VSN}"
    prepare_filename_sha256_txt "${global_OTP_VSN}"

    tar -vzcf "${global_FILENAME_TAR_GZ}" ./*
    shasum -a 256 "${global_FILENAME_TAR_GZ}" >"${global_FILENAME_SHA256_TXT}"
}
echo "::group::Release: prepare"
cd_install_dir
release_prepare
echo "::endgroup::"

_releases_update() {
    #if [[ "${GITHUB_REF_NAME}" == "main" ]]; then
        prepare_filename_no_ext "${global_OTP_VSN}"
        prepare_tar_gz_path "${global_OTP_VSN}"

        crc32=$(crc32 "${global_TAR_GZ_PATH}")
        date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        echo "${global_FILENAME_NO_EXT} ${crc32} ${date}" >>_RELEASES
        sort -o _RELEASES _RELEASES

        release_name="release/${global_FILENAME_NO_EXT}"
        git config user.name "GitHub Actions"
        git config user.email "actions@user.noreply.github.com"
        git add _RELEASES
        git switch -c releases "${release_name}"
        git commit -m "Update _RELEASES: ${global_FILENAME_NO_EXT}"
        git push origin "${release_name}"
        pr=$(gh pr create -B main -t "Automation: update _RELEASES for ${global_FILENAME_NO_EXT}")
        gh pr review "${pr}" -a
        gh pr merge "${pr}" --admin --auto
        git switch main
    #else
    #    echo "Skipping branch ${GITHUB_REF_NAME} (runs in main alone)"
    #fi
}
echo "::group::_RELEASES: update"
cd_initial_dir
_releases_update
echo "::endgroup::"

config_build_outputs() {
    prepare_tar_gz_path "${global_OTP_VSN}"
    prepare_sha256_txt_path "${global_OTP_VSN}"
    prepare_git_tag "${global_OTP_VSN}"

    {
        echo "otp_vsn=${global_OTP_VSN}"
        echo "tar_gz=${global_TAR_GZ_PATH}"
        echo "sha256_txt=${global_SHA256_TXT_PATH}"
        echo "git_tag=${global_GIT_TAG}"
        echo "target_commitish=$(git log -n 1 --pretty=format:"%H")"
    } >>"${GITHUB_OUTPUT}"
    cat "${GITHUB_OUTPUT}"
}
echo "::group::Configure and build: outputs"
cd_initial_dir
config_build_outputs
echo "::endgroup::"
