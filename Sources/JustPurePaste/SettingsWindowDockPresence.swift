import AppKit
import SwiftUI

/// Observe the settings window itself: SwiftUI appearance does not track closing
/// or minimizing a cached Settings scene, and losing focus must not hide its icon.
struct SettingsWindowDockPresence: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowObserverView { WindowObserverView() }
    func updateNSView(_ nsView: WindowObserverView, context: Context) {}

    final class WindowObserverView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            let center = NotificationCenter.default
            center.removeObserver(self)
            guard let window else { return }

            for name in [NSWindow.didBecomeKeyNotification, NSWindow.didDeminiaturizeNotification] {
                center.addObserver(self, selector: #selector(showDockIcon), name: name, object: window)
            }
            for name in [NSWindow.willCloseNotification, NSWindow.didMiniaturizeNotification] {
                center.addObserver(self, selector: #selector(hideDockIcon), name: name, object: window)
            }
            if window.isVisible && !window.isMiniaturized { showDockIcon() }
        }

        @objc private func showDockIcon() {
            guard let window, !window.isMiniaturized else { return }
            if NSApplication.shared.activationPolicy() != .regular {
                NSApplication.shared.setActivationPolicy(.regular)
            }
        }

        @objc private func hideDockIcon() {
            NSApplication.shared.setActivationPolicy(.accessory)
        }

        deinit { NotificationCenter.default.removeObserver(self) }
    }
}
