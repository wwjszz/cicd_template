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

- Other branch pushes call cpp-build.yml.
- Default branch pushes call cpp-release.yml.

Both callers use the test/wt-cicd-lab ref and explicitly pass CI_SSH_KEY.
The release workflow checks that the event is a non-deletion push to the
repository's default branch. Tag pushes do not start another release workflow.
The default branch name is filled in by GitHub when creating the caller.

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
