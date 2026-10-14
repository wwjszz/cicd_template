#!/usr/bin/env bash

set -eo pipefail

: "${BUILD_TYPE:?BUILD_TYPE is required}"
: "${RUN_TESTS:?RUN_TESTS is required}"

case "$BUILD_TYPE" in
    Debug|Release)
        ;;
    *)
        echo "Unsupported build type: $BUILD_TYPE" >&2
        exit 1
        ;;
esac

case "$RUN_TESTS" in
    true|false)
        ;;
    *)
        echo "RUN_TESTS must be true or false." >&2
        exit 1
        ;;
esac

echo "Enabling the compiler toolchain..."
source /opt/rh/devtoolset-8/enable

echo "Initializing the project..."
git_setup

if [[ ! -f ./build.sh ]]; then
    echo "Project build.sh was not generated." >&2
    exit 1
fi

# TODO: add --parallel
args=(-b -t "$BUILD_TYPE")

if [[ "$RUN_TESTS" == "true" ]]; then
    args+=(-u)
fi

echo "Building project: type=$BUILD_TYPE, run-tests=$RUN_TESTS"
./build.sh "${args[@]}"