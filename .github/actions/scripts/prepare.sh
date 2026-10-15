#!/usr/bin/env bash
set -euo pipefail

if [[ ! -f ./CMakeLists.txt || ! -f ./build.sh || ! -x ./build.sh ]]; then
    echo "The lab project must provide CMakeLists.txt and an executable build.sh." >&2
    exit 1
fi
cmake --version
echo "Project preparation completed."
