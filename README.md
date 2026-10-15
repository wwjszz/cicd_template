# wt-cicd-lab CI templates

This test/wt-cicd-lab branch of wwjszz/cicd_template runs C++ jobs directly
inside the organization's lab runner.

## Entry points

- cpp-build.yml: Prepare -> Build Release -> Test.
- cpp-release.yml: two jobs. The first builds Release, runs tests, and generates
  a version tag. The second checks out that tag, builds RelWithDebInfo, runs
  tests, packages the build directory, and uploads the workflow artifact.

The organization starter templates in wt-cicd-lab/.github generate these
callers for repositories:

Choose one pair of organization starter templates:

- cpp-ci.yml: all branch pushes, including the default branch, call cpp-build.yml.
- cpp-release-manual.yml: workflow_dispatch calls cpp-release.yml. Select the
  default branch in Run workflow; no version input is needed.

The earlier automatic-release pair is also available:

- cpp-dev.yml: other branch pushes call cpp-build.yml.
- cpp-release.yml: default branch pushes call cpp-release.yml.

All callers use the test/wt-cicd-lab ref and explicitly pass CI_SSH_KEY.
The release workflow accepts workflow_dispatch or a non-deletion push, and
requires the selected ref to be the repository's default branch. Other branches,
tag refs, and unrelated events skip the release jobs. Tag pushes do not start
another build or release workflow. Both release entry points share the same
concurrency group and reuse an existing version tag on the selected commit.

Commit the manual caller to the default branch before using Run workflow.
Installing it does not release anything automatically. When switching to the
manual pair, remove or disable the old automatic-release caller; otherwise it
will continue to release on default branch pushes. Replace the old development
caller as well to avoid duplicate builds. For the automatic pair, GitHub fills
in the default branch name when creating the caller.

## Runner and authentication

Both workflows select runner group lab-runners with labels
self-hosted, linux, x64, wt-cicd-lab. The image contains GCC/G++, Make, and CMake.
The group must grant the caller repository access.

CI_SSH_KEY must read the caller repository. The release flow also requires
permission to push tags. The tag job keeps checkout's SSH authentication
until post-job cleanup; other jobs disable credential persistence.
Contents read is sufficient for GITHUB_TOKEN because Git tag pushes use SSH.
Organization secrets must grant access to the caller repository.

## Project contract and phases

The existing layers remain:

reusable workflow -> composite action.yml -> run.sh -> scripts/ci.sh
-> prepare.sh / build.sh / test.sh / tag.sh / package.sh

- Prepare requires CMakeLists.txt and an executable build.sh.
- Build invokes ./build.sh -b -t Release or RelWithDebInfo.
- Test runs CTest in build/ and fails if no tests are registered.
- Tag invokes project-owned ./build.sh -T to create and push one version tag.
  A numeric major.minor.patch tag already on the same commit is reused on reruns.
  The tag must point to the triggering commit.
- Package requires RelWithDebInfo and coverage=false. It archives build/,
  writes build-info.txt, and computes SHA256SUMS.

Tag jobs use one concurrency group with queue: max to serialize version
allocation. The artifact job waits with needs: tag and receives the tag through
a job output; it does not rely on a separate tag-push workflow.

The uploaded artifact contains build-output.tar.gz, build-info.txt and SHA256SUMS.
Its name includes the version, run ID and attempt. No GitHub Release page is created.
Coverage workflows remain outside this lab's supported entry points.
