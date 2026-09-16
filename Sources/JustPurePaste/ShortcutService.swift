import KeyboardShortcuts

enum ShortcutState: Equatable {
    case ready, paused, unavailable

    var message: String {
        switch self {
        case .ready: "全局快捷键已注册，可在其他应用中使用"
        case .paused: "快捷键未设置，已暂停"
        case .unavailable: "快捷键注册失败，可能已被其他程序占用。请更换组合或退出占用程序；会自动重试。"
        }
    }
}

@MainActor
final class ShortcutService {
    private let isConfigured: () -> Bool
    private let isRegistered: () -> Bool
    private let register: () -> Void
    private let unregister: () -> Void

    convenience init(action: @escaping @MainActor () -> Void) {
        self.init(
            isConfigured: { KeyboardShortcuts.getShortcut(for: .purePaste) != nil },
            isRegistered: { KeyboardShortcuts.isEnabled(for: .purePaste) },
            register: { KeyboardShortcuts.enable(.purePaste) },
            unregister: { KeyboardShortcuts.disable(.purePaste) }
        )
        KeyboardShortcuts.onKeyUp(for: .purePaste, action: action)
    }

    init(isConfigured: @escaping () -> Bool, isRegistered: @escaping () -> Bool,
         register: @escaping () -> Void, unregister: @escaping () -> Void) {
        self.isConfigured = isConfigured
        self.isRegistered = isRegistered
        self.register = register
        self.unregister = unregister
    }

    func refresh() -> ShortcutState {
        guard isConfigured() else { return .paused }
        // Do not cycle a healthy registration: releasing it creates an opportunity
        // for another app to take it. enable() retries only missing registrations
        // and respects the library's temporary pause during shortcut recording.
        if !isRegistered() { register() }
        return isRegistered() ? .ready : .unavailable
    }

    func reset() { KeyboardShortcuts.reset(.purePaste) }
    func stop() { unregister() }
}
