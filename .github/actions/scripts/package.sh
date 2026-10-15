#!/usr/bin/env bash
set -euo pipefail

: "${BUILD_TYPE:?BUILD_TYPE is required}"
: "${COVERAGE:?COVERAGE is required}"
: "${BUILD_IMAGE:?BUILD_IMAGE is required}"
: "${GITHUB_REF:?GITHUB_REF is required}"
: "${GITHUB_SHA:?GITHUB_SHA is required}"

if [[ "$GITHUB_REF" != refs/tags/* ]]; then
    echo "Release packaging requires a tag." >&2
    exit 1
fi

if [[ "$BUILD_TYPE" != "RelWithDebInfo" || "$COVERAGE" != "false" ]]; then
    echo "Release packaging requires RelWithDebInfo and coverage=false." >&2
    exit 1
fi

project_dir="$PWD"
artifact_dir="$project_dir/artifacts"
cache_file="$project_dir/build/CMakeCache.txt"

if [[ ! -f "$cache_file" ]]; then
    echo "Build configuration was not found: $cache_file" >&2
    exit 1
fi

if ! grep -Fxq 'CMAKE_BUILD_TYPE:STRING=RelWithDebInfo' "$cache_file"; then
    echo "The actual build configuration is not RelWithDebInfo." >&2
    exit 1
fi

if ! grep -Fxq 'RUN_COVERAGE:BOOL=OFF' "$cache_file"; then
    echo "Coverage must be disabled for release packaging." >&2
    exit 1
fi

commit_sha="$(git rev-parse HEAD)"
event_sha="$(git rev-parse --verify "${GITHUB_SHA}^{commit}")"
tag_sha="$(git rev-parse --verify "${GITHUB_REF}^{commit}")"

if [[ "$commit_sha" != "$event_sha" || "$commit_sha" != "$tag_sha" ]]; then
    echo "Checkout, event and tag do not identify the same commit." >&2
    exit 1
fi

mkdir -p -- "$artifact_dir"

cat > "$artifact_dir/build-info.txt" <<EOF
tag=${GITHUB_REF#refs/tags/}
commit=$commit_sha
build_type=$BUILD_TYPE
coverage=$COVERAGE
build_image=$BUILD_IMAGE
EOF

echo "Packaging tag ${GITHUB_REF#refs/tags/}..."

tar -czf "$artifact_dir/build-output.tar.gz" \
    -C "$project_dir" build \
    -C "$artifact_dir" build-info.txt

(
    cd -- "$artifact_dir"
    sha256sum build-output.tar.gz > SHA256SUMS
)

echo "Release build artifacts generated:"
ls -lh -- \
    "$artifact_dir/build-output.tar.gz" \
    "$artifact_dir/build-info.txt" \
    "$artifact_dir/SHA256SUMS"