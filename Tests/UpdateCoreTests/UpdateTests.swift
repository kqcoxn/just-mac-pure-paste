import Foundation
import Testing
@testable import UpdateCore

@Suite
struct ReleaseVersionTests {
    @Test(arguments: [
        ["v0.9.0", "v0.10.0"], ["1.9.9", "2.0.0"], ["1.2.3-beta.2", "1.2.3-beta.10"],
        ["1.2.3-rc.1", "1.2.3"], ["1.2.3-alpha", "1.2.3-beta"], ["1.2.3-1", "1.2.3-alpha"]
    ])
    func numericalAndPrereleaseOrdering(_ pair: [String]) throws {
        let older = try #require(ReleaseVersion(pair[0]))
        let newer = try #require(ReleaseVersion(pair[1]))
        #expect(older < newer)
        #expect(!(newer < older))
    }
    @Test func buildMetadataDoesNotAffectPrecedence() {
        #expect(ReleaseVersion("v1.2.3+build.1") == ReleaseVersion("1.2.3+build.2"))
    }
    @Test(arguments: ["1.2", "v01.2.3", "1.2.3-beta.01", "1.2.3\n", "1.2.3/evil", "999999999999999999999.0.0", "latest", "1.2.3-"])
    func rejectsInvalidVersions(_ tag: String) { #expect(ReleaseVersion(tag) == nil) }
}

@Suite
struct GitHubReleaseClientTests {
    @Test func requestUsesPublicEndpointWithoutCredentials() {
        let request = GitHubReleaseClient.request
        #expect(request.url?.absoluteString == "https://api.github.com/repos/kqcoxn/just-mac-pure-paste/releases/latest")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(request.httpBody == nil)
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/vnd.github+json")
    }
    @Test func decodesStableReleaseAndUsesFixedRepository() throws {
        let body = Data(#"{"tag_name":"v0.2.0","draft":false,"prerelease":false,"html_url":"https://example.com/malicious"}"#.utf8)
        let decoded = try GitHubReleaseClient.decode(body, status: 200)
        let release = try #require(decoded)
        #expect(release.tag == "v0.2.0")
        #expect(release.url.absoluteString == "https://github.com/kqcoxn/just-mac-pure-paste/releases/tag/v0.2.0")
    }
    @Test func ignoresUnpublishedAndPrerelease() throws {
        for body in [#"{"tag_name":"v0.2.0","draft":true,"prerelease":false}"#,
                     #"{"tag_name":"v0.2.0-beta.1","draft":false,"prerelease":true}"#] {
            let release = try GitHubReleaseClient.decode(Data(body.utf8), status: 200)
            #expect(release == nil)
        }
        let missing = try GitHubReleaseClient.decode(Data(), status: 404)
        #expect(missing == nil)
    }
    @Test(arguments: [403, 429, 500, 200])
    func reportsBadResponses(_ status: Int) {
        #expect(throws: UpdateError.self) { try GitHubReleaseClient.decode(Data("invalid".utf8), status: status) }
    }
}

private actor StubClient: ReleaseChecking {
    var calls = 0
    var tag: String? = "v0.2.0"
    var failure: Bool = false
    func set(tag: String?, failure: Bool = false) { self.tag = tag; self.failure = failure }
    func latestRelease() async throws -> PublishedRelease? {
        calls += 1
        if failure { throw UpdateError.rateLimited }
        return tag.flatMap(PublishedRelease.init(tag:))
    }
}

@MainActor
private final class TestClock {
    var date = Date(timeIntervalSince1970: 1_800_000_000)
}

@Suite @MainActor
struct UpdateServiceTests {
    private func storage() -> (String, UserDefaults) {
        let name = "JustPurePaste.UpdateTests.\(UUID().uuidString)"
        return (name, UserDefaults(suiteName: name)!)
    }

    @Test func discoversAndPersistsNewVersion() async {
        let (name, defaults) = storage()
        defer { defaults.removePersistentDomain(forName: name) }
        let service = UpdateService(currentVersion: "0.1.0", defaults: defaults, client: StubClient())
        await service.check()
        #expect(service.availableRelease?.tag == "v0.2.0")
        #expect(service.lastChecked != nil)
        let restarted = UpdateService(currentVersion: "0.1.0", defaults: defaults, client: StubClient())
        #expect(restarted.availableRelease?.tag == "v0.2.0")
        let upgraded = UpdateService(currentVersion: "0.2.0", defaults: defaults, client: StubClient())
        #expect(upgraded.availableRelease == nil)
    }

    @Test(arguments: ["0.2.0", "0.3.0"])
    func doesNotOfferSameOrOlderVersion(_ current: String) async {
        let (name, defaults) = storage()
        defer { defaults.removePersistentDomain(forName: name) }
        let service = UpdateService(currentVersion: current, defaults: defaults, client: StubClient())
        await service.check()
        #expect(service.availableRelease == nil)
        #expect(service.status == "当前已是最新版本。")
    }

    @Test func prereleaseUpgradesToSameNumberStable() async {
        let (name, defaults) = storage()
        defer { defaults.removePersistentDomain(forName: name) }
        let service = UpdateService(currentVersion: "v0.2.0-beta.1", defaults: defaults, client: StubClient())
        await service.check()
        #expect(service.availableRelease?.tag == "v0.2.0")
    }

    @Test func dailyChecksAndManualThrottlePersistAcrossRestarts() async {
        let (name, defaults) = storage()
        defer { defaults.removePersistentDomain(forName: name) }
        let clock = TestClock()
        let client = StubClient()
        let service = UpdateService(currentVersion: "0.1.0", defaults: defaults, client: client, now: { clock.date })
        await service.check(manual: false)
        await service.check()
        #expect(await client.calls == 1)
        clock.date += 61
        await service.check(manual: false)
        #expect(await client.calls == 1)
        await service.check()
        #expect(await client.calls == 2)
        let restarted = UpdateService(currentVersion: "0.1.0", defaults: defaults, client: client, now: { clock.date })
        await restarted.check(manual: false)
        #expect(await client.calls == 2)
        clock.date += 24 * 60 * 60
        await restarted.check(manual: false)
        #expect(await client.calls == 3)
    }

    @Test func automaticSettingPersistsAndManualStillWorks() async {
        let (name, defaults) = storage()
        defer { defaults.removePersistentDomain(forName: name) }
        let client = StubClient()
        let service = UpdateService(currentVersion: "0.1.0", defaults: defaults, client: client)
        #expect(service.automaticallyChecks)
        service.automaticallyChecks = false
        await service.check(manual: false)
        #expect(await client.calls == 0)
        #expect(!UpdateService(currentVersion: "0.1.0", defaults: defaults, client: client).automaticallyChecks)
        await service.check()
        #expect(await client.calls == 1)
    }

    @Test func failuresPreserveKnownUpdateAndDoNotClaimSuccess() async {
        let (name, defaults) = storage()
        defer { defaults.removePersistentDomain(forName: name) }
        let clock = TestClock()
        let client = StubClient()
        let service = UpdateService(currentVersion: "0.1.0", defaults: defaults, client: client, now: { clock.date })
        await service.check()
        let checked = service.lastChecked
        clock.date += 61
        await client.set(tag: nil, failure: true)
        await service.check()
        #expect(service.availableRelease?.tag == "v0.2.0")
        #expect(service.lastChecked == checked)
        #expect(service.status == UpdateError.rateLimited.message)
        #expect(!service.isChecking)
    }

    @Test func noReleaseAndInvalidCurrentVersion() async {
        let (name, defaults) = storage()
        defer { defaults.removePersistentDomain(forName: name) }
        let client = StubClient()
        await client.set(tag: nil)
        let invalid = UpdateService(currentVersion: "unknown", defaults: defaults, client: client)
        await invalid.check()
        #expect(await client.calls == 0)
        let service = UpdateService(currentVersion: "0.1.0", defaults: defaults, client: client)
        await service.check()
        #expect(service.availableRelease == nil)
        #expect(service.status == "暂未找到可用的公开正式版。")
    }
}

private actor GatedClient: ReleaseChecking {
    private var continuation: CheckedContinuation<PublishedRelease?, Never>?
    private(set) var calls = 0
    func latestRelease() async throws -> PublishedRelease? {
        calls += 1
        return await withCheckedContinuation { continuation = $0 }
    }
    func finish() { continuation?.resume(returning: PublishedRelease(tag: "v0.2.0")); continuation = nil }
}

@Suite @MainActor
struct UpdateConcurrencyTests {
    @Test(arguments: [false, true])
    func coalescesRequestsAndDiscardsCancelledResults(_ cancel: Bool) async {
        let name = "JustPurePaste.UpdateTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let client = GatedClient()
        let service = UpdateService(currentVersion: "0.1.0", defaults: defaults, client: client)
        let first = Task { await service.check() }
        while await client.calls == 0 { await Task.yield() }
        #expect(service.isChecking)
        await service.check()
        #expect(await client.calls == 1)
        if cancel { first.cancel() }
        await client.finish()
        await first.value
        #expect(!service.isChecking)
        #expect((service.availableRelease != nil) == !cancel)
        #expect((service.lastChecked != nil) == !cancel)
    }
}
