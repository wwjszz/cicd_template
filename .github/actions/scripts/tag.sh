#!/usr/bin/env bash

set -euo pipefail

if [[ ! -f ./build.sh || ! -x ./build.sh ]]; then
    echo "Project build.sh is missing or not executable. Run prepare first." >&2
    exit 1
fi

export GIT_COMMITTER_NAME='github-actions[bot]'
export GIT_COMMITTER_EMAIL='41898282+github-actions[bot]@users.noreply.github.com'

echo "Synchronizing version tags..."
git fetch --prune origin '+refs/tags/*:refs/tags/*'

echo "Creating the next version tag with project build.sh..."
./build.sh -T