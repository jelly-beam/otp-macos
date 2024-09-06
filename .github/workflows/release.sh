#!/bin/bash
#shellcheck disable=SC2154  # $VAR is referenced but not assigned

global_DARWIN64_VSN=$1
global_OTP_VSN=$2
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
    echo "darwin64-${global_DARWIN64_VSN}/OTP-$1"
}

filename_no_ext_for() {
    # $1: OTP version

    # The format used for the generated filenames
    echo "darwin64-${global_DARWIN64_VSN}_OTP-$1"
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

is_nightly_otp_for() {
    # $1: OTP version

    local nightly_otp_targets
    nightly_otp_targets=("master" "maint")
    if [[ ${nightly_otp_targets[*]} =~ $1 ]]; then
        echo true
    else
        echo false
    fi
}

export_kerl_configuration_option() {
    # $1: configuration option

    KERL_CONFIGURE_OPTIONS="${KERL_CONFIGURE_OPTIONS:-} $1"
    export KERL_CONFIGURE_OPTIONS
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

    export_kerl_configuration_option "--disable-dynamic-ssl-lib"
    local with_ssl
    with_ssl="$(brew --prefix openssl@3.0)"
    export_kerl_configuration_option "--with-ssl=${with_ssl}"

    local openssl_version
    openssl_version=$(openssl version)
    echo "OpenSSL is ${openssl_version}"
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

    # Search for oldest supported version from latest available
    while read -r release; do
        # Avoid release candidates, while searching for latest
        if [[ ${release} =~ ^[0-9].*$ ]] && ! [[ ${release} =~ -rc ]]; then
            local latest=${release%%.*}
            echo "Found latest major version to be ${latest}"
            oldest_supported=$((latest - 2))
            echo "  thus the oldest support version (per our support policy) is ${oldest_supported}"
            break
        fi
    done <<<"${kerl_releases_reversed}"

    # Search for a version to apply the pipeline to
    while read -r release; do
        if [[ ${release} =~ ^[0-9].*$ ]]; then
            local major=${release%%.*}
            local minor=${release#*.}
            minor=${minor%%.*}
            if [[ ${oldest_supported} == undefined ]]; then
                echo "Couldn't determine oldest support version. Exiting..."
                echo "::endgroup::"
                exit 1
            fi

            if [[ ${major} -lt ${oldest_supported} ]] || { [[ ${major} -eq 25 ]] && [[ ${minor} -lt 1 ]]; }; then
                continue
            fi

            local filename_no_ext
            filename_no_ext=$(filename_no_ext_for "${release}")

            pushd "${global_INITIAL_DIR}" >/dev/null || exit 1
            if [[ -f _RELEASES ]]; then
                local found
                found=$(grep "${filename_no_ext} " _RELEASES)
                if [[ -n "${found}" ]]; then
                    continue
                fi
            fi
            popd >/dev/null || exit 1

            global_OTP_VSN=${release}
            break
        fi
    done <<<"${kerl_releases}"

    if [[ "${global_OTP_VSN}" == undefined ]]; then
        echo "Nothing to build. Exiting..."
        echo "::endgroup::"
        exit 0
    fi
}
echo "::group::Erlang/OTP: pick version to build"
cd_kerl_dir
global_IS_NIGHTLY_OTP=$(is_nightly_otp_for "${global_OTP_VSN}")
if [[ ${global_IS_NIGHTLY_OTP} == false ]]; then
    pick_otp_vsn
fi
echo "Picked OTP ${global_OTP_VSN}"
echo "::endgroup::"

kerl_build_install() {
    # $1: OTP version

    if [[ ${global_IS_NIGHTLY_OTP} == false ]]; then
        KERL_DEBUG=true ./kerl build-install "$1" "$1" "${global_INSTALL_DIR}"
    else
        KERL_DEBUG=true ./kerl build-install git https://github.com/erlang/otp.git "$1" "$1" "${global_INSTALL_DIR}"
    fi
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

        touch _RELEASES
        local update_releases_prefix
        local release_was_found
        release_was_found=$(grep "${filename_no_ext} " _RELEASES)
        if [[ -z "${release_was_found}" ]]; then
            echo "${filename_no_ext} ${crc32} ${date}" >>_RELEASES
            update_releases_prefix="add"
        fi

        git config user.name "GitHub Actions"
        git config user.email "actions@user.noreply.github.com"

        local release_name="release/${filename_no_ext}"
        if [[ ${global_IS_NIGHTLY_OTP} == true ]]; then
            if [[ -n "${release_was_found}" ]]; then
                # Replace (inline) in previously existing file (this is a special target)
                sed -i -e "s|${filename_no_ext} \(.*\)|${filename_no_ext} ${crc32} ${date}|g" _RELEASES
                update_releases_prefix="replace"
            fi

            # This is not atomic and might fail, but that's the cost of bleeding edge
            local git_tag
            git_tag=$(git_tag_for "$1")
            gh release delete "${git_tag}" --cleanup-tag --yes || true
            git branch -D "${release_name}" || true
            git push origin --delete "${release_name}" || true
        fi
        sort -o _RELEASES _RELEASES

        git switch -c "${release_name}"
        git add _RELEASES
        rm -rf kerl

        local commit_msg="Update _RELEASES: ${update_releases_prefix} ${filename_no_ext}"
        git commit -m "${commit_msg}"
        git push origin "${release_name}"

        # A non-nightly version gets updated in the main branch
        # A nightly version gets updated in a special (moving target) branch
        if [[ ${global_IS_NIGHTLY_OTP} == false ]]; then
            local pr
            pr=$(gh pr create -B main -t "[automation] ${commit_msg}" -b "🔒 tight, tight, tight!")
            gh pr merge "${pr}" -s
            git switch main
        fi

        git pull # Otherwise the latest commit is not picked up
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

    local target_commitish
    target_commitish=$(git log -n 1 --pretty=format:"%H")

    {
        echo "otp_vsn=$1"
        echo "tar_gz=${tar_gz_path}"
        echo "sha256_txt=${sha256_txt_path}"
        echo "git_tag=${git_tag}"
        echo "target_commitish=${target_commitish}"
    } >>"${GITHUB_OUTPUT}"
    cat "${GITHUB_OUTPUT}"
}
echo "::group::Configure and build: outputs"
cd_initial_dir
config_build_outputs "${global_OTP_VSN}"
echo "::endgroup::"
