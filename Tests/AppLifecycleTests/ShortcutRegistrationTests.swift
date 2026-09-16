import AppKit
import Carbon.HIToolbox
import KeyboardShortcuts
import Testing
@testable import JustPurePaste

// Requires a logged-in desktop. Reserves an uncommon shortcut briefly; sends no keys.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["JPP_RUN_HOTKEY_TESTS"] == "1"))
@MainActor
struct ShortcutRegistrationTests {
    @Test func carbonConflictIsReportedAndRecovers() throws {
        let name = KeyboardShortcuts.Name("registration-test-\(UUID().uuidString)")
        let shortcut = KeyboardShortcuts.Shortcut(.f19, modifiers: [.command, .control, .option, .shift])
        var competingKey: EventHotKeyRef?
        let result = RegisterEventHotKey(UInt32(shortcut.carbonKeyCode), UInt32(shortcut.carbonModifiers),
            EventHotKeyID(signature: 0x4A505054, id: 1), GetEventDispatcherTarget(), 0, &competingKey)
        #expect(result == noErr)
        let key = try #require(competingKey)
        var released = false
        defer {
            if !released { UnregisterEventHotKey(key) }
            KeyboardShortcuts.removeHandler(for: name)
            KeyboardShortcuts.setShortcut(nil, for: name)
        }
        KeyboardShortcuts.setShortcut(shortcut, for: name)
        KeyboardShortcuts.onKeyUp(for: name) {}
        let service = ShortcutService(
            isConfigured: { KeyboardShortcuts.getShortcut(for: name) != nil },
            isRegistered: { KeyboardShortcuts.isEnabled(for: name) },
            register: { KeyboardShortcuts.enable(name) },
            unregister: { KeyboardShortcuts.disable(name) })
        #expect(service.refresh() == .unavailable)
        #expect(UnregisterEventHotKey(key) == noErr)
        released = true
        #expect(service.refresh() == .ready)
        service.stop()
        #expect(!KeyboardShortcuts.isEnabled(for: name))
    }
}
