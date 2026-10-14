#!/usr/bin/env bash

set -eo pipefail

: "${BUILD_TYPE:?BUILD_TYPE is required}"

if [[ ! -f ./build.sh || ! -x ./build.sh ]]; then
    echo "Project build.sh is missing or not executable. Run prepare first." >&2
    exit 1
fi

# TODO: add --parallel
args=(-b -t "$BUILD_TYPE")

echo "Building project: type=$BUILD_TYPE"
./build.sh "${args[@]}"