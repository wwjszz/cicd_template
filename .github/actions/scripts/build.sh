#!/usr/bin/env bash

set -eo pipefail

# TODO: add --parallel
args=(-b -t "$BUILD_TYPE")

if [[ "$COVERAGE" == "true" ]]; then
    args+=(-C)
fi

echo "Building project: type=$BUILD_TYPE, coverage=$COVERAGE"
./build.sh "${args[@]}"

if [[ "$COVERAGE" == "true" ]]; then
    echo "Resetting coverage counters before tests..."
    lcov --zerocounters --directory "$PWD/build"
fi