import Testing
@testable import JustPurePaste

@Suite @MainActor
struct SystemPasteEnvironmentTests {
    // Exercise the production suspension path, including in optimized builds.
    // FakeEnvironment.wait() never suspends in most coordinator tests.
    @Test func repeatedModifierPolling() async throws {
        let environment = SystemPasteEnvironment()
        for _ in 0..<20 {
            try await environment.wait()
        }
    }

    @Test func cancelledPollingThrows() async {
        let task = Task { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            try await SystemPasteEnvironment().wait()
        }
        do {
            try await task.value
            Issue.record("Cancelled polling must throw")
        } catch is CancellationError {
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
