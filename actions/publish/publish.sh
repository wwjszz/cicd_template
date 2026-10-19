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

mkdir -m 755 -- "$destination"
mv -- "$source_dir" "$destination/"

echo "Published: $destination"
