#!/usr/bin/env bash
set -euo pipefail

: "${BUILD_IMAGE:?BUILD_IMAGE is required}"
: "${RELEASE_TAG:?RELEASE_TAG is required}"
: "${GITHUB_SHA:?GITHUB_SHA is required}"

git check-ref-format "refs/tags/$RELEASE_TAG"

if [[ "$BUILD_TYPE" != "RelWithDebInfo" || "$COVERAGE" != "false" ]]; then
    echo "Release packaging requires RelWithDebInfo and coverage=false." >&2
    exit 1
fi

project_dir="$PWD"
artifact_dir="$project_dir/artifacts"

commit_sha="$(git rev-parse HEAD)"
event_sha="$(git rev-parse --verify "${GITHUB_SHA}^{commit}")"
tag_sha="$(git rev-parse --verify "refs/tags/${RELEASE_TAG}^{commit}")"

if [[ "$commit_sha" != "$event_sha" || "$commit_sha" != "$tag_sha" ]]; then
    echo "Checkout, event and tag do not identify the same commit." >&2
    exit 1
fi

mkdir -p -- "$artifact_dir"

cat > "$artifact_dir/build-info.txt" <<EOF
tag=${RELEASE_TAG}
commit=$commit_sha
build_type=$BUILD_TYPE
coverage=$COVERAGE
build_image=$BUILD_IMAGE
EOF

echo "Packaging tag $RELEASE_TAG..."

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