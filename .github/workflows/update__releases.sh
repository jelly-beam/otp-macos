#!/bin/bash

filename_no_ext=$1

INSTALL_DIR=$RUNNER_TEMP/otp

crc32=$(crc32 "$INSTALL_DIR"/"$filename_no_ext.tar.gz")
date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
echo "$filename_no_ext $crc32 $date" >>_RELEASES

sort -o _RELEASES _RELEASES

git config user.name "GitHub Actions"
git config user.email "actions@user.noreply.github.com"
git add _RELEASES
git commit -m "Update _RELEASES: $filename_no_ext"
git push origin "${GITHUB_REF_NAME}"

target_commitish=$(git log -n 1 --pretty=format:"%H")
echo "target_commitish=${target_commitish}" >>"$GITHUB_OUTPUT"

