#!/usr/bin/env bash
set -euo pipefail

export GIT_COMMITTER_NAME='github-actions[bot]'
export GIT_COMMITTER_EMAIL='41898282+github-actions[bot]@users.noreply.github.com'

export LC_ALL=C
mkdir -p artifacts

echo "Synchronizing version tags..."
git fetch --prune origin '+refs/tags/*:refs/tags/*'

tags_before="$(git tag --list | sort)"

echo "Creating the next version tag with project build.sh..."
./build.sh -T

tags_after="$(git tag --list | sort)"
release_tag="$(comm -13 \
    <(printf '%s\n' "$tags_before") \
    <(printf '%s\n' "$tags_after"))"

if [[ -z "$release_tag" || "$release_tag" == *$'\n'* ]]; then
    echo "Expected exactly one new version tag." >&2
    exit 1
fi

printf '%s\n' "$release_tag" > artifacts/release-tag.txt
echo "Recorded release tag: $release_tag"