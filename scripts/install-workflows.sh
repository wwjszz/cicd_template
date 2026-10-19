#!/usr/bin/env bash
# Install the three C++ workflow entry points into the current Git repository.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: run inside the target Git working tree
  bash /path/to/install-workflows.sh --repo COMPANY_ORG/.github [options]

Options:
  --repo OWNER/REPO  Shared template repository, usually ORG/.github (required)
  --ref REF          Template and workflow branch, tag or commit SHA (default: main)
  --branch BRANCH    Release branch in the target repository (default: master)
  --https            Fetch over HTTPS instead of SSH
  --dry-run          Preview the generated diff without writing files
  -h, --help         Show this help

Installs cpp-build.yml, cpp-coverage.yml and the generic cpp-release.yml.
Release defaults to deploy-target: none; choose app or strategy to publish files.
Identical files are skipped. Conflicting files abort installation before writing.
Only local files are created. No git add, commit, push or permission changes.
EOF
}

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

require_value() {
  [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || die "Missing value for $1"
}

source_repo=
source_ref=main
release_branch=master
transport=ssh
dry_run=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) require_value "$@"; source_repo=$2; shift 2 ;;
    --ref) require_value "$@"; source_ref=$2; shift 2 ;;
    --branch) require_value "$@"; release_branch=$2; shift 2 ;;
    --https) transport=https; shift ;;
    --dry-run) dry_run=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown argument: $1 (see --help)" ;;
  esac
done

for dependency in git awk cmp diff mktemp; do
  command -v "$dependency" >/dev/null 2>&1 || die "Missing command: $dependency"
done
[[ "$source_repo" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*/[A-Za-z0-9_.-]+$ ]] ||
  die '--repo must be OWNER/REPO, for example COMPANY_ORG/.github'
[[ "$source_ref" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*$ ]] &&
  git check-ref-format "refs/heads/$source_ref" >/dev/null 2>&1 ||
  die '--ref must be a branch, tag or SHA using letters, digits, dots, underscores, slashes or hyphens'
[[ "$release_branch" != -* ]] &&
  git check-ref-format "refs/heads/$release_branch" >/dev/null 2>&1 ||
  die '--branch is not a valid Git branch name'

target_root=$(git rev-parse --show-toplevel 2>/dev/null) || die 'Run inside the target Git working tree'
target_dir="$target_root/.github/workflows"
for directory in "$target_root/.github" "$target_dir"; do
  [[ ! -L "$directory" ]] || die "Target directory must not be a symlink: $directory"
  [[ ! -e "$directory" || -d "$directory" ]] || die "Target path is not a directory: $directory"
done

if [[ "$transport" == https ]]; then
  source_url="https://github.com/$source_repo.git"
else
  source_url="git@github.com:$source_repo.git"
fi
scratch=$(mktemp -d "${TMPDIR:-/tmp}/cicd-workflows.XXXXXX")
trap 'rm -rf -- "$scratch"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
git init --quiet "$scratch/source"
printf 'Fetching templates: %s @ %s\n' "$source_repo" "$source_ref"
if ! git -C "$scratch/source" fetch --quiet --depth=1 --no-tags -- "$source_url" "$source_ref"; then
  die 'Could not fetch templates; check the repository, ref and Git read access'
fi
source_commit=$(git -C "$scratch/source" rev-parse FETCH_HEAD)
printf 'Template commit: %s\nTarget repository: %s\nRelease branch: %s\n' "$source_commit" "$target_root" "$release_branch"

workflows=(cpp-build.yml cpp-coverage.yml cpp-release.yml)
mkdir "$scratch/generated"
for workflow in "${workflows[@]}"; do
  git -C "$scratch/source" show "FETCH_HEAD:workflow-templates/$workflow" > "$scratch/template.yml" ||
    die "Missing source template: workflow-templates/$workflow"
  git -C "$scratch/source" cat-file -e "FETCH_HEAD:.github/workflows/$workflow" ||
    die "Missing reusable workflow: .github/workflows/$workflow"

  # Only rewrite the known caller and trigger lines. GitHub expressions and
  # permissions are copied verbatim. Refuse unfamiliar template layouts.
  if ! INSTALL_REPO="$source_repo" INSTALL_REF="$source_ref" \
    INSTALL_BRANCH="$release_branch" INSTALL_WORKFLOW="$workflow" awk '
    BEGIN {
      repo = ENVIRON["INSTALL_REPO"]
      ref = ENVIRON["INSTALL_REF"]
      workflow = ENVIRON["INSTALL_WORKFLOW"]
      branch = ENVIRON["INSTALL_BRANCH"]
      gsub(/\047/, "\047\047", branch)
      branch = "\047" branch "\047"
      branch_key = workflow == "cpp-release.yml" ? "branches:" : "branches-ignore:"
    }
    {
      indent = $0
      sub(/[^[:space:]].*$/, "", indent)
      if (NF == 2 && $1 == "uses:" &&
          $2 ~ /^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+\/\.github\/workflows\// &&
          index($2, "/.github/workflows/" workflow "@") > 0) {
        print indent "uses: " repo "/.github/workflows/" workflow "@" ref
        callers++
      } else if (NF == 2 && $1 == branch_key && $2 == "[master]") {
        print indent branch_key " [" branch "]"
        branches++
      } else {
        print
      }
    }
    END { if (callers != 1 || branches != 1) exit 1 }
  ' "$scratch/template.yml" > "$scratch/generated/$workflow"; then
    die "Unexpected template layout: $workflow; expected one reusable workflow call and a [master] branch filter"
  fi
done

# Check every destination before writing any file, including unchanged symlinks.
conflict=false
for workflow in "${workflows[@]}"; do
  destination="$target_dir/$workflow"
  if [[ -L "$destination" || ( -e "$destination" && ! -f "$destination" ) ]]; then
    die "Target must be a regular file: $destination"
  fi
  if [[ -e "$destination" ]] && ! cmp -s "$scratch/generated/$workflow" "$destination"; then
    printf 'File conflict: %s\n' "$destination" >&2
    conflict=true
  fi
done

if [[ "$dry_run" == true ]]; then
  for workflow in "${workflows[@]}"; do
    destination="$target_dir/$workflow"
    existing=/dev/null
    [[ ! -e "$destination" ]] || existing=$destination
    diff_status=0
    diff -u --label "a/.github/workflows/$workflow" --label "b/.github/workflows/$workflow" \
      "$existing" "$scratch/generated/$workflow" || diff_status=$?
    [[ "$diff_status" -le 1 ]] || die "Could not preview $workflow"
  done
  [[ "$conflict" == false ]] || die 'Preview found conflicts; target repository was not modified'
  printf 'Preview complete; target repository was not modified.\n'
  exit 0
fi
[[ "$conflict" == false ]] || die 'Existing workflows differ; no files installed. Use --dry-run and resolve differences manually'

mkdir -p "$target_dir"
for workflow in "${workflows[@]}"; do
  destination="$target_dir/$workflow"
  if [[ -e "$destination" ]]; then
    printf 'Skipped (identical): .github/workflows/%s\n' "$workflow"
  else
    # Noclobber also protects a file created after the preflight check.
    (set -o noclobber; cat "$scratch/generated/$workflow" > "$destination") ||
      die "Could not create $destination; check permissions or concurrent changes"
    printf 'Installed: .github/workflows/%s\n' "$workflow"
  fi
done
printf '\nReview the three files under .github/workflows/, then commit and push them.\n'
printf 'Build/Coverage run on pushes outside %s; Release runs on pushes to %s.\n' "$release_branch" "$release_branch"
