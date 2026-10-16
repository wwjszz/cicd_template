# C++ CI 模板

准备好 `CI_SSH_KEY` secret，能拉取项目及私有依赖；自动打 tag 时还需推送权限。
runner 使用 Linux x64，默认标签为 `wwj-cicd`，能通过 Docker 启动 `localhost:5000/cxx_builder_devtoolset_8:1.3`。

## 调用示例

业务仓库创建 `.github/workflows/ci.yml`：

```yaml
name: CI

on: [push, pull_request]

permissions:
  contents: read

jobs:
  ci:
    uses: wwjszz/cicd_template/.github/workflows/cpp-ci.yml@main
    with:
      runner-label: wwj-cicd
      build-type: Release
      run-tests: true
      coverage: false
    secrets:
      CI_SSH_KEY: ${{ secrets.CI_SSH_KEY }}
```

`runner-label` 必填，其余参数默认值如上。`build-type` 支持 Release、Debug、RelWithDebInfo；开启 coverage 时始终运行测试。

## 固定流程

固定流程将示例中的 `uses` 文件名替换为下表入口，并删除 `with`：

| 入口 | 流程 |
| --- | --- |
| `cpp-build.yml` | Release 构建、测试 |
| `cpp-coverage.yml` | Debug 插桩构建、测试、上传 coverage 报告 |
| `cpp-release.yml` | Release 构建测试 → 自动打 tag → RelWithDebInfo 构建测试、打包 |

`cpp-release.yml` 只在需要发版的分支 push 时调用，避免每个分支都自动打 tag。它目前上传 Actions artifact，GitHub Release 发布步骤尚未接入。

产物在 Actions 运行页面下载：`coverage-report` 内含 HTML 报告，`release-build-*` 内含编译包、构建信息和 SHA256SUMS。

## 项目约定

项目需支持 `git_setup` 初始化，以及 `./build.sh -b -t <类型>`、`-C` 插桩、`-T` 自动打 tag。测试程序放在 `build/run_test/`。

模板内部统一调用 `setup` 完成 checkout 和 SSH 初始化，调用 `build-test` 依次执行 Prepare、Build、Test；具体命令保留在 `.github/actions/scripts/`。
