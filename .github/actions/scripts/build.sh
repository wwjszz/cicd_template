#!/usr/bin/env bash

set -eo pipefail

: "${BUILD_TYPE:?BUILD_TYPE is required}"
: "${COVERAGE:?COVERAGE is required}"

if [[ ! -f ./build.sh || ! -x ./build.sh ]]; then
    echo "Project build.sh is missing or not executable. Run prepare first." >&2
    exit 1
fi

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