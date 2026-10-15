#!/usr/bin/env bash
set -euo pipefail

if [[ ! -f build/CMakeCache.txt ]]; then
    echo "Build configuration was not found. Run the build phase first." >&2
    exit 1
fi
ctest --test-dir build --output-on-failure --no-tests=error
echo "All CTest tests passed."
