#!/usr/bin/env bash
set -euo pipefail

: "${GITHUB_SHA:?GITHUB_SHA is required}"
if [[ ! -f ./build.sh || ! -x ./build.sh ]]; then
    echo "Project build.sh is missing or not executable. Run prepare first." >&2
    exit 1
fi
if [[ "$(git rev-parse HEAD)" != "$(git rev-parse --verify "${GITHUB_SHA}^{commit}")" ]]; then
    echo "Tagging requires the triggering commit to be checked out." >&2
    exit 1
fi

export GIT_COMMITTER_NAME='github-actions[bot]'
export GIT_COMMITTER_EMAIL='41898282+github-actions[bot]@users.noreply.github.com'
export LC_ALL=C
mkdir -p artifacts

echo "Synchronizing version tags..."
git fetch --prune origin '+refs/tags/*:refs/tags/*'

# Rerunning a failed artifact job must not allocate another version.
release_tag="$(git tag --points-at HEAD | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n 1 || true)"
if [[ -n "$release_tag" ]]; then
    echo "Reusing version tag: $release_tag"
else
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
fi

git check-ref-format "refs/tags/$release_tag"
if [[ "$(git rev-parse --verify "refs/tags/${release_tag}^{commit}")" != "$GITHUB_SHA" ]]; then
    echo "Generated tag does not match the triggering commit." >&2
    exit 1
fi
printf '%s\n' "$release_tag" > artifacts/release-tag.txt
echo "Recorded release tag: $release_tag"
