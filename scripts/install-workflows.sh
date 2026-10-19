#!/usr/bin/env bash
# Install workflow entry points into the current Git repository.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bash /path/to/install-workflows.sh --repo OWNER/REPO

  --repo OWNER/REPO  Shared template repository (required)
  -h, --help         Show this help

Fetches main over SSH and installs build, coverage and release entry points.
Identical files are skipped; conflicting files are not overwritten.
Release defaults to deploy-target: none; choose app or strategy to publish files.
EOF
}

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

source_repo=
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      [[ $# -ge 2 ]] || die 'Missing value for --repo'
      source_repo=$2
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown argument: $1 (see --help)" ;;
  esac
done
[[ "$source_repo" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*/[A-Za-z0-9_.-]+$ ]] ||
  die '--repo must be OWNER/REPO, for example COMPANY_ORG/.github'

target_root=$(git rev-parse --show-toplevel 2>/dev/null) || die 'Run inside the target Git working tree'
target_dir="$target_root/.github/workflows"
for directory in "$target_root/.github" "$target_dir"; do
  [[ ! -L "$directory" ]] || die "Target directory must not be a symlink: $directory"
done

scratch=$(mktemp -d "${TMPDIR:-/tmp}/cicd-workflows.XXXXXX")
trap 'rm -rf -- "$scratch"' EXIT
git clone --quiet --depth 1 --single-branch --branch main --no-tags \
  "git@github.com:$source_repo.git" "$scratch/source"

workflows=(cpp-build.yml cpp-coverage.yml cpp-release.yml)
mkdir "$scratch/generated"
for workflow in "${workflows[@]}"; do
  template="$scratch/source/workflow-templates/$workflow"
  [[ -f "$template" ]] || die "Missing source template: workflow-templates/$workflow"
  sed "s|COMPANY_ORG/\\.github|$source_repo|g" "$template" > "$scratch/generated/$workflow"
done

# Check all destinations before writing any files.
for workflow in "${workflows[@]}"; do
  destination="$target_dir/$workflow"
  [[ ! -L "$destination" && ( ! -e "$destination" || -f "$destination" ) ]] ||
    die "Target must be a regular file: $destination"
  if [[ -e "$destination" ]] && ! cmp -s "$scratch/generated/$workflow" "$destination"; then
    die "File conflict: $destination; no files installed"
  fi
done

mkdir -p "$target_dir"
for workflow in "${workflows[@]}"; do
  destination="$target_dir/$workflow"
  if [[ -e "$destination" ]]; then
    printf 'Skipped (identical): .github/workflows/%s\n' "$workflow"
  else
    (set -o noclobber; cat "$scratch/generated/$workflow" > "$destination")
    printf 'Installed: .github/workflows/%s\n' "$workflow"
  fi
done
printf '\nReview .github/workflows/, choose the release deploy-target, then commit and push.\n'
