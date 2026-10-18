#!/usr/bin/env bash

set -eo pipefail

case "$PHASE" in
    prepare|build|test|coverage|package|tag)
        ;;
    *)
        echo "Unsupported CI phase: $PHASE" >&2
        exit 1
        ;;
esac

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

script_dir="$(cd -- "$(dirname -- "$0")" && pwd)"

echo "Enabling the compiler toolchain..."
source /opt/rh/devtoolset-8/enable

echo "Running CI phase: $PHASE"
exec bash "$script_dir/$PHASE.sh"