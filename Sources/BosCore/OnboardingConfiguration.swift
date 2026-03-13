import Foundation

public struct OnboardingMetadata: Codable, Sendable, Equatable {
    public let companyName: String?
    public let appName: String
    public let appIdentifier: String
    public let appleTeamId: String
    public let primaryLanguage: String
    public let sku: String
    public let appStoreAppId: String?
    public let matchGitURL: String?

    public init(
        companyName: String?,
        appName: String,
        appIdentifier: String,
        appleTeamId: String,
        primaryLanguage: String,
        sku: String,
        appStoreAppId: String? = nil,
        matchGitURL: String?
    ) {
        self.companyName = OnboardingMetadata.normalized(companyName)
        self.appName = appName
        self.appIdentifier = appIdentifier
        self.appleTeamId = appleTeamId
        self.primaryLanguage = primaryLanguage
        self.sku = sku
        self.appStoreAppId = OnboardingMetadata.normalized(appStoreAppId)
        self.matchGitURL = OnboardingMetadata.normalized(matchGitURL)
    }

    public static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

public enum ReleaseEnvironment {
    public static func effectiveEnvironment(
        profile: Profile,
        environment: [String: String]
    ) -> [String: String] {
        var merged = environment
        if OnboardingMetadata.normalized(merged["MATCH_GIT_URL"]) == nil,
           let matchGitURL = profile.configuredMatchGitURL {
            merged["MATCH_GIT_URL"] = matchGitURL
        }
        return merged
    }
}

public extension Profile {
    var configuredCompanyName: String? { identity.companyName }
    var configuredAppName: String? { identity.appName }
    var configuredAppIdentifier: String? { identity.appIdentifier }
    var configuredAppleTeamId: String? { identity.appleTeamId }
    var configuredPrimaryLanguage: String { release.primaryLanguage }
    var configuredSKU: String? { release.sku }
    var configuredAppStoreAppId: String? { release.appStoreAppId }
    var configuredMatchGitURL: String? { release.matchGitURL }

    func updating(onboarding metadata: OnboardingMetadata) throws -> Profile {
        try Profile(
            schemaVersion: schemaVersion,
            name: name,
            defaults: defaults,
            identity: .init(
                companyName: metadata.companyName ?? identity.companyName,
                appName: metadata.appName,
                appIdentifier: metadata.appIdentifier,
                appleTeamId: metadata.appleTeamId
            ),
            release: .init(
                primaryLanguage: metadata.primaryLanguage,
                sku: metadata.sku,
                appStoreAppId: metadata.appStoreAppId ?? release.appStoreAppId,
                matchGitURL: metadata.matchGitURL ?? release.matchGitURL
            ),
            featurePattern: featurePattern,
            rules: rules
        )
    }

    func updating(appStoreAppId: String) throws -> Profile {
        try Profile(
            schemaVersion: schemaVersion,
            name: name,
            defaults: defaults,
            identity: identity,
            release: .init(
                primaryLanguage: release.primaryLanguage,
                sku: release.sku,
                appStoreAppId: appStoreAppId,
                matchGitURL: release.matchGitURL
            ),
            featurePattern: featurePattern,
            rules: rules
        )
    }
}
