#!/usr/bin/env bash
set -euo pipefail

: "${PHASE:?PHASE is required}"
: "${BUILD_TYPE:?BUILD_TYPE is required}"
: "${COVERAGE:?COVERAGE is required}"

case "$PHASE" in
    prepare|build|test|tag|package) ;;
    *) echo "Unsupported lab phase: $PHASE" >&2; exit 1 ;;
esac
case "$BUILD_TYPE" in
    Debug|Release|RelWithDebInfo) ;;
    *) echo "Unsupported build type: $BUILD_TYPE" >&2; exit 1 ;;
esac
if [[ "$COVERAGE" != false ]]; then
    echo "Coverage is not enabled in this lab yet." >&2
    exit 1
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
echo "Running CI phase: $PHASE"
exec bash "$script_dir/$PHASE.sh"
