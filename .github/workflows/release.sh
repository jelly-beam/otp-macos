#!/bin/bash
#shellcheck disable=SC1091 # Not following: ./activate was not specified as input.

macos_vsn=$1

INSTALL_DIR=$RUNNER_TEMP/otp

homebrew_install() {
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}
echo "::group::Homebrew: install"
homebrew_install
echo "::endgroup::"

kerl_checkout() {
    git clone https://github.com/kerl/kerl
    cd kerl || exit
}
echo "::group::Kerl: checkout"
kerl_checkout
echo "::endgroup::"

kerl_configure() {
    ./kerl update releases
    MAKEFLAGS="-j$(getconf _NPROCESSORS_ONLN)"
    export MAKEFLAGS
    KERL_BUILD_DOCS="yes"
    export KERL_BUILD_DOCS
    echo "OpenSSL is $(openssl version)"
}
echo "::group::Kerl: configure"
kerl_configure
echo "::endgroup::"

pick_otp_vsn() {
    OTP_VSN=undefined
    while read -r release; do
        if git show-ref --tags --verify --quiet "refs/tags/macos64-${macos_vsn}-OTP-${release}"; then
            continue
        fi
        OTP_VSN=$release
        break
    done < <(./kerl update releases | tail -n 70)
    if [ "$OTP_VSN" == "undefined" ]; then
        echo "  nothing to build. Exiting..."
        echo "::endgroup::"
        exit 0
    fi
    echo "  picked OTP $OTP_VSN"
    export OTP_VSN
}
echo "::group::Erlang/OTP: pick version to build"
pick_otp_vsn
echo "::endgroup::"

kerl_build_install() {
    KERL_DEBUG=true ./kerl build-install "$OTP_VSN" "$OTP_VSN" "$INSTALL_DIR"
}
echo "::group::Kerl: build-install"
kerl_build_install
echo "::endgroup::"

kerl_test() {
    cd "$INSTALL_DIR" || exit
    ./bin/erl -s crypto -s init stop
    ./bin/erl_call
}
echo "::group::Kerl: test build result"
kerl_test
echo "::endgroup::"

tar_archive() {
    file="macos64-${macos_vsn}-OTP-${OTP_VSN}.tar.gz"
    tar -vzcf "$file" ./*
    shasum -a 256  "$file" > "${macos_vsn}-OTP-${OTP_VSN}-sha256.txt"
}
echo "::group::tar: archive"
tar_archive
echo "::endgroup::"

echo "otp_vsn=${OTP_VSN}" >>"$GITHUB_OUTPUT"
