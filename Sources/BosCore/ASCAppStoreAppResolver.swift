import Foundation

public struct ASCAppStoreAppResolution: Sendable {
    public enum Source: String, Sendable, Equatable {
        case profile
        case lookup
    }

    public let appStoreAppId: String
    public let source: Source
    public let updatedProfile: Profile

    public init(appStoreAppId: String, source: Source, updatedProfile: Profile) {
        self.appStoreAppId = appStoreAppId
        self.source = source
        self.updatedProfile = updatedProfile
    }
}

public enum ASCAppStoreAppResolverError: Error, Equatable {
    case missingBundleIdentifier
    case lookupFailed(summary: String)
    case appNotFound(bundleIdentifier: String)
    case ambiguous(bundleIdentifier: String, appStoreAppIds: [String])
    case invalidResponse(summary: String)
}

public struct ASCAppStoreAppResolver: Sendable {
    private let backend: ASCBackend

    public init(backend: ASCBackend = ASCBackend()) {
        self.backend = backend
    }

    public func resolve(
        profile: Profile,
        projectRoot: URL,
        environment: [String: String],
        bundleIdentifierOverride: String? = nil
    ) throws -> ASCAppStoreAppResolution {
        if let configured = profile.configuredAppStoreAppId {
            return ASCAppStoreAppResolution(
                appStoreAppId: configured,
                source: .profile,
                updatedProfile: profile
            )
        }

        guard let bundleIdentifier = bundleIdentifierOverride ?? profile.configuredAppIdentifier else {
            throw ASCAppStoreAppResolverError.missingBundleIdentifier
        }

        let result = try backend.run(
            arguments: [
                "apps", "list",
                "--bundle-id", bundleIdentifier,
                "--output", "json"
            ],
            projectRoot: projectRoot,
            environment: environment
        )
        let sanitizedEnvironment = environment.merging(
            ["ASC_PRIVATE_KEY_B64": environment["ASC_KEY_P8_BASE64"] ?? ""],
            uniquingKeysWith: { _, new in new }
        )
        let sanitizedStdout = ASCBackend.sanitizeSecrets(result.stdout, environment: sanitizedEnvironment)
        let sanitizedStderr = ASCBackend.sanitizeSecrets(result.stderr, environment: sanitizedEnvironment)

        guard result.exitCode == 0 else {
            let summary = sanitizedStderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? sanitizedStdout.trimmingCharacters(in: .whitespacesAndNewlines)
                : sanitizedStderr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw ASCAppStoreAppResolverError.lookupFailed(summary: summary.isEmpty ? "asc apps list failed" : summary)
        }

        let response: AppsListResponse
        do {
            response = try JSONDecoder().decode(AppsListResponse.self, from: Data(result.stdout.utf8))
        } catch {
            throw ASCAppStoreAppResolverError.invalidResponse(summary: sanitizedStdout)
        }

        let matchingIDs = response.data
            .filter { app in
                guard let appBundleID = app.attributes?.bundleID?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                    return false
                }
                return appBundleID == bundleIdentifier
            }
            .map(\.id)
            .filter { !$0.isEmpty }

        if matchingIDs.count > 1 {
            throw ASCAppStoreAppResolverError.ambiguous(
                bundleIdentifier: bundleIdentifier,
                appStoreAppIds: matchingIDs.sorted()
            )
        }
        guard let appStoreAppId = matchingIDs.first else {
            throw ASCAppStoreAppResolverError.appNotFound(bundleIdentifier: bundleIdentifier)
        }

        return ASCAppStoreAppResolution(
            appStoreAppId: appStoreAppId,
            source: .lookup,
            updatedProfile: try profile.updating(appStoreAppId: appStoreAppId)
        )
    }
}

extension ASCAppStoreAppResolver: AppStoreAppIDResolving {}

private extension ASCAppStoreAppResolver {
    struct AppsListResponse: Decodable {
        let data: [App]
    }

    struct App: Decodable {
        let id: String
        let attributes: Attributes?
    }

    struct Attributes: Decodable {
        let bundleID: String?

        enum CodingKeys: String, CodingKey {
            case bundleID = "bundleId"
        }
    }
}
