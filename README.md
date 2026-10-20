# C++ CI/CD 模板

本仓库集中保存 C++ 项目的接入模板、公共工作流和执行脚本。交付时将仓库内容整体放入公司组织的 `.github` 仓库，保留下面的目录结构，包括隐藏目录 `.github/`：

```text
仓库根目录/
├── README.md
├── scripts/                 # 业务仓库 workflow 安装脚本
├── workflow-templates/       # 业务仓库入口模板和展示信息
├── .github/workflows/       # 可复用工作流
└── actions/                 # 按操作划分的 Action 和公共容器入口
```

## 部署到公司组织

公司公共仓库使用 `COMPANY_ORG/.github` 的 `master` 分支，建议将其设为该仓库的默认分支。部署时保留完整目录结构，包括仓库内的 `.github/`。

测试仓库 `wwjszz/cicd_template` 和公司公共仓库统一使用 `master`。安装脚本从 `master` 获取入口模板，入口中的公共 workflow 引用也使用 `@master`。

配置业务仓库使用 runner、`CI_SSH_KEY` 和公共 workflow/Action 的权限。通过 GitHub 页面或手动复制入口时，将 `COMPANY_ORG/.github` 替换为实际公共仓库；安装脚本会替换这个仓库名。

公司引用示例为 `COMPANY_ORG/.github/.github/workflows/cpp-build.yml@master`：前一个 `.github` 是仓库名，后一个是目录。公共实现内部的 `$/actions/...` 始终引用同仓库、同一提交的 Action，无需修改。

公共仓库的 `@master` 决定模板版本；入口里的 `on.push.branches: [master]` 决定业务发布分支，两者分别配置。

## 使用前准备

使用前准备好：

- 仓库或组织 Secret `CI_SSH_KEY`，用于拉取源码、私有依赖和推送 tag，并授权业务仓库使用。
- 在线 runner，标签包含 `self-hosted, linux, x64, cpp-cicd-runner`；提供 Docker 和镜像 `localhost:5000/cxx_builder_devtoolset_8:1.3`。
- 可执行的项目 `./build.sh`，支持 `-b -t Release`、`-b -t Debug -C`、`-b -t RelWithDebInfo`、`-T`。构建输出到 `build/`，测试程序放在 `build/run_test/`；`-T` 负责创建并推送新 tag。
- `CI_SSH_KEY` 对应的 SSH 身份需要推送 tag 的权限。发布步骤将指定产物目录移动到服务器版本目录，入口使用 `permissions: contents: read`。
- 发布用 runner 配置并挂载 `APPLICATION_RELEASE_ROOT`、`STRATEGY_RELEASE_ROOT`；默认产物目录分别由 `APPLICATION_PUBLISH_DIR`、`STRATEGY_PUBLISH_DIR` 指定。

## 1. 接入业务仓库

### 通过脚本安装

在业务仓库的 Git 工作区内执行安装脚本：

```bash
bash /path/to/install-workflows.sh --repo COMPANY_ORG/.github
```

替换实际组织名。脚本可以单独分发，执行者需要该模板仓库的 SSH 读取权限。使用个人测试仓库时，参数改为 `--repo wwjszz/cicd_template`。

脚本通过 SSH 读取模板仓库的 `master` 分支，只安装 `ci.yml`、`release.yml` 两个入口到业务仓库的 `.github/workflows/`，并替换公共仓库名称。

- 触发规则沿用入口模板：非 `master` 分支 push、目标为 `master` 的 PR 依次运行 build、coverage；`master` push 运行 release。
- release 默认 `deploy-target: none`；系统发布改为 `app`，策略发布改为 `strategy`。
- 已有相同文件跳过；存在不同内容的同名文件则停止安装，不覆盖文件。

### 通过 GitHub 页面或手动复制

将模板部署到组织的 `.github` 仓库后，在业务仓库打开 **Actions → New workflow**，选择以下两个模板：

| 模板文件 | GitHub 页面名称 | 触发条件 | 执行内容 |
| --- | --- | --- | --- |
| `ci.yml` | C++ CI | 非 `master` 分支 push、目标为 `master` 的 PR | Release 构建测试 → Debug 构建测试和覆盖率报告 |
| `release.yml` | C++ Tag and Release | `master` 分支 push | Release 构建测试 → 打 tag → RelWithDebInfo 构建测试 → 按配置发布产物 |

也可以从 [`workflow-templates/`](workflow-templates/) 复制这两个 YAML 到业务仓库的 `.github/workflows/`。将 `uses` 中的 `COMPANY_ORG/.github` 替换为实际公共仓库，例如 `KkingAlpha/.github`。`.properties.json` 仅用于页面展示，不需要复制。

`ci.yml` 通过 `needs: build` 保证编译测试成功后才执行 Coverage。两个入口均忽略 tag push，并跳过删除分支的事件。`master` 的任意 push 都会触发发布；需要限制合并时，在仓库规则中要求通过 PR 和 CI 检查。

覆盖率报告在 Actions 的 **Artifacts** 下载，保留 30 天。发布步骤将 `publish-dir` 指定的目录整体移动到服务器的 `{发布根目录}/{发布名称}/{tag}/` 下，并保留目录名。例如 `publish-dir: build/bin` 的结果是 `{发布根目录}/{发布名称}/{tag}/bin/`，工作区中原来的 `build/bin` 随之移走。服务器产物的保留时间单独管理，不受 Artifact 的 30 天配置影响。同版本目录已存在时，打印提醒后删除旧目录，再放入本次产物；移动失败不会自动恢复旧产物。

发布只负责文件落盘，不启动或重启业务进程，也不创建 GitHub Release。

`release.yml` 默认 `deploy-target: none`，仍执行编译、测试和打 tag，但跳过文件发布。`app` 用于系统发布，`strategy` 用于策略发布；选择 `none` 时无需填写 `release-name` 和 `publish-dir`。打标调用项目的 `build.sh -T`，整条流程重跑可能生成新 tag。

## 2. 自己写 workflow、引用和传参

### 使用公共 workflow

标准流程使用 `cpp-build.yml`、`cpp-coverage.yml`、`cpp-release.yml`；只调整参数时使用 `cpp-ci.yml`；需要插入自定义步骤或调整执行顺序时，直接组合独立 Action。

三个固定工作流都接收 Secret `CI_SSH_KEY`。`cpp-build.yml`、`cpp-coverage.yml` 没有 `with` 参数；`cpp-release.yml` 支持：

| 参数 | 默认值 | 说明 |
| --- | --- | --- |
| `deploy-target` | `none` | `app` 系统发布，`strategy` 策略发布，`none` 仅构建测试和打 tag |
| `release-name` | 业务仓库名 | 系统或策略的发布名称；`none` 时无需填写 |
| `publish-dir` | runner 配置 | 项目内的产物目录；`none` 时无需填写 |

发布根目录固定取 runner 配置，调用方不传 `release-root`。`app` 对应 `APPLICATION_RELEASE_ROOT` / `APPLICATION_PUBLISH_DIR`，`strategy` 对应 `STRATEGY_RELEASE_ROOT` / `STRATEGY_PUBLISH_DIR`。

公共 workflow 不限制触发事件和分支。需要改为 `main` 分支或增加 `workflow_dispatch` 手动触发时，修改业务仓库入口 workflow 的 `on` 即可。

需要调整 runner、构建类型、测试或覆盖率开关时，可以直接调用 [`cpp-ci.yml`](.github/workflows/cpp-ci.yml)。它是可配置的 C++ 构建工作流，不包含打 tag 和服务器发布，也不接受自定义构建命令。例如在业务 workflow 的 `jobs` 下添加：

```yaml
jobs:
  ci:
    uses: COMPANY_ORG/.github/.github/workflows/cpp-ci.yml@master
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

五个独立 Action 分别负责源码准备、编译测试、覆盖率报告、打标和服务器发布：

| Action | 输入 | 输出或结果 |
| --- | --- | --- |
| [`setup`](actions/setup/action.yml) | `ssh-key`，可选 `ref` | 检出源码并启动 SSH agent |
| [`build-test`](actions/build-test/action.yml) | `build-type`、`run-tests`、`coverage` | 初始化项目、编译并按配置运行测试 |
| [`coverage`](actions/coverage/action.yml) | 无 | 从已有覆盖率数据生成 `build/test_coverage/` |
| [`tag`](actions/tag/action.yml) | 无 | 创建并推送一个新 tag，通过 `outputs.tag` 返回名称 |
| [`publish`](actions/publish/action.yml) | `deploy-target`、`release-name`、`release-tag`，可选 `publish-dir` | 将产物目录移动到服务器版本目录 |

在 job 的 `steps` 中依次调用 [`setup`](actions/setup/action.yml) 和 [`build-test`](actions/build-test/action.yml)：

```yaml
- name: Setup
  uses: COMPANY_ORG/.github/actions/setup@master
  with:
    ssh-key: ${{ secrets.CI_SSH_KEY }}

- name: Build and test
  uses: COMPANY_ORG/.github/actions/build-test@master
  with:
    build-type: Debug
    run-tests: "true"
    coverage: "false"
```

`setup` 完成源码 checkout 和 SSH agent 初始化：`ssh-key` 必填，`ref` 可选，留空时检出触发事件对应的源码。
`build-test` 依次执行 Prepare、Build、Test：`build-type` 默认 `Release`，`run-tests` 默认 `"true"`，`coverage` 默认 `"false"`。Action 的开关参数使用字符串 `"true"` / `"false"`；开启 coverage 时始终运行测试。

`build-test` 的 `coverage: "true"` 只开启插桩并运行测试。生成报告需要在同一个 job 中调用 `coverage`，报告上传和保留时间由 workflow 配置。上方编译步骤设置 `build-type: Debug`、`coverage: "true"` 后，可以接上：

```yaml
- name: Generate coverage report
  uses: COMPANY_ORG/.github/actions/coverage@master

- name: Upload coverage report
  uses: actions/upload-artifact@v7.0.2
  with:
    name: coverage-report
    path: build/test_coverage/
    if-no-files-found: error
    retention-days: 30
```

打标前先完成 `setup` 和 Release 编译测试，再调用 `tag`：

```yaml
- name: Generate and push version tag
  id: version
  uses: COMPANY_ORG/.github/actions/tag@master
```

同一 job 的后续步骤通过 `${{ steps.version.outputs.tag }}` 获取版本号；跨 job 使用时，先映射为 job output，再通过 `needs` 获取。Action 内部处理版本号的读取和校验，workflow 无需读取中间文件。完整打标、按 tag 检出、RelWithDebInfo 编译测试和服务器发布的顺序参考 [`cpp-release.yml`](.github/workflows/cpp-release.yml)。

旧版直接调用 `actions/` 并传入 `phase` 的自定义 workflow，需要迁移到对应的独立 Action。项目初始化、编译和测试统一由 `build-test` 处理。

公共 workflow 在 `jobs.<job>.uses` 中引用，Action 在 `steps[].uses` 中引用。本 README 的公司示例使用 `.github` 仓库的 `@master`，接入前需要完成部署并替换组织名；正式使用时也可以固定到已验证的版本 tag 或提交 SHA。
公共实现内部使用 `$/actions/...` 引用同仓库、同一提交的 Action，业务仓库无需复制这些文件。

更多语法见 [GitHub 复用工作流说明](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows)、[同仓库 Action 引用说明](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#jobsjob_idstepsuses)。

## 3. Action 代码结构

每个操作的 Action 定义与脚本放在同一个目录：

```text
actions/
├── setup/
│   └── action.yml
├── build-test/
│   ├── action.yml
│   ├── prepare.sh
│   ├── build.sh
│   └── test.sh
├── coverage/
│   ├── action.yml
│   └── coverage.sh
├── tag/
│   ├── action.yml
│   └── tag.sh
├── publish/
│   ├── action.yml
│   └── publish.sh
└── shared/
    ├── run-container.sh
    └── container-entrypoint.sh
```

`build-test`、`coverage` 和 `tag` 通过 `shared/run-container.sh` 启动编译容器，复用工作区挂载、SSH agent 和镜像配置。公共入口将这些脚本放入共享临时目录供 Docker 挂载，容器内的 `container-entrypoint.sh` 启用工具链后执行指定脚本。

`setup` 和 `publish` 在 runner 环境执行。公共 workflow 负责操作顺序、job 依赖、runner 选择和 Artifact 上传；业务仓库入口负责触发事件和业务发布参数。
