#!/usr/bin/env bash

set -eo pipefail

args=(-b -t "$BUILD_TYPE")

if [[ "$COVERAGE" == "true" ]]; then
    args+=(-C)
fi

echo "Building project: type=$BUILD_TYPE, coverage=$COVERAGE"
./build.sh "${args[@]}"