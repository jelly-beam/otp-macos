#!/bin/bash

macos_vsn=$1

INSTALL_DIR=$RUNNER_TEMP/otp

echo_pwd() {
    echo "pwd: $PWD"
}

homebrew_install() {
    echo_pwd
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}
echo "::group::Homebrew: install"
homebrew_install
echo "::endgroup::"

kerl_checkout() {
    echo_pwd
    git clone https://github.com/kerl/kerl
    cd kerl || exit
}
echo "::group::kerl: checkout"
kerl_checkout
echo "::endgroup::"

kerl_configure() {
    echo_pwd
    ./kerl update releases
    MAKEFLAGS="-j$(getconf _NPROCESSORS_ONLN)"
    export MAKEFLAGS
    KERL_BUILD_DOCS="yes"
    export KERL_BUILD_DOCS
    echo "OpenSSL is $(openssl version)"
}
echo "::group::kerl: configure"
kerl_configure
echo "::endgroup::"

pick_otp_vsn() {
    echo_pwd
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
pick_otp_vsn
echo "::endgroup::"

kerl_build_install() {
    echo_pwd
    KERL_DEBUG=true ./kerl build-install "$global_OTP_VSN" "$global_OTP_VSN" "$INSTALL_DIR"
}
echo "::group::kerl: build-install"
kerl_build_install
echo "::endgroup::"

kerl_test() {
    echo_pwd
    cd "$INSTALL_DIR" || exit
    ./bin/erl -s crypto -s init stop
    ./bin/erl_call
}
echo "::group::kerl: test build result"
kerl_test
echo "::endgroup::"

release_prepare() {
    echo_pwd
    file="macos64-${macos_vsn}-OTP-${global_OTP_VSN}.tar.gz"
    tar -vzcf "$file" ./*
    shasum -a 256 "$file" >"macos64-${macos_vsn}-OTP-${global_OTP_VSN}.sha256.txt"
}
echo "::group::Release: prepare"
release_prepare
echo "::endgroup::"

_releases_update() {
    echo_pwd
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
_releases_update
echo "::endgroup::"

config_build_outputs() {
    echo_pwd
    {
        echo "otp_vsn=$global_OTP_VSN"
        echo "tar_gz=${INSTALL_DIR}/macos64-${macos_vsn}-OTP-${global_OTP_VSN}.tar.gz"
        echo "sha256_txt=${INSTALL_DIR}/macos64-${macos_vsn}-OTP-${global_OTP_VSN}.sha256.txt"
        echo "target_commitish=$(git log -n 1 --pretty=format:"%H")"
    } >>"$GITHUB_OUTPUT"
}
echo "::group::Configure and build: outputs"
config_build_outputs
echo "::endgroup::"
