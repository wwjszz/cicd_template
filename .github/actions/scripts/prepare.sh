#!/usr/bin/env bash

set -eo pipefail

echo "Initializing the project..."
git_setup

if [[ ! -f ./build.sh || ! -x ./build.sh ]]; then
    echo "Project build.sh is missing or not executable." >&2
    exit 1
fi

echo "Project preparation completed."