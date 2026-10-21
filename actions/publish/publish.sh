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
if [[ -e "$destination" || -L "$destination" ]]; then
    backup_root="$project_dir/.backup/$RELEASE_TAG"
    mkdir -p -- "$backup_root"

    backup_dir="$backup_root/$(date +%Y%m%d-%H%M%S-%N)"
    mv -T -- "$destination" "$backup_dir"

    echo "::warning::Version $RELEASE_TAG already exists; backed up to $backup_dir; replacing it."
fi

bin_dir="$destination/bin"
mkdir -m 755 -- "$destination" "$bin_dir"
cp -a -- "$source_dir/." "$bin_dir/"
rm -rf -- "$source_dir"

echo "Published: $bin_dir"
