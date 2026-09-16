# GitHub 构建与发版

工作流：`.github/workflows/macos.yml`。

## 触发规则

| 事件 | 行为 |
| --- | --- |
| 推送到 `main` | 测试、编译、打包，上传 Actions 构建附件 |
| Pull Request | 同上，不发布 Release |
| Actions 中手动运行 | 构建所选分支或标签，不发布 Release |
| 推送 `v*` 标签 | 校验版本，两个架构均通过测试和构建后发布 Release |

固定使用 Xcode 26.2，分别在 `macos-15`（arm64）与 `macos-15-intel`（x86_64）上构建和测试。两个架构使用同一套本地脚本与锁定依赖。工作流校验运行器实际架构，并检查 `Package.resolved` 未被构建修改。

PR 和常规构建仅有仓库读取权限；仅发布任务使用 `contents: write`。使用 GitHub 自动提供的 `GITHUB_TOKEN`，不需要配置个人访问令牌或 Apple 证书。

## 发布版本

先提交并推送代码和工作流，再对需要发布的提交打标签：

```bash
git tag -a v0.1.0 -m "Release v0.1.0"
git push origin v0.1.0
```

稳定版标签格式为 `v主版本.次版本.补丁版本`，例如 `v0.1.0`。预发布支持 `v0.2.0-beta.1`，会自动标记为 GitHub Pre-release。各数字部分不接受前导零，不接受构建元数据 `+...`；不符合规则的 `v*` 标签会明确失败，不会发布。

标签提供应用的 `CFBundleShortVersionString`（预发布后缀不写入此字段），Actions 的运行编号提供 `CFBundleVersion`。无需为了每次标签发布手动修改 plist；本地不指定版本时仍使用 plist 默认值。

Release 附件：

- `JustPurePaste-v0.1.0-macos-arm64.zip`
- `JustPurePaste-v0.1.0-macos-x86_64.zip`
- `SHA256SUMS.txt`

ZIP 使用 `ditto` 保留应用结构、执行权限和资源。每个构建会解压一次，验证签名、可执行文件、依赖本地化资源与许可证。发布任务再次检查两个 ZIP 的 SHA-256 校验值，然后才发布。

Release 先创建为草稿；上传完整后才公开。上传中途失败可在 Actions 重跑，继续完成同一草稿。已公开的同名 Release 不会自动覆盖，应使用新版本标签。不要移动已发布标签。

## 获取开发构建

进入 GitHub → Actions → macOS CI and Release → 对应运行，下载 `macos-arm64` 或 `macos-x86_64` 附件。附件保留 14 天；其中包含应用 ZIP 和对应 `.sha256` 文件。普通分支构建文件名使用提交 SHA，便于定位版本。

## 本地复用

```bash
./scripts/swift.sh test
APP_VERSION=0.2.0 APP_BUILD_NUMBER=2 ./scripts/build-app.sh
./scripts/package-release.sh v0.2.0 "$(uname -m)"
cd dist
shasum -a 256 -c JustPurePaste-v0.2.0-macos-*.zip.sha256
```

本地仅打包当前机器架构，脚本会拒绝为 arm64 二进制标注 x86_64，反之亦然。`release-info.py` 只校验标签并输出版本字段，不执行发布。

## 签名与验证范围

沿用 ad-hoc 签名，没有 Apple Developer ID 签名或公证。签名检查验证包的完整性，不等于 Gatekeeper 的开发者信任认证。用户从 GitHub 下载后可能需要按系统设置中的提示允许打开；不应关闭系统安全功能。辅助功能权限仍由用户自行授予。

CI 不启动应用、不申请辅助功能权限、不模拟向真实应用粘贴。自动测试使用独立剪贴板和按键替身。

此工作流已进行本地语法检查和 arm64 构建、ZIP 解压及校验测试；真实 GitHub 运行器、Intel 构建和 Release 发布需要在推送工作流/标签后验证。当前没有自动提交、推送、打标签或创建线上 Release。
