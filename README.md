# wt-cicd-lab CI template branch

This is the test/wt-cicd-lab branch of the existing wwjszz/cicd_template
repository. The main branch and company-project integration remain separate.

## Supported entry point

```yaml
jobs:
  build:
    uses: wwjszz/cicd_template/.github/workflows/cpp-build.yml@test/wt-cicd-lab
```

The caller needs contents: read for its GITHUB_TOKEN and a self-hosted
Linux/x64 runner carrying the wt-cicd-lab label. This dependency-free lab
does not require CI_SSH_KEY.

The existing layers are preserved:

reusable workflow -> composite action.yml -> run.sh -> scripts/ci.sh
-> prepare.sh / build.sh / test.sh

- Prepare checks the project-owned build.sh and CMakeLists.txt.
- Build runs ./build.sh -b -t Release in the fixed compiler image.
- Test runs CTest and fails if there are no registered tests.
- The image is localhost:5000/cxx_builder_devtoolset_8:1.3.
- No Docker CPU or memory limit is added.

Only cpp-build.yml is adapted and enabled for this first lab.
The other workflows and advanced phase scripts are retained from the
original branch for later work; they are not lab entry points yet.
