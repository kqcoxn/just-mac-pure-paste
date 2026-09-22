<p align="center">
  <img src="docs/assets/readme-banner.svg" alt="Just Pure Paste — 保留文字，去掉来源格式。Shift + Command + V。" width="960">
</p>

<h1 align="center">Just Pure Paste</h1>

<p align="center">
  一个轻巧的 macOS 菜单栏工具，一个快捷键粘贴纯文本。<br>
  照常复制，按下 <kbd>⇧ Shift</kbd> + <kbd>⌘ Command</kbd> + <kbd>V</kbd>，继续书写。
</p>

<p align="center">
  <a href="https://github.com/kqcoxn/just-mac-pure-paste/actions/workflows/macos.yml"><img src="https://github.com/kqcoxn/just-mac-pure-paste/actions/workflows/macos.yml/badge.svg" alt="macOS 构建与发版状态"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-234f40?style=flat" alt="需要 macOS 14 或更新版本">
  <img src="https://img.shields.io/badge/Swift-6-F05138?style=flat&amp;logo=swift&amp;logoColor=white" alt="使用 Swift 6 构建">
</p>

<p align="center">
  <a href="README.md">English</a> · <strong>简体中文</strong>
</p>

<p align="center">
  <a href="https://github.com/kqcoxn/just-mac-pure-paste/releases"><strong>下载应用</strong></a> ·
  <a href="#快速开始">快速开始</a> ·
  <a href="#从源码构建">从源码构建</a> ·
  <a href="https://github.com/kqcoxn/just-mac-pure-paste/issues">反馈问题</a>
</p>

---

## 让粘贴简单一点

复制文字时，字体、颜色和其他来源格式常常也被一起带走。Just Pure Paste 将剪贴板中的文本转换为纯文本，再向当前应用发送粘贴指令，由目标应用决定文字的显示样式。

| | 功能 |
| --- | --- |
| **一个快捷键** | 默认 **⇧⌘V**，也可以录制自己的全局快捷键，重启后保留。 |
| **文字原样保留** | 去掉来源格式，保留空格、换行、Unicode 字符和 emoji。 |
| **安静驻留** | 菜单栏图标可隐藏；仅在设置窗口显示时出现 Dock 图标，关闭设置后继续运行。 |
| **本地处理剪贴板** | 不保存历史、不上传内容、不做云同步，仅在触发快捷键时读取剪贴板。 |
| **新版本提醒** | 检查 GitHub 正式版，发现更新后提供下载页入口。 |

> **剪贴板行为：**转换后，剪贴板会保持纯文本，不会恢复原来的富文本。空内容、纯图片和文件复制保持不变。

## 快速开始

### 1. 下载并打开

需要 **macOS 14 或更新版本**。在 [GitHub Releases](https://github.com/kqcoxn/just-mac-pure-paste/releases) 中选择适合你的 Mac 的 ZIP：

| 你的 Mac | 压缩包后缀 |
| --- | --- |
| Apple Silicon — M 系列芯片 | `macos-arm64.zip` |
| Intel 芯片 | `macos-x86_64.zip` |

解压，将 **Just Pure Paste.app** 移至“应用程序”并打开。如果暂时没有 Release，可以[从源码构建](#从源码构建)，也可从成功的 [Actions 运行](https://github.com/kqcoxn/just-mac-pure-paste/actions/workflows/macos.yml)下载开发构建。

当前应用使用 ad-hoc 签名，**尚未经过 Apple 公证**。macOS 可能要求你在“系统设置 → 隐私与安全性”中允许打开，详见[分发说明](docs/ci-release.md#签名与验证范围)。

### 2. 授予辅助功能权限

手动启动或再次打开应用都会展示设置；登录时自动启动则在后台驻留。**应用界面目前为简体中文**；本页的语言切换只切换文档。

1. 在应用设置中点击 **请求授权**。
2. 打开 **系统设置 → 隐私与安全性 → 辅助功能**，启用 **Just Pure Paste**；列表中没有时，手动添加 `.app`。
3. 回到应用，点击 **重新检查**，确认状态为 **已授权**。
4. 如果 macOS 另行询问剪贴板访问权限，请允许读取以继续粘贴。

辅助功能权限用于向目标应用发送粘贴按键。

### 3. 复制，然后粘贴

复制文本，点击目标输入框，按下 **⇧⌘V**，松开按键后应用就会发送粘贴指令。

通过菜单栏剪贴板图标 → **设置…** 录制其他快捷键。清除快捷键可暂停热键功能，点击 **恢复默认** 可恢复 ⇧⌘V。如果与其他应用的快捷键冲突，请换一个组合。注册失败会在设置和菜单栏显示提示；后台每两秒尝试恢复，关闭设置不影响恢复。录制时会阻止已知的系统快捷键冲突。其他软件自行拦截按键的冲突无法全部检测，需要调整其中一方的组合。普通 **⌘V** 保持原有行为，也不能被设置成本工具的快捷键。

关闭设置后应用继续驻留。按住 ⌘ 拖走菜单栏图标只会隐藏图标，快捷键继续生效，隐藏状态会保留到下次启动。再次打开 App 即可唤起设置；通过 **在菜单栏显示图标** 开关可恢复图标。要停止运行，可在菜单栏选择 **退出 Just Pure Paste**，或在设置窗口中按 ⌘Q。

## 登录时自动启动

首次运行会默认开启 **登录时自动启动**，应用会在登录 Mac 后后台运行，不弹出设置窗口。关闭开关即可取消，之后启动会保留你的选择。若提示需要批准，点击 **打开登录项设置** 并在系统设置中允许；返回应用后会刷新实际状态。

## 检查更新

默认启用自动检查：首次运行检查一次，之后在应用运行期间，距离上次请求满 **24 小时**再检查。可在设置中关闭自动检查，仍可手动点击 **检查更新**。手动请求最短间隔为一分钟；上次请求时间与已发现的新版本会保存，重启不会重复请求。

仅查询本仓库的公开正式 Release。发现新版本后，菜单栏图标变为下载提示，并提供发布页入口。**下载和安装由你手动完成。** 检查失败仅显示状态，不中断粘贴。

更新请求不携带账号令牌、剪贴板内容或其他应用使用记录。应用不提供剪贴板历史或云同步。

## 从源码构建

在 macOS 上使用 **Swift 6.2+**、Python 3 和项目构建脚本。CI 使用 Xcode 26.2；Command Line Tools 构建路径还要求本机已安装 macOS 26 SDK。

```bash
git clone https://github.com/kqcoxn/just-mac-pure-paste.git
cd just-mac-pure-paste
./scripts/swift.sh test
./scripts/setup-dev-signing.sh  # one-time setup
./scripts/dev.sh               # build, install, and launch
```

日常开发使用固定的本地自签名证书，私钥保存在登录钥匙串，不进入仓库。首次执行 `setup-dev-signing.sh` 时 macOS 可能要求确认钥匙串操作；已有证书会复用，不会每次生成。也可设置 `DEV_SIGNING_IDENTITY` 使用已有开发证书的名称。

之后只需运行 `./scripts/dev.sh`：先构建并验证签名，再退出旧开发版、安装到 `~/Applications/Just Pure Paste Dev.app` 并启动。开发版使用独立 Bundle ID `com.justmacpurepaste.app.dev`；首次使用需为开发版授予辅助功能权限。保持同一证书与应用身份，以便系统在重建后继续识别授权。请勿同时运行发布版与开发版，以免争抢快捷键。不要删除开发证书或私钥；更换证书可能需要重新授权。

`./scripts/build-app.sh` 默认仅构建开发版，产物在 `dist/development/Just Pure Paste Dev.app`。发布构建显式使用 `./scripts/build-app.sh --release`，产物仍为 `dist/Just Pure Paste.app`，Bundle ID 为 `com.justmacpurepaste.app`，使用 ad-hoc 签名且不公证。CI 使用发布模式，不使用本机开发证书。发布版更新后仍可能需要重新授权；允许打开下载的应用与辅助功能授权是不同步骤。

<details>
<summary><strong>构建兼容与依赖处理</strong></summary>

[KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) 固定为 **3.1.0**，具体提交记录在 `Package.resolved`。

Command Line Tools 缺少该依赖所用的 SwiftUI 宏插件。在此环境中，`scripts/swift.sh` 使用已安装的 macOS 26 SDK 和 SwiftPM native 构建，对可清理的 `.build` 依赖缓存做兼容处理：将 `@Entry` 展开为等价的 `EnvironmentKey`，移除三段仅用于设计预览的 `#Preview`。不改动快捷键逻辑或锁定版本；清理缓存后脚本会重新应用。

完整 Xcode 环境不需要这些宏兼容转换。所有环境还会调整依赖资源查找入口，使本地化资源能放入 `Contents/Resources` 并通过签名验证。CLT 环境请使用脚本，不要直接运行 `swift build` / `swift test`；脚本不会安装 SDK 或修改系统工具。

</details>

## 常见问题

| 情况 | 排查方式 |
| --- | --- |
| 没有粘贴出内容 | 确认辅助功能已授权，并点击可编辑的输入框。提示音响起后，在菜单栏或设置中查看原因。 |
| 更新后权限失效 | ad-hoc 签名应用重建或移动后，可能需要重新授予辅助功能权限。 |
| 操作被取消 | 最多等待一秒让修饰键释放；操作期间切换应用或改变剪贴板会取消本次操作，不自动重试。 |
| 状态显示 **已发送粘贴** | 仅表示按键事件已发出，不保证目标输入框已经接收。 |
| 个别应用表现不同 | 安全输入框、远程桌面等特殊场景可能不接收模拟按键。 |

<details>
<summary><strong>文本转换与剪贴板边界</strong></summary>

优先读取纯文本表示；仅 RTF 的内容可以提取文本。HTML-only 且没有文本表示的内容不做 HTML 解析。

macOS 剪贴板没有系统级比较并交换接口。应用会在写入前检查变化，但仍存在很小的竞争窗口。写入失败，或写入后目标应用、权限立即变化时，可能已经移除来源格式，即使最终没有发送粘贴。应用不会恢复剪贴板，也不会自动重试。

</details>

## 项目文档

以下详细工程文档目前使用中文。

| 文档 | 内容 |
| --- | --- |
| [项目方案](docs/project-plan.md) | 功能范围、架构与行为约定 |
| [CI 与发版](docs/ci-release.md) | Apple Silicon / Intel 构建、版本标签、压缩包与校验值 |
| [验证记录](docs/verification.md) | 已完成检查、验证环境与待验证项目 |

推送到 `main`、提交 PR 或手动运行时，CI 会测试并打包两个架构。推送 `v*` 版本标签后，两个构建均成功才发布 GitHub Release；预发布标签会生成预发布版本。具体步骤见发版文档。

**验证范围：**本机自动测试、arm64 构建与打包已通过。Safari、VS Code、微信和 WPS 的真实粘贴仍待辅助功能授权后验证；macOS 14 与 Intel 运行兼容性也待验证。具体状态以验证记录为准。

---

使用 SwiftUI、AppKit 和 [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) 构建。
