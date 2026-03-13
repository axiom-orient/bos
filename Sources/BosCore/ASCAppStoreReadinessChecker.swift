import Foundation

public struct AppStoreReadinessCheckResult: Sendable, Equatable {
    public let summary: String

    public init(summary: String) {
        self.summary = summary
    }
}

public protocol AppStoreReadinessChecking: Sendable {
    func check(projectRoot: URL, profile: Profile, environment: [String: String]) throws -> AppStoreReadinessCheckResult
}

public struct NoopAppStoreReadinessChecker: AppStoreReadinessChecking {
    public init() {}

    public func check(projectRoot: URL, profile: Profile, environment: [String : String]) throws -> AppStoreReadinessCheckResult {
        AppStoreReadinessCheckResult(summary: "app store readiness deferred")
    }
}

public struct ASCAppStoreReadinessChecker: AppStoreReadinessChecking {
    private let backend: ASCBackend
    private let resolver: any AppStoreAppIDResolving

    public init(
        backend: ASCBackend = ASCBackend(),
        resolver: any AppStoreAppIDResolving = ASCAppStoreAppResolver()
    ) {
        self.backend = backend
        self.resolver = resolver
    }

    public func check(projectRoot: URL, profile: Profile, environment: [String : String]) throws -> AppStoreReadinessCheckResult {
        let resolution = try resolver.resolve(
            profile: profile,
            projectRoot: projectRoot,
            environment: environment,
            bundleIdentifierOverride: profile.configuredAppIdentifier
        )
        let result = try backend.run(
            arguments: ["status", "--output", "json"],
            projectRoot: projectRoot,
            environment: environment,
            appStoreAppId: resolution.appStoreAppId
        )
        let curatedEnvironment = try backend.curatedEnvironment(
            projectRoot: projectRoot,
            environment: environment,
            appStoreAppId: resolution.appStoreAppId
        )
        let sanitizedStdout = ASCBackend.sanitizeSecrets(result.stdout, environment: curatedEnvironment)
        let sanitizedStderr = ASCBackend.sanitizeSecrets(result.stderr, environment: curatedEnvironment)

        guard result.exitCode == 0 else {
            let summary = sanitizedStderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? sanitizedStdout.trimmingCharacters(in: .whitespacesAndNewlines)
                : sanitizedStderr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(
                domain: "BosCore.ASCAppStoreReadinessChecker",
                code: Int(result.exitCode),
                userInfo: [NSLocalizedDescriptionKey: summary.isEmpty ? "asc status failed" : summary]
            )
        }

        guard let data = sanitizedStdout.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: data)) != nil else {
            throw NSError(
                domain: "BosCore.ASCAppStoreReadinessChecker",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "asc status returned non-JSON output"]
            )
        }

        return AppStoreReadinessCheckResult(
            summary: "app store readiness status collected (appStoreAppId=\(resolution.appStoreAppId))"
        )
    }
}
