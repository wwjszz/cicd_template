#!/usr/bin/env bash
set -euo pipefail

: "${GITHUB_WORKSPACE:?GITHUB_WORKSPACE is required}"
: "${BUILD_TYPE:?BUILD_TYPE is required}"
: "${PHASE:?PHASE is required}"
: "${COVERAGE:?COVERAGE is required}"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ ! -f "$script_dir/scripts/ci.sh" ]]; then
    echo "CI script was not found." >&2
    exit 1
fi

cd -- "$GITHUB_WORKSPACE"
echo "Running lab phase directly in the runner: $PHASE"
exec bash "$script_dir/scripts/ci.sh"
