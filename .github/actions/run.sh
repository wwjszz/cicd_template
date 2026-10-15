#!/usr/bin/env bash
set -euo pipefail

: "${GITHUB_WORKSPACE:?GITHUB_WORKSPACE is required}"
: "${RUNNER_TEMP:?RUNNER_TEMP is required}"
: "${SSH_AUTH_SOCK:?SSH_AUTH_SOCK is required}"
: "${BUILD_TYPE:?BUILD_TYPE is required}"
: "${PHASE:?PHASE is required}"
: "${COVERAGE:?COVERAGE is required}"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
build_image="localhost:5000/cxx_builder_devtoolset_8:1.3"

if [[ ! -f "$script_dir/scripts/ci.sh" ]]; then
    echo "CI script was not found." >&2
    exit 1
fi

if [[ ! -S "$SSH_AUTH_SOCK" ]]; then
    echo "SSH agent socket was not found." >&2
    exit 1
fi

# Stage scripts in the shared runner temporary directory.
temp_dir="$(mktemp -d "$RUNNER_TEMP/cicd-build.XXXXXX")"
trap 'rm -rf -- "$temp_dir"' EXIT

cp -R -- "$script_dir/scripts" "$temp_dir/scripts"

# Use the GitHub host key from the verified workflow.
known_hosts="$temp_dir/known_hosts"

printf '%s\n' \
    'github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl' \
    > "$known_hosts"

echo "Starting build container: phase=$PHASE"

# --cpus 2 \
# --memory 4g \
docker run --rm --init \
    --mount "type=bind,src=$GITHUB_WORKSPACE,dst=$GITHUB_WORKSPACE" \
    --mount "type=bind,src=$temp_dir/scripts,dst=/opt/ci,readonly" \
    --mount "type=bind,src=$SSH_AUTH_SOCK,dst=/run/ci-ssh-agent.sock,readonly" \
    --mount "type=bind,src=$known_hosts,dst=/run/ci-known-hosts,readonly" \
    --workdir "$GITHUB_WORKSPACE" \
    --env "BUILD_TYPE=$BUILD_TYPE" \
    --env "COVERAGE=$COVERAGE" \
    --env "PHASE=$PHASE" \
    --env "BUILD_IMAGE=$build_image" \
    --env GITHUB_REF \
    --env GITHUB_SHA \
    --env RELEASE_TAG \
    --env TZ=Asia/Shanghai \
    --env SSH_AUTH_SOCK=/run/ci-ssh-agent.sock \
    --env GIT_TERMINAL_PROMPT=0 \
    --env 'GIT_SSH_COMMAND=ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/run/ci-known-hosts -o ConnectTimeout=10' \
    --entrypoint /bin/bash \
    "$build_image" \
    /opt/ci/ci.sh