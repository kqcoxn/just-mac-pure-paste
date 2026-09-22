import AppKit
import KeyboardShortcuts
import Observation
import PasteCore
import SwiftUI
import UpdateCore

extension KeyboardShortcuts.Name {
    static let purePaste = Self("purePaste", initial: .init(.v, modifiers: [.shift, .command]))
}

@MainActor
@Observable
final class AppModel {
    let permission = PermissionService()
    let launchAtLogin = LaunchAtLoginService()
    let updates = UpdateService(currentVersion:
        Bundle.main.object(forInfoDictionaryKey: "JPPReleaseTag") as? String
        ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        ?? "unknown")
    private var pasteStatus = "就绪"
    private var pasteFailed = false
    private(set) var shortcutState: ShortcutState = .ready
    var status: String { shortcutState == .ready ? pasteStatus : shortcutState.message }
    var hasFailure: Bool { shortcutState == .unavailable || pasteFailed }
    private(set) var shortcutLabel = ""
    @ObservationIgnored private let coordinator = PasteCoordinator(environment: SystemPasteEnvironment())
    @ObservationIgnored private var shortcutService: ShortcutService?
    @ObservationIgnored private var shortcutMonitor: Task<Void, Never>?
    @ObservationIgnored private var pasteTask: Task<Void, Never>?

    init(startUpdates: Bool = true) {
        shortcutService = ShortcutService { [weak self] in self?.triggerPaste() }
        refreshShortcut()
        // App-owned: closing Settings must not stop recovery from a failed registration.
        shortcutMonitor = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 2_000_000_000) } catch { return }
                guard let self else { return }
                self.refreshShortcut()
            }
        }
        if startUpdates { updates.start() }
    }
    func refreshShortcut() {
        shortcutLabel = KeyboardShortcuts.getShortcut(for: .purePaste)?.description ?? "未设置"
        shortcutState = shortcutService?.refresh() ?? .paused
    }
    func restoreShortcut() {
        shortcutService?.reset()
        refreshShortcut()
    }
    private func triggerPaste() {
        guard pasteTask == nil else { return }
        pasteTask = Task { [weak self] in
            guard let self else { return }
            let result = await coordinator.paste()
            permission.refresh()
            pasteStatus = result.message
            pasteFailed = result != .sent && result != .busy
            if hasFailure { NSSound.beep() }
            pasteTask = nil
        }
    }
    func stop() {
        pasteTask?.cancel()
        shortcutMonitor?.cancel()
        shortcutService?.stop()
        updates.stop()
    }
}

struct SettingsView: View {
    let model: AppModel
    let menuBar: MenuBarController
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 32))
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Just Pure Paste").font(.title2.bold())
                        Text("复制内容，按下快捷键，只粘贴文本。")
                            .foregroundStyle(.secondary)
                    }
                }
                Toggle("在菜单栏显示图标", isOn: Binding(
                    get: { menuBar.isVisible },
                    set: { menuBar.setVisible($0) }
                ))
                LaunchAtLoginSettingsView(service: model.launchAtLogin)
                GroupBox("全局快捷键") {
                    VStack(alignment: .leading, spacing: 12) {
                        KeyboardShortcuts.Recorder("纯文本粘贴", name: .purePaste) { _ in
                            model.refreshShortcut()
                        }
                        .shortcutValidation { shortcut in
                            shortcut == .init(.v, modifiers: [.command])
                                ? .disallow(reason: String("请保留 ⌘V 用于普通粘贴，选择其他组合。")) : .allow
                        }
                        .keyboardShortcutsConflictPolicy(.init(systemShortcut: .block))
                        Text(model.shortcutState.message)
                            .font(.caption)
                            .foregroundStyle(model.shortcutState == .unavailable ? .orange : .secondary)
                        Text("若其他软件也使用此组合，请修改其中一方的快捷键；开发版和正式版请只运行一个。")
                            .font(.caption).foregroundStyle(.secondary)
                        HStack {
                            Text("默认 ⇧⌘V；清除快捷键可暂停使用。")
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button("恢复默认") { model.restoreShortcut() }
                        }
                    }.padding(8)
                }
                GroupBox("辅助功能权限") {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(model.permission.granted ? "已授权" : "尚未授权",
                              systemImage: model.permission.granted ? "checkmark.circle.fill" : "exclamationmark.circle")
                            .foregroundStyle(model.permission.granted ? .green : .orange)
                        Text("用于向当前应用发送粘贴按键。请在系统设置的“隐私与安全性 → 辅助功能”中允许 Just Pure Paste。")
                            .font(.callout).foregroundStyle(.secondary)
                        HStack {
                            if !model.permission.granted {
                                Button("请求授权") { model.permission.request() }
                            }
                            Button("打开系统设置") { model.permission.openSystemSettings() }
                            Button("重新检查") { model.permission.refresh() }
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
                }
                UpdateSettingsView(updates: model.updates)
                Text("粘贴后，剪贴板会保持纯文本，原有格式不会恢复。保留换行、空格和 emoji；图片和文件不会被转换。")
                    .font(.callout).foregroundStyle(.secondary)
                Text("仅在触发快捷键时读取剪贴板，不保存历史、不上传内容。若系统询问剪贴板访问权限，请允许以继续粘贴。")
                    .font(.caption).foregroundStyle(.secondary)
                Divider()
                Label(model.status, systemImage: model.hasFailure ? "exclamationmark.circle" : "info.circle")
                    .font(.callout).textSelection(.enabled)
            }
            .padding(24)
        }
        .frame(width: 480, height: 660)
        .background(SettingsWindowDockPresence())
        .task {
            // This task never reads the clipboard. Refresh while this settings window is active.
            while !Task.isCancelled {
                if NSApplication.shared.isActive {
                    model.permission.refresh()
                    model.launchAtLogin.refresh()
                }
                do { try await Task.sleep(nanoseconds: 1_000_000_000) } catch { return }
            }
        }
    }
}

private struct LaunchAtLoginSettingsView: View {
    @Bindable var service: LaunchAtLoginService

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("登录时自动启动", isOn: $service.isEnabled)
            Text("登录 Mac 后在后台运行，不弹出设置窗口。")
                .font(.caption).foregroundStyle(.secondary)
            if service.status == .requiresApproval {
                Text("请在系统设置的登录项中允许 Just Pure Paste 自动启动。")
                    .font(.caption).foregroundStyle(.orange)
                Button("打开登录项设置") { service.openSystemSettings() }
            }
            if service.status == .notFound {
                Text("无法找到应用，请将完整的 App 移至“应用程序”后重新打开。")
                    .font(.caption).foregroundStyle(.orange)
            }
            if let error = service.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled)
            }
        }
    }
}

private struct UpdateSettingsView: View {
    @Bindable var updates: UpdateService

    var body: some View {
        GroupBox("软件更新") {
            VStack(alignment: .leading, spacing: 10) {
                Text("当前版本：\(updates.currentVersion)")
                Toggle("自动检查更新（每天一次）", isOn: $updates.automaticallyChecks)
                Text(updates.status).font(.callout).textSelection(.enabled)
                if let checked = updates.lastChecked {
                    Text("上次成功检查：\(checked.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                HStack {
                    Button(updates.isChecking ? "正在检查…" : "检查更新") {
                        Task { await updates.check() }
                    }
                    .disabled(updates.isChecking)
                    if let release = updates.availableRelease {
                        Button("下载 \(release.tag)…") { NSWorkspace.shared.open(release.url) }
                    }
                }
                Text("仅查询 GitHub 正式版，不上传剪贴板内容。下载按钮打开发布页，由你选择并安装新版本。")
                    .font(.caption).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
        }
    }
}
