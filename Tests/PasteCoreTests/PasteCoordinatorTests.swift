import Foundation
import Testing
@testable import PasteCore

@MainActor
private final class FakeEnvironment: PasteEnvironment {
    var hasPermission = true
    var targetPID: Int32? = 42
    var clipboardVersion = 1
    var modifiersAreDown = false
    var now: Duration = .zero
    var content = "  中文 👩🏽‍💻\n\tsecond line  "
    var readFailure: PasteResult?
    var canPrepare = true
    var canWrite = true
    var reads = 0
    var written: [String] = []
    var sent: [Int32] = []
    var onWait: (() async throws -> Void)?
    var onRead: (() -> Void)?
    func wait() async throws {
        now += .milliseconds(100)
        try await onWait?()
    }
    func readText() -> Result<String, PasteResultError> {
        reads += 1
        onRead?()
        if let readFailure { return .failure(PasteResultError(readFailure)) }
        return .success(content)
    }
    func prepareEvents() -> Bool { canPrepare }
    func writeText(_ text: String) -> Bool {
        written.append(text)
        clipboardVersion += 1
        return canWrite
    }
    func sendPaste(to pid: Int32) { sent.append(pid) }
}

@Suite @MainActor
struct PasteCoordinatorTests {
    @Test func preservesTextAndSendsOnce() async {
        let environment = FakeEnvironment()
        let coordinator = PasteCoordinator(environment: environment)
        #expect(await coordinator.paste() == .sent)
        #expect(environment.written == [environment.content])
        #expect(environment.sent == [42])
        #expect(!coordinator.isBusy)
    }

    @Test(arguments: [PasteResult.permissionRequired, .noTarget, .noText, .clipboardUnavailable, .eventUnavailable])
    func earlyFailuresDoNotWriteOrSend(_ failure: PasteResult) async {
        let environment = FakeEnvironment()
        switch failure {
        case .permissionRequired: environment.hasPermission = false
        case .noTarget: environment.targetPID = nil
        case .noText: environment.content = ""
        case .clipboardUnavailable: environment.readFailure = .clipboardUnavailable
        case .eventUnavailable: environment.canPrepare = false
        default: break
        }
        let coordinator = PasteCoordinator(environment: environment)
        #expect(await coordinator.paste() == failure)
        #expect(environment.written.isEmpty)
        #expect(environment.sent.isEmpty)
        if failure == .permissionRequired || failure == .noTarget { #expect(environment.reads == 0) }
    }

    @Test func waitsForModifierRelease() async {
        let environment = FakeEnvironment()
        environment.modifiersAreDown = true
        environment.onWait = { environment.modifiersAreDown = false }
        #expect(await PasteCoordinator(environment: environment).paste() == .sent)
        #expect(environment.sent.count == 1)
    }

    @Test func modifierTimeout() async {
        let environment = FakeEnvironment()
        environment.modifiersAreDown = true
        #expect(await PasteCoordinator(environment: environment).paste() == .modifierTimeout)
        #expect(environment.now == .seconds(1))
        #expect(environment.reads == 0)
        #expect(environment.written.isEmpty)
        #expect(environment.sent.isEmpty)
    }

    @Test(arguments: [PasteResult.clipboardChanged, .targetChanged, .permissionRequired])
    func detectsChangesWhileWaiting(_ failure: PasteResult) async {
        let environment = FakeEnvironment()
        environment.modifiersAreDown = true
        environment.onWait = {
            switch failure {
            case .clipboardChanged: environment.clipboardVersion += 1
            case .targetChanged: environment.targetPID = 99
            case .permissionRequired: environment.hasPermission = false
            default: break
            }
        }
        #expect(await PasteCoordinator(environment: environment).paste() == failure)
        #expect(environment.written.isEmpty)
        #expect(environment.sent.isEmpty)
    }

    @Test(arguments: [PasteResult.clipboardChanged, .targetChanged, .permissionRequired, .modifierTimeout])
    func revalidatesAfterReading(_ failure: PasteResult) async {
        let environment = FakeEnvironment()
        environment.onRead = {
            switch failure {
            case .clipboardChanged: environment.clipboardVersion += 1
            case .targetChanged: environment.targetPID = 99
            case .permissionRequired: environment.hasPermission = false
            case .modifierTimeout: environment.modifiersAreDown = true
            default: break
            }
        }
        #expect(await PasteCoordinator(environment: environment).paste() == failure)
        #expect(environment.written.isEmpty)
        #expect(environment.sent.isEmpty)
    }

    @Test func failedWriteDoesNotSend() async {
        let environment = FakeEnvironment()
        environment.canWrite = false
        #expect(await PasteCoordinator(environment: environment).paste() == .writeFailed)
        #expect(environment.sent.isEmpty)
    }

    @Test func concurrentTriggerIsIgnored() async {
        let environment = FakeEnvironment()
        let coordinator = PasteCoordinator(environment: environment)
        environment.modifiersAreDown = true
        environment.onWait = {
            #expect(await coordinator.paste() == .busy)
            environment.modifiersAreDown = false
        }
        #expect(await coordinator.paste() == .sent)
        #expect(environment.written.count == 1)
        #expect(environment.sent.count == 1)
    }

    @Test func cancellationDoesNotWriteAndAllowsNextAttempt() async {
        let environment = FakeEnvironment()
        let coordinator = PasteCoordinator(environment: environment)
        environment.modifiersAreDown = true
        environment.onWait = { throw CancellationError() }
        #expect(await coordinator.paste() == .cancelled)
        #expect(environment.written.isEmpty)
        #expect(environment.sent.isEmpty)
        #expect(!coordinator.isBusy)
        environment.modifiersAreDown = false
        #expect(await coordinator.paste() == .sent)
    }
}
