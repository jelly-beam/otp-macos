# `otp-macos` [![Release][release-img]][release]

[release]: /jelly-beam/otp-macos/actions/workflows/release.yml
[release-img]: /jelly-beam/otp-macos/actions/workflows/release.yml/badge.svg

`otp-macos` is a living, and up-to-date, collection of precompiled macOS-ready Erlang/OTP versions.

It was initially created to support macOS on <https://github.com/erlef/setup-beam> builds.

We aim to build all Erlang versions (at most one every 2 hours - for all OS versions) starting from
Erlang/OTP 24, as per `kerl`'s listing, and targeting macOS for the versions supported by GitHub
Actions (11, 12, and 13, at the time of this writing).

## The build/release pipeline

We build the Erlang/OTP images using a mix of [Homebrew](https://brew.sh/) and
[kerl](/kerl/kerl), as well as some 3rd party actions. For security reasons, we
aim to stop depending on these in the future.

### Documentation chunks

The images are built with documentation chunks as per `make docs DOC_TARGETS=chunks`.

### Releases

Releases are tagged as `macos64-${macos_vsn}/OTP-${otp_vsn}`, and available at
<https://github.com/jelly-beam/otp-macos/releases/> under section Assets. We aim to keep naming
of the assets consistent as to ease use in CI pipelines.

File `_RELEASES` will contain the available `.tar.gz` packages, as well as the execution of
`crc32` on them and a date (of approximately when the build was finished), in the following format:

```plain
<vsn> <crc32_for_tar_gz> <date_as_utc_%Y-%m-%dT%H:%M:%SZ>
```

where:

* `vsn` (the name of the file with the build), is `macos64-${macos_vsn}_OTP-${otp_vsn}` (similar
to the tag, but notice the `_` instead of the `/`)

Finally, we also include a `.sha256.txt` in releases, for consumers to verify the origin of the
files. To do so, run `shasum -a 256 <file>` where `<file>` is the downloaded `.tar.gz` asset,
then compare the result of that operation to `<file>`'s `.sha256.txt` counterpart. If they're
different feel free to open an issue in this pull request so we can help investigate further.

### GitHub images

Read more about GitHub-hosted runners in the
[official documentation](https://docs.github.com/en/actions/using-github-hosted-runners/about-github-hosted-runners).

## The project

### Changelog

A complete changelog can be found under [CHANGELOG.md](/jelly-beam/otp-macos/blob/main/CHANGELOG.md).

### Code of Conduct

This project's code of conduct is made explicit in [CODE_OF_CONDUCT.md](/jelly-beam/otp-macos/blob/main/CODE_OF_CONDUCT.md).

### Contributing

First of all, thank you for contributing with your time and patience.

If you want to request a new feature make sure to
[open an issue](/jelly-beam/otp-macos/issues) so we can
discuss it first.

Bug reports and questions are also welcome, but do check you're using the latest version of the
plugin - if you found a bug - and/or search the issue database - if you have a question, since it
might have already been answered before.

Contributions will be subject to the MIT License.
You will retain the copyright.

For more information check out [CONTRIBUTING.md](/jelly-beam/otp-macos/blob/main/CONTRIBUTING.md).

### License

License information can be found inside [LICENSE](/jelly-beam/otp-macos/blob/main/LICENSE).

### Security

This project's security policy is made explicit in [SECURITY.md](/jelly-beam/otp-macos/blob/main/SECURITY.md).
