# C++ CI/CD 模板

本仓库集中保存 C++ 项目的接入模板、公共工作流和执行脚本。交付时将仓库内容整体放入公司组织的 `.github` 仓库，保留下面的目录结构，包括隐藏目录 `.github/`：

```text
仓库根目录/
├── README.md
├── scripts/                 # 业务仓库 workflow 安装脚本
├── workflow-templates/       # 业务仓库入口模板和展示信息
├── .github/workflows/       # 可复用工作流
└── actions/                 # 公共 Action、容器入口和阶段脚本
```

## 部署到公司组织

1. 将完整内容放入公司 `.github` 仓库的 `main` 分支；公司仓库已有其他文件时保留这些文件。
2. 按下方说明通过脚本接入业务仓库，脚本自动填写公共仓库名称。若使用 GitHub 页面或手动复制接入，需要将所选 `workflow-templates/*.yml` 中的 `COMPANY_ORG/.github` 替换为实际公共仓库名称。本 README 命令中的占位符也需要手动替换。
3. 配置目标业务仓库对 runner、`CI_SSH_KEY` 和公共 workflow/Action 的使用权限。
4. 核对业务主分支名称。当前入口使用 `master`；公司公共实现的 `@main` 是另一项配置，不会自动改变业务主分支规则。

业务入口跨仓库调用 `COMPANY_ORG/.github/.github/workflows/...@main`；两个 `.github` 分别是仓库名和仓库内目录。公共实现内部使用 `$/actions/...` 引用同仓库、同一提交的 Action，迁移时无需填写组织名。接入模板生成到业务仓库后属于该业务仓库，因此跨仓库入口不能改成 `$/`。

## 使用前准备

使用前准备好：

- 仓库或组织 Secret `CI_SSH_KEY`，用于拉取源码、私有依赖和推送 tag，并授权业务仓库使用。
- 在线 runner，标签包含 `self-hosted, linux, x64, cpp-cicd-runner`；提供 Docker 和镜像 `localhost:5000/cxx_builder_devtoolset_8:1.3`。
- 可执行的项目 `./build.sh`，支持 `-b -t Release`、`-b -t Debug -C`、`-b -t RelWithDebInfo`、`-T`。构建输出到 `build/`，测试程序放在 `build/run_test/`；`-T` 负责创建并推送新 tag。
- `CI_SSH_KEY` 对应的 SSH 身份需要推送 tag 的权限。发布产物直接复制到服务器，入口使用 `permissions: contents: read`。
- 发布用 runner 配置并挂载 `APPLICATION_RELEASE_ROOT`、`STRATEGY_RELEASE_ROOT`；默认产物目录分别由 `APPLICATION_PUBLISH_DIR`、`STRATEGY_PUBLISH_DIR` 指定。

## 1. 接入业务仓库

### 通过脚本安装

在业务仓库的 Git 工作区内执行：

```bash
bash /path/to/install-workflows.sh --repo wwjszz/cicd_template
```

迁移到公司组织后，将仓库参数改为 `--repo COMPANY_ORG/.github`。脚本可以单独分发，执行者需要该模板仓库的 SSH 读取权限。

脚本固定通过 SSH 读取模板仓库的 `main` 分支，只安装 `ci.yml`、`release.yml` 两个入口到业务仓库的 `.github/workflows/`，并替换公共仓库名称。

- 触发规则沿用入口模板：非 `master` 分支 push、目标为 `master` 的 PR 依次运行 build、coverage；`master` push 运行 release。
- release 默认 `deploy-target: none`；系统发布改为 `app`，策略发布改为 `strategy`。
- 已有相同文件跳过；存在不同内容的同名文件则停止安装，不覆盖文件。
- 脚本不会提交、推送或配置 runner、secrets。生成后审阅文件，再自行提交。

入口文件不会自动同步；使用 `@main` 引用的公共 workflow 会随模板仓库更新。

已接入旧入口的仓库，切换时需自行移除或停用原有入口，避免重复执行和打 tag。

### 通过 GitHub 页面或手动复制

将模板部署到组织的 `.github` 仓库后，在业务仓库打开 **Actions → New workflow**，选择以下两个模板：

| 模板文件 | GitHub 页面名称 | 触发条件 | 执行内容 |
| --- | --- | --- | --- |
| `ci.yml` | C++ CI | 非 `master` 分支 push、目标为 `master` 的 PR | Release 构建测试 → Debug 构建测试和覆盖率报告 |
| `release.yml` | C++ Tag and Release | `master` 分支 push | Release 构建测试 → 打 tag → RelWithDebInfo 构建测试 → 按配置发布产物 |

也可以从 [`workflow-templates/`](workflow-templates/) 复制这两个 YAML 到业务仓库的 `.github/workflows/`。将 `uses` 中的 `COMPANY_ORG/.github` 替换为实际公共仓库，例如 `wwjszz/cicd_template`。`.properties.json` 仅用于页面展示，不需要复制。

`ci.yml` 通过 `needs: build` 保证编译测试成功后才执行 Coverage。两个入口均忽略 tag push，并跳过删除分支的事件。`master` 的任意 push 都会触发发布；需要限制合并时，在仓库规则中要求通过 PR 和 CI 检查。

覆盖率报告在 Actions 的 **Artifacts** 下载。发布产物保存在服务器的 `{发布根目录}/{发布名称}/{tag}/bin/`，同一版本目录保存 `build-info.txt` 和 `SHA256SUMS`，不上传编译产物到 GitHub。

`release.yml` 默认 `deploy-target: none`，仍执行编译、测试和打 tag，但跳过文件发布。`app` 用于系统发布，`strategy` 用于策略发布；选择 `none` 时无需填写 `release-name` 和 `publish-dir`。打标调用项目的 `build.sh -T`，整条流程重跑可能生成新 tag。

## 2. 自己写 workflow、引用和传参

### 使用公共 workflow

三个固定工作流都接收 Secret `CI_SSH_KEY`。`cpp-build.yml`、`cpp-coverage.yml` 没有 `with` 参数；`cpp-release.yml` 支持：

| 参数 | 默认值 | 说明 |
| --- | --- | --- |
| `deploy-target` | `none` | `app` 系统发布，`strategy` 策略发布，`none` 仅构建测试和打 tag |
| `release-name` | 业务仓库名 | 系统或策略的发布名称；`none` 时无需填写 |
| `publish-dir` | runner 配置 | 项目内的产物目录；`none` 时无需填写 |

发布根目录固定取 runner 配置，调用方不传 `release-root`。`app` 对应 `APPLICATION_RELEASE_ROOT` / `APPLICATION_PUBLISH_DIR`，`strategy` 对应 `STRATEGY_RELEASE_ROOT` / `STRATEGY_PUBLISH_DIR`。

公共 workflow 不限制触发事件和分支。需要改为 `main` 分支或增加 `workflow_dispatch` 手动触发时，修改业务仓库入口 workflow 的 `on` 即可。

需要自选 runner、构建类型、测试和覆盖率时，引用 [`cpp-ci.yml`](.github/workflows/cpp-ci.yml)。在业务仓库创建 `.github/workflows/custom-ci.yml`：

```yaml
name: Custom C++ CI

on:
  push:
    branches-ignore: [master]
    tags-ignore: ['**']
  workflow_dispatch:

permissions:
  contents: read

jobs:
  ci:
    uses: COMPANY_ORG/.github/.github/workflows/cpp-ci.yml@main
    with:
      runner-label: cpp-cicd-runner
      build-type: Debug
      run-tests: true
      coverage: true
    secrets:
      CI_SSH_KEY: ${{ secrets.CI_SSH_KEY }}
```

| 参数 | 类型 | 必填 / 默认值 | 说明 |
| --- | --- | --- | --- |
| `runner-label` | string | 必填 | runner 的额外标签，示例为 `cpp-cicd-runner` |
| `build-type` | string | `Release` | `Debug`、`Release`、`RelWithDebInfo` |
| `run-tests` | boolean | `true` | 是否运行测试 |
| `coverage` | boolean | `false` | 是否开启覆盖率构建并上传报告 |

例如普通构建使用 `build-type: Release`、`coverage: false`；覆盖率构建使用 `build-type: Debug`、`coverage: true`。
`coverage: true` 时始终运行测试，即使 `run-tests: false`。
普通参数放在 `with`，密钥放在 `secrets`；boolean 参数使用 `true` / `false`，不加引号。
`cpp-ci.yml` 的触发分支由调用方的 `on` 决定，不包含打标和服务器发布。

### 自己编排每个步骤

在 job 的 `steps` 中依次调用 [`setup`](actions/setup/action.yml) 和 [`build-test`](actions/build-test/action.yml)：

```yaml
- name: Setup
  uses: COMPANY_ORG/.github/actions/setup@main
  with:
    ssh-key: ${{ secrets.CI_SSH_KEY }}

- name: Build and test
  uses: COMPANY_ORG/.github/actions/build-test@main
  with:
    build-type: Debug
    run-tests: "true"
    coverage: "false"
```

`setup` 完成源码 checkout 和 SSH agent 初始化：`ssh-key` 必填，`ref` 可选，留空时检出触发事件对应的源码。
`build-test` 依次执行 Prepare、Build、Test：`build-type` 默认 `Release`，`run-tests` 默认 `"true"`，`coverage` 默认 `"false"`。Action 的开关参数使用字符串 `"true"` / `"false"`；开启 coverage 时始终运行测试。

`build-test` 的 `coverage: "true"` 只开启插桩并运行测试。生成报告还需调用 [`actions/`](actions/action.yml)，传入 `phase: coverage`，再上传 `build/test_coverage/`；完整步骤参考 [`cpp-coverage.yml`](.github/workflows/cpp-coverage.yml)。
单个阶段也可直接调用 `actions/`：`phase` 必填，支持 `prepare`、`build`、`test`、`coverage`、`tag`；`build-type` 和 `coverage` 的默认值分别为 `Release`、`"false"`。打标与服务器发布的完整流程参考 [`cpp-release.yml`](.github/workflows/cpp-release.yml)。

公共 workflow 在 `jobs.<job>.uses` 中引用，Action 在 `steps[].uses` 中引用。当前模板和示例使用公司 `.github` 仓库的 `@main`，接入前需要完成部署并替换组织名；正式使用时也可以固定到已验证的版本 tag 或提交 SHA。
公共实现内部使用 `$/actions/...` 引用同仓库、同一提交的 Action，业务仓库无需复制这些文件。

更多语法见 [GitHub 复用工作流说明](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows)、[同仓库 Action 引用说明](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#jobsjob_idstepsuses)。
