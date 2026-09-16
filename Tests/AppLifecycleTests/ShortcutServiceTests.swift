import Testing
@testable import JustPurePaste

@Suite @MainActor
struct ShortcutServiceTests {
    @Test func registrationFailureRecoversWhenConflictEnds() {
        var occupied = true
        var registered = false
        var attempts = 0
        let service = ShortcutService(isConfigured: { true }, isRegistered: { registered },
            register: { attempts += 1; registered = !occupied }, unregister: { registered = false })
        #expect(service.refresh() == .unavailable)
        #expect(attempts == 1)
        occupied = false
        #expect(service.refresh() == .ready)
        #expect(attempts == 2)
        #expect(service.refresh() == .ready)
        #expect(attempts == 2) // Never release/reacquire a healthy registration.
        registered = false // Registration lost after recording/menu tracking.
        #expect(service.refresh() == .ready)
        #expect(attempts == 3)
        service.stop()
        #expect(!registered)
    }

    @Test func clearedShortcutStaysPaused() {
        let service = ShortcutService(isConfigured: { false }, isRegistered: { false },
            register: { Issue.record("Must not register a cleared shortcut") }, unregister: {})
        #expect(service.refresh() == .paused)
    }
}
