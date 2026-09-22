import AppKit
import ServiceManagement
import Testing
@testable import JustPurePaste

@MainActor
struct LaunchAtLoginTests {
    @Test func registrationAndExternalChangesUseSystemStatus() {
        var status = SMAppService.Status.notRegistered
        let service = LaunchAtLoginService(
            defaults: UserDefaults(suiteName: UUID().uuidString)!,
            readStatus: { status },
            register: { status = .enabled },
            unregister: { status = .notRegistered }
        )
        #expect(!service.isEnabled)
        service.isEnabled = true
        #expect(service.isEnabled)
        service.isEnabled = false
        #expect(!service.isEnabled)
        status = .requiresApproval
        service.refresh()
        #expect(service.isEnabled)
        #expect(service.status == .requiresApproval)
        service.isEnabled = false
        #expect(status == .notRegistered)
    }

    @Test(arguments: [false, true])
    func failedChangesPreserveActualStatus(initiallyEnabled: Bool) {
        struct Failure: Error {}
        let status: SMAppService.Status = initiallyEnabled ? .enabled : .notRegistered
        let service = LaunchAtLoginService(
            defaults: UserDefaults(suiteName: UUID().uuidString)!,
            readStatus: { status },
            register: { throw Failure() },
            unregister: { throw Failure() }
        )
        service.isEnabled = !initiallyEnabled
        #expect(service.isEnabled == initiallyEnabled)
        #expect(service.errorMessage != nil)
    }

    @Test(arguments: [false, true])
    func defaultRegistrationRunsOnceAndRespectsOptOut(inSystemSettings: Bool) {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        var status = SMAppService.Status.notRegistered
        var registrations = 0
        func makeService() -> LaunchAtLoginService {
            LaunchAtLoginService(
                defaults: defaults,
                readStatus: { status },
                register: { registrations += 1; status = .enabled },
                unregister: { status = .notRegistered }
            )
        }
        let service = makeService()
        service.enableByDefaultIfNeeded()
        #expect(service.isEnabled)
        #expect(registrations == 1)
        if inSystemSettings {
            status = .notRegistered
        } else {
            service.isEnabled = false
        }
        let relaunched = makeService()
        relaunched.enableByDefaultIfNeeded()
        #expect(!relaunched.isEnabled)
        #expect(registrations == 1)
    }

    @Test func onlyLoginLaunchSkipsSettings() {
        #expect(!AppDelegate.isLoginItemLaunch(nil))
        let event = NSAppleEventDescriptor(
            eventClass: AEEventClass(kCoreEventClass), eventID: AEEventID(kAEOpenApplication),
            targetDescriptor: nil, returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID)
        )
        #expect(!AppDelegate.isLoginItemLaunch(event))
        event.setParam(NSAppleEventDescriptor(enumCode: OSType(keyAELaunchedAsLogInItem)),
                       forKeyword: AEKeyword(keyAEPropData))
        #expect(AppDelegate.isLoginItemLaunch(event))
    }
}
