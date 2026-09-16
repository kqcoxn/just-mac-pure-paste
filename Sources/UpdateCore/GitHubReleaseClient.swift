import Foundation

package protocol ReleaseChecking: Sendable {
    func latestRelease() async throws -> PublishedRelease?
}

package enum UpdateError: Error, Sendable {
    case rateLimited, server, invalidResponse
    package var message: String {
        switch self {
        case .rateLimited: "GitHub 请求受限，请稍后重试。"
        case .server: "GitHub 暂时不可用，请稍后重试。"
        case .invalidResponse: "无法识别 GitHub 返回的版本信息。"
        }
    }
}

package struct GitHubReleaseClient: ReleaseChecking {
    private let session: URLSession
    package init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 20
        config.httpShouldSetCookies = false
        config.urlCredentialStorage = nil
        config.urlCache = nil
        self.session = URLSession(configuration: config)
    }

    package static var request: URLRequest {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/kqcoxn/just-mac-pure-paste/releases/latest")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("JustPurePaste-UpdateChecker", forHTTPHeaderField: "User-Agent")
        return request
    }

    package func latestRelease() async throws -> PublishedRelease? {
        let (data, response) = try await session.data(for: Self.request)
        guard let response = response as? HTTPURLResponse else { throw UpdateError.invalidResponse }
        return try Self.decode(data, status: response.statusCode)
    }

    package static func decode(_ data: Data, status: Int) throws -> PublishedRelease? {
        if status == 404 { return nil }
        if status == 403 || status == 429 { throw UpdateError.rateLimited }
        guard status == 200 else { throw UpdateError.server }
        struct Payload: Decodable {
            let tag_name: String
            let draft: Bool
            let prerelease: Bool
        }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else { throw UpdateError.invalidResponse }
        guard !payload.draft, !payload.prerelease else { return nil }
        guard let release = PublishedRelease(tag: payload.tag_name) else { throw UpdateError.invalidResponse }
        return release
    }
}
