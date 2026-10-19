#!/usr/bin/env bash

set -eo pipefail

case "$BUILD_TYPE" in
    Debug|Release|RelWithDebInfo)
        ;;
    *)
        echo "Unsupported build type: $BUILD_TYPE" >&2
        exit 1
        ;;
esac

case "$COVERAGE" in
    true|false)
        ;;
    *)
        echo "COVERAGE must be true or false." >&2
        exit 1
        ;;
esac

args=(-b -t "$BUILD_TYPE")

if [[ "$COVERAGE" == "true" ]]; then
    args+=(-C)
fi

echo "Building project: type=$BUILD_TYPE, coverage=$COVERAGE"
./build.sh "${args[@]}"
