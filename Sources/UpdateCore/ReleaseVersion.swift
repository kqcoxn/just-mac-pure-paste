import Foundation

package struct ReleaseVersion: Comparable, Sendable {
    private let numbers: [Int]
    private let prerelease: [String]

    package init?(_ tag: String) {
        let text = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        let pattern = #"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?\z"#
        guard text.range(of: pattern, options: .regularExpression) != nil else { return nil }
        let components = text.split(separator: "+", maxSplits: 1)[0].split(separator: "-", maxSplits: 1)
        let numbers = components[0].split(separator: ".").compactMap { Int($0) }
        guard numbers.count == 3 else { return nil }
        let prerelease = components.count == 2 ? components[1].split(separator: ".").map(String.init) : []
        guard !prerelease.contains(where: { $0.allSatisfy(\.isNumber) && $0.count > 1 && $0.hasPrefix("0") }) else { return nil }
        self.numbers = numbers
        self.prerelease = prerelease
    }

    package var isPrerelease: Bool { !prerelease.isEmpty }

    package static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.numbers != rhs.numbers { return lhs.numbers.lexicographicallyPrecedes(rhs.numbers) }
        if lhs.prerelease.isEmpty { return false }
        if rhs.prerelease.isEmpty { return true }
        for (left, right) in zip(lhs.prerelease, rhs.prerelease) where left != right {
            let leftNumeric = left.allSatisfy(\.isNumber)
            let rightNumeric = right.allSatisfy(\.isNumber)
            if leftNumeric && rightNumeric {
                return left.count == right.count ? left < right : left.count < right.count
            }
            if leftNumeric != rightNumeric { return leftNumeric }
            return left < right
        }
        return lhs.prerelease.count < rhs.prerelease.count
    }
}

package struct PublishedRelease: Equatable, Sendable {
    package let tag: String
    package let version: ReleaseVersion
    package var url: URL {
        // Construct from a validated tag and fixed repository; never open arbitrary API-provided URLs.
        URL(string: "https://github.com/kqcoxn/just-mac-pure-paste/releases/tag/\(tag)")!
    }
    package init?(tag: String) {
        guard let version = ReleaseVersion(tag), !version.isPrerelease else { return nil }
        self.tag = tag
        self.version = version
    }
}
