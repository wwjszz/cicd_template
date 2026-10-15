#!/usr/bin/env bash
set -euo pipefail

: "${GITHUB_WORKSPACE:?GITHUB_WORKSPACE is required}"
: "${RUNNER_TEMP:?RUNNER_TEMP is required}"
: "${BUILD_TYPE:?BUILD_TYPE is required}"
: "${PHASE:?PHASE is required}"
: "${COVERAGE:?COVERAGE is required}"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
build_image="localhost:5000/cxx_builder_devtoolset_8:1.3"

if [[ ! -f "$script_dir/scripts/ci.sh" ]]; then
    echo "CI script was not found." >&2
    exit 1
fi

temp_dir="$(mktemp -d "$RUNNER_TEMP/cicd-build.XXXXXX")"
trap 'rm -rf -- "$temp_dir"' EXIT
cp -R -- "$script_dir/scripts" "$temp_dir/scripts"

echo "Starting lab build container: phase=$PHASE"
docker run --rm --init \
    --mount "type=bind,src=$GITHUB_WORKSPACE,dst=$GITHUB_WORKSPACE" \
    --mount "type=bind,src=$temp_dir/scripts,dst=/opt/ci,readonly" \
    --workdir "$GITHUB_WORKSPACE" \
    --env "BUILD_TYPE=$BUILD_TYPE" \
    --env "COVERAGE=$COVERAGE" \
    --env "PHASE=$PHASE" \
    --env "BUILD_IMAGE=$build_image" \
    --env GITHUB_SHA \
    --env TZ=Asia/Shanghai \
    --entrypoint /bin/bash \
    "$build_image" \
    /opt/ci/ci.sh
