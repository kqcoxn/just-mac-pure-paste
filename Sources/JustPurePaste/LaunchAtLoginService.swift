import Observation
import ServiceManagement

@MainActor
@Observable
final class LaunchAtLoginService {
    private(set) var status: SMAppService.Status = .notRegistered
    private(set) var errorMessage: String?
    @ObservationIgnored private let readStatus: () -> SMAppService.Status
    @ObservationIgnored private let register: () throws -> Void
    @ObservationIgnored private let unregister: () throws -> Void
    @ObservationIgnored private let defaults: UserDefaults
    private static let configuredKey = "launchAtLoginConfigured"

    init(
        defaults: UserDefaults = .standard,
        readStatus: @escaping () -> SMAppService.Status = { SMAppService.mainApp.status },
        register: @escaping () throws -> Void = { try SMAppService.mainApp.register() },
        unregister: @escaping () throws -> Void = { try SMAppService.mainApp.unregister() }
    ) {
        self.defaults = defaults
        self.readStatus = readStatus
        self.register = register
        self.unregister = unregister
        refresh()
    }

    // Pending approval is registered, but not yet allowed to run at login.
    var isEnabled: Bool {
        get { status == .enabled || status == .requiresApproval }
        set {
            defaults.set(true, forKey: Self.configuredKey)
            errorMessage = nil
            do {
                if newValue { try register() } else { try unregister() }
            } catch {
                errorMessage = "无法更改自动启动设置：\(error.localizedDescription)"
            }
            refresh()
        }
    }

    func enableByDefaultIfNeeded() {
        guard !defaults.bool(forKey: Self.configuredKey) else { return }
        // Apply once. Later launches must respect changes made in System Settings too.
        defaults.set(true, forKey: Self.configuredKey)
        refresh()
        if status == .notRegistered { isEnabled = true }
    }

    func refresh() { status = readStatus() }

    func openSystemSettings() { SMAppService.openSystemSettingsLoginItems() }
}
