# C++ CI/CD 模板

本仓库集中保存 C++ 项目的接入模板、公共工作流和执行脚本。交付时将仓库内容整体放入公司组织的 `.github` 仓库，保留下面的目录结构，包括隐藏目录 `.github/`：

```text
仓库根目录/
├── README.md
├── workflow-templates/       # 业务仓库入口模板和展示信息
├── .github/workflows/       # 可复用工作流
└── actions/                 # 公共 Action、容器入口和阶段脚本
```

## 部署到公司组织

1. 将完整内容放入公司 `.github` 仓库的 `main` 分支；公司仓库已有其他文件时保留这些文件。
2. 将三个 `workflow-templates/*.yml` 和本 README 示例中的 `COMPANY_ORG` 替换为实际公司组织名。它是交付占位符，GitHub 不会自动替换。
3. 配置目标业务仓库对 runner、`CI_SSH_KEY` 和公共 workflow/Action 的使用权限。
4. 核对业务主分支名称。当前入口使用 `master`；公司公共实现的 `@main` 是另一项配置，不会自动改变业务主分支规则。

业务入口跨仓库调用 `COMPANY_ORG/.github/.github/workflows/...@main`；两个 `.github` 分别是仓库名和仓库内目录。公共实现内部使用 `$/actions/...` 引用同仓库、同一提交的 Action，迁移时无需填写组织名。接入模板生成到业务仓库后属于该业务仓库，因此跨仓库入口不能改成 `$/`。

## 使用前准备

使用前准备好：

- 仓库或组织 Secret `CI_SSH_KEY`，用于拉取源码、私有依赖和推送 tag，并授权业务仓库使用。
- 在线 runner，标签包含 `self-hosted, linux, x64, cpp-cicd-runner`；提供 Docker 和镜像 `localhost:5000/cxx_builder_devtoolset_8:1.3`。
- 可执行的项目 `./build.sh`，支持 `-b -t Release`、`-b -t Debug -C`、`-b -t RelWithDebInfo`、`-T`。构建输出到 `build/`，测试程序放在 `build/run_test/`；`-T` 负责创建并推送新 tag。
- 发布入口的调用 job 需要 `permissions: contents: write`，供 GitHub Release 发布使用；推送 tag 使用的 SSH 身份也需要相应写权限。入口模板已经包含发布 job 的 token 权限声明。

## 1. 使用三个模板

| 模板文件 | GitHub 页面名称 | 触发条件 | 执行内容 |
| --- | --- | --- | --- |
| `cpp-build.yml` | C++ 构建与测试（非 master） | 非 `master` 分支 push | Release 构建、测试 |
| `cpp-coverage.yml` | C++ 覆盖率（非 master） | 非 `master` 分支 push | Debug 构建、测试、上传覆盖率报告 |
| `cpp-release.yml` | C++ 打标与归档（仅 master） | 仅 `master` 分支 push | 构建测试、打 tag、RelWithDebInfo 构建测试、保存 artifact、发布 GitHub Release |

1. 在业务仓库打开 **Actions → New workflow**，搜索上面的模板名称，点击 **Configure**。
2. 按需添加模板，将生成的 YAML 提交到业务仓库的 `.github/workflows/`。
3. 向开发分支 push 运行 build、coverage；向 `master` push 运行 release。

也可以直接复制本仓库 [`workflow-templates/`](workflow-templates/) 下的三个 `.yml` 到业务仓库的 `.github/workflows/`，不需要复制 `.properties.json`。

三个模板都忽略 tag push，并在外层调用 job 中跳过删除分支的事件。默认 build、coverage 在非 `master` 分支运行，release 在 `master` 运行；这些触发规则由业务仓库的入口 workflow 控制。
覆盖率报告和发布归档在对应 Actions 运行页面的 **Artifacts** 下载。发布流程还会创建 GitHub Release、自动生成 release notes，并上传 `build-output.tar.gz`、`build-info.txt` 和 `SHA256SUMS` 三个附件。

发布流程在同一次运行中先完成 Release 编译、测试和打标，再检出生成的 tag 执行 RelWithDebInfo 编译、测试和归档。当前打标阶段每次调用项目的 `build.sh -T` 生成一个新 tag；整条流程重跑可能再次生成版本，不应视为同一版本的幂等重试。

## 2. 自己写 workflow、引用和传参

### 使用公共 workflow

三个固定工作流 `cpp-build.yml`、`cpp-coverage.yml`、`cpp-release.yml` 只接收 Secret `CI_SSH_KEY`，没有可通过 `with` 修改的输入参数。
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
`cpp-ci.yml` 的触发分支由调用方的 `on` 决定，不包含打标和发布归档。

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
单个阶段也可直接调用 `actions/`：`phase` 必填，支持 `prepare`、`build`、`test`、`coverage`、`tag`、`package`；`build-type` 和 `coverage` 的默认值分别为 `Release`、`"false"`。打标与归档的完整流程参考 [`cpp-release.yml`](.github/workflows/cpp-release.yml)。

公共 workflow 在 `jobs.<job>.uses` 中引用，Action 在 `steps[].uses` 中引用。当前模板和示例使用公司 `.github` 仓库的 `@main`，接入前需要完成部署并替换组织名；正式使用时也可以固定到已验证的版本 tag 或提交 SHA。
公共实现内部使用 `$/actions/...` 引用同仓库、同一提交的 Action，业务仓库无需复制这些文件。

更多语法见 [GitHub 复用工作流说明](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows)、[同仓库 Action 引用说明](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#jobsjob_idstepsuses)。
