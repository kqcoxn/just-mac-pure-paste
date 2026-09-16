import Foundation
import Observation

/// Observable UI state is main-actor owned; the injected client performs asynchronous I/O.
@MainActor @Observable
package final class UpdateService {
    package let currentVersion: String
    package private(set) var isChecking = false
    package private(set) var availableRelease: PublishedRelease?
    package private(set) var status = "尚未检查更新"
    package private(set) var lastChecked: Date?
    package var automaticallyChecks: Bool {
        didSet { defaults.set(automaticallyChecks, forKey: "updates.automatic") }
    }
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let client: any ReleaseChecking
    @ObservationIgnored private let now: @MainActor () -> Date
    @ObservationIgnored private var lastAttempt: Date?
    @ObservationIgnored private var scheduleTask: Task<Void, Never>?

    package init(currentVersion: String, defaults: UserDefaults = .standard,
                 client: any ReleaseChecking = GitHubReleaseClient(),
                 now: @escaping @MainActor () -> Date = { Date() }) {
        self.currentVersion = currentVersion
        self.defaults = defaults
        self.client = client
        self.now = now
        automaticallyChecks = defaults.object(forKey: "updates.automatic") as? Bool ?? true
        lastAttempt = defaults.object(forKey: "updates.lastAttempt") as? Date
        lastChecked = defaults.object(forKey: "updates.lastChecked") as? Date
        if let tag = defaults.string(forKey: "updates.cachedTag"),
           let release = PublishedRelease(tag: tag), let current = ReleaseVersion(currentVersion), release.version > current {
            availableRelease = release
            status = "发现新版本 \(tag)"
        }
    }

    package func start() {
        guard scheduleTask == nil else { return }
        scheduleTask = Task { [weak self] in
            // This task does not hold the service alive across the scheduler sleep.
            while !Task.isCancelled && self != nil {
                await self?.check(manual: false)
                do { try await Task.sleep(for: .seconds(60)) } catch { return }
            }
        }
    }
    package func stop() { scheduleTask?.cancel(); scheduleTask = nil }

    package func check(manual: Bool = true) async {
        guard !isChecking, !Task.isCancelled else { return }
        guard manual || automaticallyChecks else { return }
        let date = now()
        if let lastAttempt {
            let elapsed = date.timeIntervalSince(lastAttempt)
            // A clock moving backwards should not disable checks forever.
            if elapsed >= 0 && elapsed < (manual ? 60 : 24 * 60 * 60) {
                if manual { status = "刚刚已检查，请一分钟后再试。" }
                return
            }
        }
        guard let current = ReleaseVersion(currentVersion) else {
            status = "无法识别当前版本，请从正式应用包运行。"
            return
        }
        isChecking = true
        status = "正在检查更新…"
        lastAttempt = date
        defaults.set(date, forKey: "updates.lastAttempt")
        defer { isChecking = false }
        do {
            let release = try await client.latestRelease()
            try Task.checkCancellation()
            lastChecked = now()
            defaults.set(lastChecked, forKey: "updates.lastChecked")
            availableRelease = release.flatMap { $0.version > current ? $0 : nil }
            defaults.set(availableRelease?.tag, forKey: "updates.cachedTag")
            if let availableRelease {
                status = "发现新版本 \(availableRelease.tag)"
            } else {
                status = release == nil ? "暂未找到可用的公开正式版。" : "当前已是最新版本。"
            }
        } catch is CancellationError {
            status = "检查已取消"
        } catch let error as UpdateError {
            status = error.message
        } catch {
            status = "检查失败，请检查网络后重试。"
        }
    }
}
