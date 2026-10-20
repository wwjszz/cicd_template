#!/usr/bin/env bash

set -eo pipefail

test_dir="$PWD/build/run_test"

if [[ ! -d "$test_dir" ]]; then
    echo "Skipping tests: test directory was not found: $test_dir"
    exit 0
fi

report_dir="$test_dir/reports"
mkdir -p -- "$report_dir"

cd -- "$test_dir"

shopt -s nullglob
ran_tests=false

for test_file in ./*; do
    if [[ ! -f "$test_file" || ! -x "$test_file" ]]; then
        continue
    fi

    test_name="${test_file##*/}"

    echo "Running test file: $test_name"
    GTEST_OUTPUT="xml:$report_dir/$test_name.xml" "$test_file"

    ran_tests=true
done

if [[ "$ran_tests" == "false" ]]; then
    echo "No executable test programs were found in: $test_dir"
    exit 0
fi

echo "All test programs passed."
