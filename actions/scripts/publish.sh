#!/usr/bin/env bash
set -euo pipefail

fail() { echo "Error: $*" >&2; exit 1; }

case "$DEPLOY_TARGET" in
    app)
        RELEASE_ROOT="${APPLICATION_RELEASE_ROOT:?APPLICATION_RELEASE_ROOT is required}"
        PUBLISH_DIR="${PUBLISH_DIR:-${APPLICATION_PUBLISH_DIR:?APPLICATION_PUBLISH_DIR is required}}"
        ;;
    strategy)
        RELEASE_ROOT="${STRATEGY_RELEASE_ROOT:?STRATEGY_RELEASE_ROOT is required}"
        PUBLISH_DIR="${PUBLISH_DIR:-${STRATEGY_PUBLISH_DIR:?STRATEGY_PUBLISH_DIR is required}}"
        ;;
    *)
        fail "deploy-target must be app or strategy."
        ;;
esac

for value in "$RELEASE_NAME" "$RELEASE_TAG"; do
    [[ -n "$value" && "$value" != "." && "$value" != ".." && "$value" != */* ]] ||
        fail "Release name and tag must be single directory names."
done

workspace="$(realpath -e -- "$GITHUB_WORKSPACE")"
source_dir="$(realpath -e -- "$workspace/$PUBLISH_DIR")"

[[ -d "$source_dir" && "$source_dir" == "$workspace/"* ]] ||
    fail "publish-dir must be a directory inside the project."
[[ -n "$(find "$source_dir" -type f -print -quit)" ]] ||
    fail "No files found in $source_dir."

release_root="$(realpath -e -- "$RELEASE_ROOT")"
project_dir="$release_root/$RELEASE_NAME"
[[ ! -L "$project_dir" ]] ||
    fail "Project release directory must not be a symlink."
mkdir -p -m 755 -- "$project_dir"

destination="$project_dir/$RELEASE_TAG"
[[ ! -e "$destination" && ! -L "$destination" ]] ||
    fail "Version already exists: $destination"

staging="$(mktemp -d "$project_dir/.publishing.XXXXXX")"
trap 'rm -rf -- "$staging"' EXIT
mkdir -- "$staging/bin"

(
    cd -- "$source_dir"
    find . -type f -print0 | sort -z | xargs -0 sha256sum
) > "$staging/SHA256SUMS"

cp -a --no-preserve=ownership -- "$source_dir/." "$staging/bin/"
(
    cd -- "$staging/bin"
    sha256sum --check "$staging/SHA256SUMS"
)

printf 'tag=%s\ncommit=%s\n' "$RELEASE_TAG" "$GITHUB_SHA" > "$staging/build-info.txt"
chmod 755 -- "$staging"
mv -Tn -- "$staging" "$destination"
[[ ! -d "$staging" ]] || fail "Version was created by another publisher."

echo "Published: $destination/bin"