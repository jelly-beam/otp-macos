#!/bin/bash
#shellcheck disable=SC2154  # $VAR is referenced but not assigned

global_MACOS_VSN=$1
global_INSTALL_DIR=${RUNNER_TEMP}/otp

# Helper functions

cd_install_dir() {
    cd "${global_INSTALL_DIR}" || exit 1
}

set_initial_dir() {
    global_INITIAL_DIR=${PWD}
}

cd_initial_dir() {
    cd "${global_INITIAL_DIR}" || exit 1
}

set_kerl_dir() {
    global_KERL_DIR=${PWD}
}

cd_kerl_dir() {
    cd "${global_KERL_DIR}" || exit 1
}

git_tag_for() {
    # $1: OTP version

    # The format used for the Git tags
    echo "macos64-${global_MACOS_VSN}/OTP-$1"
}

filename_no_ext_for() {
    # $1: OTP version

    # The format used for the generated filenames
    echo "macos64-${global_MACOS_VSN}_OTP-$1"
}

filename_tar_gz_for() {
    # $1: OTP version

    local filename_no_ext
    filename_no_ext=$(filename_no_ext_for "$1")
    echo "${filename_no_ext}.tar.gz"
}

filename_sha256_txt_for() {
    # $1: OTP version

    local filename_no_ext
    filename_no_ext=$(filename_no_ext_for "$1")
    echo "${filename_no_ext}.sha256.txt"
}

tar_gz_path_for() {
    # $1: OTP version

    local filename_tar_gz
    filename_tar_gz=$(filename_tar_gz_for "$1")
    echo "${global_INSTALL_DIR}/${filename_tar_gz}"
}

sha256_txt_path_for() {
    # $1: OTP version

    local filename_sha256_txt
    filename_sha256_txt=$(filename_sha256_txt_for "$1")
    echo "${global_INSTALL_DIR}/${filename_sha256_txt}"
}

# Workflow groups

homebrew_install() {
    local install_sh
    install_sh=$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)
    /bin/bash -c "${install_sh}"
}
echo "::group::Homebrew: install"
homebrew_install
set_initial_dir
echo "::endgroup::"

kerl_checkout() {
    git clone https://github.com/kerl/kerl
    cd kerl || exit 1
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

    local openssl_version
    openssl_version=$(openssl version)
    echo OpenSSL is "${openssl_version}"
}
echo "::group::kerl: configure"
cd_kerl_dir
kerl_configure
echo "::endgroup::"

pick_otp_vsn() {
    global_OTP_VSN=undefined
    local oldest_supported=undefined
    local kerl_releases
    kerl_releases=$(./kerl list releases all)
    local kerl_releases_reversed
    kerl_releases_reversed=$(echo "${kerl_releases}" | sort -r)
    while read -r release; do
        if [[ ${release} =~ ^[0-9].*$ ]]; then
            local high=${release%%.*}
            echo "  Found latest major version to be ${high}"
            oldest_supported=$((high - 2))
            echo "    thus the oldest support version (per our support policy) is ${oldest_supported}"
            break
        fi
    done <<<"${kerl_releases_reversed}"

    while read -r release; do
        if [[ ${release} =~ ^[0-9].*$ ]]; then
            local major=${release%%.*}
            if [[ ${oldest_supported} == undefined ]]; then
                echo "  Couldn't determine oldest support version. Exiting..."
                exit 1
            fi
            if [[ ${major} -lt ${oldest_supported} ]]; then
                continue
            fi

            local filename_no_ext
            filename_no_ext=$(filename_no_ext_for "${release}")
            pushd "${global_INITIAL_DIR}" || exit 1
            echo "  Searching for ${filename_no_ext} in _RELEASES..."
            if test -f _RELEASES && grep "${filename_no_ext} " _RELEASES; then
                continue
            fi
            popd || exit 1

            global_OTP_VSN=${release}
            break
        fi
    done <<<"${kerl_releases}"
    if [[ "${global_OTP_VSN}" == undefined ]]; then
        echo "  Nothing to build. Exiting..."
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
    # $1: OTP version

    KERL_DEBUG=true ./kerl build-install "$1" "$1" "${global_INSTALL_DIR}"
}
echo "::group::kerl: build-install"
cd_kerl_dir
kerl_build_install "${global_OTP_VSN}"
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
    # $1: OTP version

    local filename_tar_gz
    filename_tar_gz=$(filename_tar_gz_for "$1")
    local filename_sha256_txt
    filename_sha256_txt=$(filename_sha256_txt_for "$1")

    tar -vzcf "${filename_tar_gz}" ./*
    shasum -a 256 "${filename_tar_gz}" >"${filename_sha256_txt}"
}
echo "::group::Release: prepare"
cd_install_dir
release_prepare "${global_OTP_VSN}"
echo "::endgroup::"

_releases_update() {
    # $1: OTP version

    if [[ "${GITHUB_REF_NAME}" == main ]]; then
        local filename_no_ext
        filename_no_ext=$(filename_no_ext_for "$1")
        local tar_gz_path
        tar_gz_path=$(tar_gz_path_for "$1")

        local crc32
        crc32=$(crc32 "${tar_gz_path}")
        local date
        date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        echo "${filename_no_ext} ${crc32} ${date}" >>_RELEASES
        sort -o _RELEASES _RELEASES

        local release_name="release/${filename_no_ext}"
        git config user.name "GitHub Actions"
        git config user.email "actions@user.noreply.github.com"
        git switch -c "${release_name}"
        git add _RELEASES
        local commit_msg="Update _RELEASES: add ${filename_no_ext}"
        git commit -m "${commit_msg}"
        git push origin "${release_name}"
        local pr
        pr=$(gh pr create -B main -t "[automation] ${commit_msg}" -b "🔒 tight, tight, tight!")
        gh pr merge "${pr}" -s
        git switch main
    else
        echo "Skipping branch ${GITHUB_REF_NAME} (runs in main alone)"
    fi
}
echo "::group::_RELEASES: update"
cd_initial_dir
_releases_update "${global_OTP_VSN}"
echo "::endgroup::"

config_build_outputs() {
    # $1: OTP version

    local tar_gz_path
    tar_gz_path=$(tar_gz_path_for "$1")
    local sha256_txt_path
    sha256_txt_path=$(sha256_txt_path_for "$1")
    local git_tag
    git_tag=$(git_tag_for "$1")

    {
        echo "otp_vsn=$1"
        echo "tar_gz=${tar_gz_path}"
        echo "sha256_txt=${sha256_txt_path}"
        echo "git_tag=${git_tag}"
        local target_commitish
        target_commitish=$(git log -n 1 --pretty=format:"%H")
        echo "target_commitish=${target_commitish}"
    } >>"${GITHUB_OUTPUT}"
    cat "${GITHUB_OUTPUT}"
}
echo "::group::Configure and build: outputs"
cd_initial_dir
config_build_outputs "${global_OTP_VSN}"
echo "::endgroup::"
