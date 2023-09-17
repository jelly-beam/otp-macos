#!/bin/bash

macos_vsn=$1

global_INSTALL_DIR=$RUNNER_TEMP/otp

# Helper functions

cd_install_dir() {
    cd "$global_INSTALL_DIR" || exit
}

set_initial_dir() {
    global_BASE_DIR="$PWD"
}

cd_initial_dir() {
    cd "$global_BASE_DIR" || exit
}

set_kerl_dir() {
    global_KERL_DIR="$PWD"
}

cd_kerl_dir() {
    cd "$global_KERL_DIR" || exit
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
    KERL_BUILD_DOCS="yes"
    export KERL_BUILD_DOCS
    echo "OpenSSL is $(openssl version)"
}
echo "::group::kerl: configure"
cd_kerl_dir
kerl_configure
echo "::endgroup::"

pick_otp_vsn() {
    global_OTP_VSN=undefined
    while read -r release; do
        if git show-ref --tags --verify --quiet "refs/tags/macos64-${macos_vsn}-OTP-${release}"; then
            continue
        fi
        global_OTP_VSN=$release
        break
    done < <(./kerl update releases | tail -n 70)
    if [ "$global_OTP_VSN" == "undefined" ]; then
        echo "  nothing to build. Exiting..."
        echo "::endgroup::"
        exit 0
    fi
    echo "  picked OTP $global_OTP_VSN"
}
echo "::group::Erlang/OTP: pick version to build"
cd_kerl_dir
pick_otp_vsn
echo "::endgroup::"

kerl_build_install() {
    KERL_DEBUG=true ./kerl build-install "$global_OTP_VSN" "$global_OTP_VSN" "$INSTALL_DIR"
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
    file="macos64-${macos_vsn}-OTP-${global_OTP_VSN}.tar.gz"
    tar -vzcf "$file" ./*
    shasum -a 256 "$file" >"macos64-${macos_vsn}-OTP-${global_OTP_VSN}.sha256.txt"
}
echo "::group::Release: prepare"
cd_install_dir
release_prepare
echo "::endgroup::"

_releases_update() {
    if [ "$GITHUB_REF" == "refs/heads/main" ]; then
        filename_no_ext="macos64-${macos_vsn}-OTP-${global_OTP_VSN}"

        crc32=$(crc32 "$INSTALL_DIR"/"$filename_no_ext.tar.gz")
        date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        echo "$filename_no_ext $crc32 $date" >>_RELEASES

        sort -o _RELEASES _RELEASES

        git config user.name "GitHub Actions"
        git config user.email "actions@user.noreply.github.com"
        git add _RELEASES
        git commit -m "Update _RELEASES: $filename_no_ext"
        git push origin "$GITHUB_REF_NAME"
    else
        echo "Skipping branch $GITHUB_REF (runs in main alone)"
    fi
}
echo "::group::_RELEASES: update"
cd_initial_dir
_releases_update
echo "::endgroup::"

config_build_outputs() {
    cd "$global_BASE_DIR" || exit
    {
        echo "otp_vsn=$global_OTP_VSN"
        echo "tar_gz=${INSTALL_DIR}/macos64-${macos_vsn}-OTP-${global_OTP_VSN}.tar.gz"
        echo "sha256_txt=${INSTALL_DIR}/macos64-${macos_vsn}-OTP-${global_OTP_VSN}.sha256.txt"
        echo "target_commitish=$(git log -n 1 --pretty=format:"%H")"
    } >>"$GITHUB_OUTPUT"
}
echo "::group::Configure and build: outputs"
cd_initial_dir
config_build_outputs
echo "::endgroup::"
