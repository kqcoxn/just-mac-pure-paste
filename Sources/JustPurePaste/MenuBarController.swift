import AppKit
import Observation

/// An optional status item, independent of the lifetime of the app and hotkey.
@MainActor
@Observable
final class MenuBarController: NSObject, NSMenuDelegate {
    private(set) var isVisible = true
    @ObservationIgnored private let model: AppModel
    @ObservationIgnored private let showSettings: () -> Void
    @ObservationIgnored private let statusItem: NSStatusItem
    @ObservationIgnored private var visibilityObservation: NSKeyValueObservation?

    init(model: AppModel, showSettings: @escaping () -> Void) {
        self.model = model
        self.showSettings = showSettings
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        // AppKit persists both Command-drag removal and the Settings toggle.
        statusItem.autosaveName = "JustPurePasteStatusItem"
        statusItem.behavior = [.removalAllowed]
        isVisible = statusItem.isVisible
        visibilityObservation = statusItem.observe(\.isVisible, options: [.new]) { [weak self] _, _ in
            // AppKit changes status item visibility on the main thread; KVO is synchronous.
            MainActor.assumeIsolated {
                guard let self else { return }
                self.isVisible = self.statusItem.isVisible
            }
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        updateIcon()
    }

    func setVisible(_ visible: Bool) { statusItem.isVisible = visible }

    private func updateIcon() {
        withObservationTracking {
            let symbol = model.updates.availableRelease != nil ? "arrow.down.circle"
                : (model.hasFailure ? "doc.on.clipboard.fill" : "doc.on.clipboard")
            let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Just Pure Paste")
            image?.isTemplate = true
            statusItem.button?.image = image
            statusItem.button?.toolTip = "Just Pure Paste · \(model.shortcutLabel) · \(model.status) · \(model.updates.status)"
        } onChange: { [weak self] in
            Task { @MainActor in self?.updateIcon() }
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        add("纯文本粘贴 · \(model.shortcutLabel)", to: menu)
        add(model.status, to: menu)
        if !model.permission.granted { add("需要辅助功能权限", to: menu) }
        menu.addItem(.separator())
        add("设置…", action: #selector(openSettings), key: ",", to: menu)
        add(model.updates.isChecking ? "正在检查更新…" : "检查更新…",
            action: model.updates.isChecking ? nil : #selector(checkUpdates), to: menu)
        add(model.updates.status, to: menu)
        if let release = model.updates.availableRelease {
            add("下载新版本 \(release.tag)…", action: #selector(downloadUpdate), to: menu)
        }
        menu.addItem(.separator())
        add("退出 Just Pure Paste", action: #selector(quit), key: "q", to: menu)
    }

    private func add(_ title: String, action: Selector? = nil, key: String = "", to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
    }

    @objc private func openSettings() { showSettings() }
    @objc private func checkUpdates() { Task { await model.updates.check() } }
    @objc private func downloadUpdate() {
        if let release = model.updates.availableRelease { NSWorkspace.shared.open(release.url) }
    }
    @objc private func quit() { NSApplication.shared.terminate(nil) }
}
