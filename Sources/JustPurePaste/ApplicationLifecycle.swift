import AppKit
import SwiftUI

@main
enum JustPurePasteApp {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model: AppModel
    private var settingsWindow: NSWindow?
    private(set) lazy var menuBar = MenuBarController(model: model) { [weak self] in
        self?.showSettings()
    }

    init(model: AppModel = AppModel()) {
        self.model = model
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = menuBar
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        let settings = NSMenuItem(title: "设置…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        appMenu.addItem(settings)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出 Just Pure Paste", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)
        NSApplication.shared.mainMenu = mainMenu
        showSettings()
    }

    @objc func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 660),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered, defer: false
            )
            window.title = "Just Pure Paste 设置"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(model: model, menuBar: menuBar))
            window.center()
            settingsWindow = window
        }
        NSApplication.shared.setActivationPolicy(.regular)
        if settingsWindow?.isMiniaturized == true { settingsWindow?.deminiaturize(nil) }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) { model.stop() }
}
