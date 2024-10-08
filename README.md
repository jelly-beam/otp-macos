# `otp-macos` [![Release][release-img]][release] [![Nightly][nightly-img]][nightly]

[release]: https://github.com/jelly-beam/otp-macos/actions/workflows/release.yml?query=branch%3Amain
[release-img]: https://github.com/jelly-beam/otp-macos/actions/workflows/release.yml/badge.svg?branch=main
[nightly]: https://github.com/jelly-beam/otp-macos/actions/workflows/nightly.yml?query=branch%3Amain
[nightly-img]: https://github.com/jelly-beam/otp-macos/actions/workflows/nightly.yml/badge.svg?branch=main

`otp-macos` is a living, and up-to-date, collection of precompiled macOS-ready Erlang/OTP versions.

It was initially created to support macOS on <https://github.com/erlef/setup-beam> builds.

We aim to build all Erlang versions (at most one every 2 hours - for all OS versions) starting from
Erlang/OTP 25.1, and targeting macOS for the versions supported by GitHub Actions (13, 14, and 15
at the time of this writing).

We also aim to build from `master` and `maint[-*]`, nightly, mostly to allow consumers to be on the
edge, but also to test potential upcoming issues with the image build/release pipeline. These
versions will remain in (moving target) branches with their copy of `_RELEASES`, but won't see
an update for their version in the main branch's `_RELEASES`.

**Note**: `[-*]` is either `""` or `-<supported_version>`.

## The build/release pipeline

We build the Erlang/OTP images using a mix of [Homebrew](https://brew.sh/) and
[kerl](https://github.com/kerl/kerl), as well as some 3rd party actions. For security reasons, we
aim to stop depending on these in the future.

### Documentation chunks

The images are built with documentation chunks as per `make docs DOC_TARGETS=chunks`.

### OpenSSL

The images are built with static OpenSSL linking, via
`--disable-dynamic-ssl-lib --with-ssl=$(command -v openssl)/../..`.

### Releases

Releases are tagged as `darwin-${arch}-${macos_vsn}/OTP-${otp_vsn}`, and available at
<https://github.com/jelly-beam/otp-macos/releases/> under section Assets. We aim to keep naming
of the assets consistent as to ease use in CI pipelines.

File `_RELEASES` will contain the available `.tar.gz` packages, as well as the execution of
`crc32` on them and a date (of approximately when the build was finished), in the following format:

```plain
<vsn> <crc32_for_tar_gz> <date_as_utc_%Y-%m-%dT%H:%M:%SZ>
```

where `vsn` (the name of the file with the build) is `darwin-${arch}-${macos_vsn}_OTP-${otp_vsn}` (similar
to the tag, but notice the `_` instead of the `/`).

Finally, we also include a `.sha256.txt` in releases, for consumers to verify the origin of the
files. To do so, run `shasum -a 256 <file>` where `<file>` is the downloaded `.tar.gz` asset,
then compare the result of that operation to `<file>`'s `.sha256.txt` counterpart.

#### Architectures

Supported architectures are (from `${arch}`):

- `x86_64`: a 64-bit Intel-based Mac
- `arm64`: a 64-bit ARM-based Mac

### GitHub images

Read more about GitHub-hosted runners in the
[official documentation](https://docs.github.com/en/actions/using-github-hosted-runners/about-github-hosted-runners).

## 🔒 Security considerations

While we make efforts to harden the security of the result of this repository's workflows we're also
human beings, and thus flawed. Our main identified concern is the possibility of injection of
malicious software into an image you'll later consume. Do that end, we:

- only use software from sources we trust
- trust that GitHub Actions (and its runners) are hardened in nature - while we make extra efforts
to build on top of this
- are vocal about [security considerations](https://github.com/jelly-beam/otp-macos/issues?q=label%3A%22security+consideration%22)
and open to suggestions for change
- have a [security policy](https://github.com/jelly-beam/otp-macos/blob/main/SECURITY.md) in place
- have tweaked the repository's Settings as per GitHub recommendations for security
- count on you, the consumer, to help where possible (after all this is FOSS)

As per our [license](https://github.com/jelly-beam/otp-macos/blob/main/LICENSE),
`THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED`, and we want
you to be aware that it lies upon an established chain of trust, on top of which we do our best to
make security concerns visible and act on them when required.

At a very minimum, when consuming the images generated by this repository, we strongly suggest you
verify their SHA sum the same way we generate it (`.sha256.txt` found next to `.tar.gz`):

```console
shasum -a 256 "${filename_tar_gz}" # Then compare to the one in _RELEASES
```

to help your project stay safe.

## The project

### Changelog

A complete changelog can be found under [CHANGELOG.md](https://github.com/jelly-beam/otp-macos/blob/main/CHANGELOG.md).

### Code of Conduct

This project's code of conduct is made explicit in [CODE_OF_CONDUCT.md](https://github.com/jelly-beam/otp-macos/blob/main/CODE_OF_CONDUCT.md).

### Contributing

First of all, thank you for contributing with your time and patience.

If you want to request a new feature make sure to
[open an issue](https://github.com/jelly-beam/otp-macos/issues) so we can
discuss it first.

Bug reports and questions are also welcome, but do check you're using the latest version of the
plugin - if you found a bug - and/or search the issue database - if you have a question, since it
might have already been answered before.

Contributions will be subject to the MIT License.
You will retain the copyright.

For more information check out [CONTRIBUTING.md](https://github.com/jelly-beam/otp-macos/blob/main/CONTRIBUTING.md).

### License

License information can be found inside [LICENSE](https://github.com/jelly-beam/otp-macos/blob/main/LICENSE).

### Security

This project's security policy is made explicit in [SECURITY.md](https://github.com/jelly-beam/otp-macos/blob/main/SECURITY.md).
