# wt-cicd-lab CI template branch

This is the test/wt-cicd-lab branch of the existing wwjszz/cicd_template
repository. The main branch and company-project integration remain separate.

## Supported entry point

```yaml
permissions:
  contents: read

jobs:
  build:
    uses: wwjszz/cicd_template/.github/workflows/cpp-build.yml@test/wt-cicd-lab
    secrets:
      CI_SSH_KEY: ${{ secrets.CI_SSH_KEY }}
```

The caller requires access to the organization runner group lab-runners.
The template selects a self-hosted Linux/x64 runner in that group carrying
the wt-cicd-lab label. The lab runner image provides GCC/G++, Make, and CMake.

CI_SSH_KEY must contain an SSH private key whose public key is authorized to
read the caller repository. Checkout uses SSH even for a public repository.
The key is removed by checkout's cleanup; persist-credentials is disabled.
Organization secrets must grant access to the caller repository. On GitHub
Free, private repositories cannot access organization secrets; use a
repository secret of the same name when testing private repositories.

The existing layers are preserved:

reusable workflow -> composite action.yml -> run.sh -> scripts/ci.sh
-> prepare.sh / build.sh / test.sh

- Prepare checks the project-owned build.sh and CMakeLists.txt and prints tool versions.
- Build runs ./build.sh -b -t Release directly in the runner.
- Test runs CTest and fails if there are no registered tests.
- No separate compiler container is started.
- No Docker CPU or memory limit is added.

Only cpp-build.yml is adapted and enabled for this first lab.
The other workflows and advanced phase scripts are retained from the
original branch for later work; they are not lab entry points yet.
