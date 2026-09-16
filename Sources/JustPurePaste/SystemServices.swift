import AppKit
import ApplicationServices
import Observation
import PasteCore

@MainActor
@Observable
final class PermissionService {
    private(set) var granted = AXIsProcessTrusted()
    func refresh() { granted = AXIsProcessTrusted() }
    func request() {
        // The public option key is a C global imported as mutable; use its stable string value.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        granted = AXIsProcessTrustedWithOptions(options)
    }
    func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }
}

@MainActor
final class SystemPasteEnvironment: PasteEnvironment {
    private let clipboard = ClipboardService()
    private let clock = ContinuousClock()
    private let start = ContinuousClock.now
    private var events: (CGEvent, CGEvent)?
    var hasPermission: Bool { AXIsProcessTrusted() }
    var targetPID: Int32? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              !app.isTerminated else { return nil }
        return app.processIdentifier
    }
    var clipboardVersion: Int { clipboard.version }
    var now: Duration { start.duration(to: clock.now) }
    var modifiersAreDown: Bool {
        let flags = CGEventSource.flagsState(.combinedSessionState)
        return !flags.intersection([.maskShift, .maskControl, .maskAlternate, .maskCommand, .maskSecondaryFn]).isEmpty
    }
    func wait() async throws { try await Task.sleep(for: .milliseconds(10)) }
    func readText() -> Result<String, PasteResultError> { clipboard.readText() }
    func writeText(_ text: String) -> Bool { clipboard.writeText(text) }
    func prepareEvents() -> Bool {
        events = nil
        guard let source = CGEventSource(stateID: .privateState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else { return false }
        down.flags = .maskCommand
        up.flags = .maskCommand
        events = (down, up)
        return true
    }
    func sendPaste(to pid: Int32) {
        guard let (down, up) = events else { return }
        // Explicit PID avoids redirecting a late event to an unrelated application.
        down.postToPid(pid)
        up.postToPid(pid)
        events = nil
    }
}
