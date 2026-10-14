#!/usr/bin/env bash

set -eo pipefail

project_dir="$PWD"
build_dir="$project_dir/build"
report_dir="$build_dir/test_coverage"
gcov_tool="/opt/rh/devtoolset-8/root/usr/bin/gcov"

if [[ ! -d "$build_dir" ]]; then
    echo "Build directory was not found: $build_dir" >&2
    exit 1
fi

if [[ -z "$(find "$build_dir" -type f -name '*.gcda' -print -quit)" ]]; then
    echo "No coverage data found. Build with coverage enabled and run tests first." >&2
    exit 1
fi

mkdir -p -- "$report_dir"

lcov_options=(
    --rc lcov_branch_coverage=1
    --gcov-tool "$gcov_tool"
)

echo "Collecting coverage data..."

lcov "${lcov_options[@]}" --capture --initial \
    --base-directory "$project_dir" --directory "$build_dir" \
    --output-file "$report_dir/base.info"

lcov "${lcov_options[@]}" --capture \
    --base-directory "$project_dir" --directory "$build_dir" \
    --output-file "$report_dir/run.info"

lcov "${lcov_options[@]}" \
    --add-tracefile "$report_dir/base.info" \
    --add-tracefile "$report_dir/run.info" \
    --output-file "$report_dir/all.info"

# Keep the exclusions from the existing project build script.
lcov "${lcov_options[@]}" --remove "$report_dir/all.info" \
    '*/x_*' '*8/*' '/usr/include/*' \
    --output-file "$report_dir/coverage.info"

genhtml "$report_dir/coverage.info" \
    --branch-coverage --ignore-errors source \
    --output-directory "$report_dir"

lcov_cobertura "$report_dir/coverage.info" \
    -b "$project_dir" -o "$report_dir/coverage.xml"

echo "Coverage reports generated: $report_dir"