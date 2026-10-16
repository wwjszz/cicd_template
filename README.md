# C++ CI 模板

业务仓库通过 `jobs.<job_id>.uses` 调用固定职责的 reusable workflow。调用方选择触发条件和流程，模板统一选择 runner、构建方式、测试步骤和报告路径。

## 可用流程

| 入口 | 固定行为 | 产出 |
| --- | --- | --- |
| `cpp-build.yml` | 准备项目 → Release 构建 → 单元测试 | 构建与测试结果，不执行发布 |
| `cpp-coverage.yml` | 准备项目 → Debug 插桩构建 → 单元测试 → 覆盖率报告 | `coverage-report` artifact，含 HTML、LCOV 和 Cobertura XML |

两个入口都只接受必需的 `CI_SSH_KEY` secret，没有 `with` 输入。普通构建始终运行测试；coverage 使用 Debug，产物不用于正式发布。

## 只运行构建和测试

在业务仓库中创建 `.github/workflows/ci.yml`：

```yaml
name: CI

on:
  push:
    branches: [master]
  pull_request:
    branches: [master]

permissions:
  contents: read

jobs:
  build:
    uses: wwjszz/cicd_template/.github/workflows/cpp-build.yml@main
    secrets:
      CI_SSH_KEY: ${{ secrets.CI_SSH_KEY }}
```

将 `master` 改为项目的目标分支。当前 `common` 示例保留 `wwj/test-cicd` 分支上的 push 触发条件。

`cpp-build.yml` 没有 coverage 或上传覆盖率报告的步骤。因此，只调用 build 时，本次 Actions 运行中不会出现这些步骤，也不会出现因关闭 coverage 而显示的 `Skipped`。

## 增加覆盖率检查

在上面的 `jobs` 中增加一个独立 job：

```yaml
  coverage:
    uses: wwjszz/cicd_template/.github/workflows/cpp-coverage.yml@main
    secrets:
      CI_SSH_KEY: ${{ secrets.CI_SSH_KEY }}
```

也可以只保留 coverage job。它自行完成插桩构建和测试，不需要 `needs: build`，不依赖另一个 job 的工作目录或产物。两个 job 都启用时，会各自执行一次构建和测试；runner 数量决定它们是否能同时执行。

测试和报告生成成功后，可在本次运行的 Artifacts 中下载 `coverage-report`，其中 `index.html` 是 HTML 报告入口，`coverage.info` 是 LCOV 数据，`coverage.xml` 是 Cobertura XML。测试失败会使 job 失败，后续覆盖率步骤按 GitHub 的默认失败处理跳过。

## 接入前提

- 调用方仓库配置名为 `CI_SSH_KEY` 的 Actions secret，或获准使用同名组织 secret。凭据需要能读取业务仓库和构建所需的私有依赖；调用时仍需显式传递。
- 调用方可以使用标签为 `self-hosted`、`linux`、`x64`、`wwj-cicd` 的现有 runner。这两个新入口已固定标签，不需要业务仓库填写。
- 调用方获准访问模板仓库及其中的 action；私有模板仓库需要配置 Actions 的共享访问权限。

目前沿用现有远程 runner、Docker 挂载方式和构建镜像 `localhost:5000/cxx_builder_devtoolset_8:1.3`，无需修改 `cicd_runner`。该镜像和 Docker 环境必须已在 runner 主机上可用。

## 项目构建约定

Prepare、Build、Test 统一通过 `.github/actions/build-test` 调用，例如：

```yaml
- name: Build and test
  uses: $/.github/actions/build-test
  with:
    build-type: Release
```

默认运行测试；coverage 流程传入 `build-type: Debug` 和 `coverage: "true"`，发版构建传入 `build-type: RelWithDebInfo`。旧 `cpp-ci.yml` 的 `run-tests` 开关继续有效，开启 coverage 时始终运行测试。

workflow 中显示一个构建步骤，展开日志查看 Prepare、Build、Test 各阶段。内部仍分别调用现有 phase action 和脚本：

1. `prepare` 在构建容器内运行 `git_setup`，准备出可执行的项目 `./build.sh`。
2. 普通构建运行 `./build.sh -b -t Release`；coverage 构建运行 `./build.sh -b -t Debug -C`，随后清零覆盖率计数。
3. 测试执行 `build/run_test/` 下的可执行文件，并通过 `GTEST_OUTPUT` 将 XML 写入 `build/run_test/reports/`。找不到测试或任一测试失败都会使 job 失败；这些测试 XML 当前不单独上传。
4. 覆盖率脚本使用匹配工具链的 gcov、lcov、genhtml 和 lcov_cobertura，将报告写入 `build/test_coverage/`。

每个 job 都 checkout 并清理自己的工作区，再完成完整流程，不依赖 self-hosted runner 上遗留的构建结果。新流程通过 `$/` 引用模板仓库同一版本的 action，沿用当前 GitHub.com 用法；该语法不适用于 GitHub Enterprise Server，参见 [GitHub 的 action 引用说明](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#jobsjob_idstepsuses)。

## 从旧入口迁移

原有 `cpp-ci.yml` 暂时保留兼容已有调用方；新的接入使用上述两个专用入口。

- 只做构建和测试：改用 `cpp-build.yml`，删除整个 `with` 块，保留 `CI_SSH_KEY` 映射。
- 需要覆盖率：增加或单独使用 `cpp-coverage.yml`，不用再传 `coverage: true`。
- 需要改变统一 runner 标签、编译模式或工具链：由模板维护者修改模板实现，不向每个业务仓库增加开关。

发布此次改动时，先将模板仓库的新文件发布到调用方引用的版本，再发布业务仓库的调用修改。否则 GitHub 无法找到新的 workflow。示例沿用当前 `@main`；推广到更多仓库前，应建立模板版本发布流程，按需使用已发布版本或固定 commit SHA。本次没有创建版本标签。

模板中的 `Release` 是编译模式。正式发版、部署、审批和权限规范将由后续专用流程实现。
