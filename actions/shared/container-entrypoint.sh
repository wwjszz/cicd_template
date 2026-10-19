#!/usr/bin/env bash
set -eo pipefail

action_script="${1:?An action script path is required}"

echo "Enabling the compiler toolchain..."
source /opt/rh/devtoolset-8/enable

echo "Running action script: $action_script"
exec bash "$action_script"
