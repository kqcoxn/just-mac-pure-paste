import Foundation

package enum PasteResult: Equatable, Sendable {
    case sent, busy, permissionRequired, noTarget, noText, clipboardUnavailable
    case targetChanged, clipboardChanged, modifierTimeout, eventUnavailable, writeFailed, cancelled

    package var message: String {
        switch self {
        case .sent: "已发送粘贴"
        case .busy: "正在处理上一次粘贴"
        case .permissionRequired: "请在设置中授予辅助功能权限"
        case .noTarget: "请先切换到需要粘贴的应用"
        case .noText: "剪贴板中没有可粘贴的文本"
        case .clipboardUnavailable: "无法读取剪贴板，请检查系统剪贴板访问权限"
        case .targetChanged: "前台应用已切换，本次粘贴已取消"
        case .clipboardChanged: "剪贴板已更新，本次粘贴已取消"
        case .modifierTimeout: "修饰键未释放，本次粘贴已取消"
        case .eventUnavailable: "无法创建粘贴按键，剪贴板未修改"
        case .writeFailed: "无法写入纯文本，本次粘贴已取消"
        case .cancelled: "本次粘贴已取消"
        }
    }
}

@MainActor
package protocol PasteEnvironment: AnyObject {
    var hasPermission: Bool { get }
    var targetPID: Int32? { get }
    var clipboardVersion: Int { get }
    var modifiersAreDown: Bool { get }
    var now: Duration { get }
    func wait() async throws
    func readText() -> Result<String, PasteResultError>
    func prepareEvents() -> Bool
    func writeText(_ text: String) -> Bool
    func sendPaste(to pid: Int32)
}

package struct PasteResultError: Error {
    package let result: PasteResult
    package init(_ result: PasteResult) { self.result = result }
}

/// UI and AppKit state belongs to the main actor. Waiting suspends without blocking it.
@MainActor
package final class PasteCoordinator {
    private let environment: any PasteEnvironment
    package private(set) var isBusy = false

    package init(environment: any PasteEnvironment) { self.environment = environment }

    package func paste() async -> PasteResult {
        guard !isBusy else { return .busy }
        isBusy = true
        defer { isBusy = false }
        guard environment.hasPermission else { return .permissionRequired }
        guard let target = environment.targetPID else { return .noTarget }
        let version = environment.clipboardVersion
        let deadline = environment.now + .seconds(1)

        func validate() -> PasteResult? {
            if Task.isCancelled { return .cancelled }
            if !environment.hasPermission { return .permissionRequired }
            if environment.targetPID != target { return .targetChanged }
            if environment.clipboardVersion != version { return .clipboardChanged }
            return nil
        }

        while environment.modifiersAreDown {
            if let failure = validate() { return failure }
            guard environment.now < deadline else { return .modifierTimeout }
            do { try await environment.wait() } catch { return .cancelled }
        }
        if let failure = validate() { return failure }
        let text: String
        switch environment.readText() {
        case .success(let value): text = value
        case .failure(let error): return error.result
        }
        guard !text.isEmpty else { return .noText }
        guard environment.prepareEvents() else { return .eventUnavailable }
        // Reading may show a system permission prompt; revalidate after it returns.
        if let failure = validate() { return failure }
        guard !environment.modifiersAreDown else { return .modifierTimeout }
        // No suspension between final checks, pasteboard mutation, and event submission.
        guard environment.writeText(text) else { return .writeFailed }
        guard environment.hasPermission else { return .permissionRequired }
        guard environment.targetPID == target else { return .targetChanged }
        environment.sendPaste(to: target)
        return .sent
    }
}
