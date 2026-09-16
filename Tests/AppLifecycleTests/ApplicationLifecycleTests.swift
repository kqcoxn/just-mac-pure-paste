import AppKit
import Testing
@testable import JustPurePaste

// Opt in on a Mac with a logged-in desktop session; this test creates a real window.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["JPP_RUN_UI_TESTS"] == "1"))
@MainActor
struct ApplicationLifecycleTests {
    @Test func hiddenStatusItemDoesNotBlockSettingsReopen() throws {
        let application = NSApplication.shared
        let model = AppModel(startUpdates: false)
        let delegate = AppDelegate(model: model)
        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        let window = try #require(application.windows.first { $0.title == "Just Pure Paste 设置" })
        let originalVisibility = delegate.menuBar.isVisible
        defer {
            delegate.menuBar.setVisible(originalVisibility)
            window.close()
            model.stop()
        }
        #expect(window.isVisible)
        delegate.menuBar.setVisible(false)
        #expect(!delegate.menuBar.isVisible)
        window.close()
        #expect(!delegate.applicationShouldTerminateAfterLastWindowClosed(application))
        #expect(!window.isVisible)

        _ = delegate.applicationShouldHandleReopen(application, hasVisibleWindows: false)
        #expect(window.isVisible)
        #expect(!delegate.menuBar.isVisible)
        #expect(application.activationPolicy() == .regular)
        #expect(application.windows.filter { $0.title == window.title }.count == 1)

        window.miniaturize(nil)
        _ = delegate.applicationShouldHandleReopen(application, hasVisibleWindows: false)
        #expect(!window.isMiniaturized)
        #expect(window.isVisible)
        #expect(!delegate.menuBar.isVisible)
        delegate.menuBar.setVisible(true)
        #expect(delegate.menuBar.isVisible)
    }
}
