import Foundation

public struct Profile: Codable, Sendable {
    public let schemaVersion: Int
    public let name: String
    public let defaults: Defaults
    public let identity: Identity
    public let release: ReleaseSettings
    public let featurePattern: FeaturePattern
    public let rules: Rules

    public init(
        schemaVersion: Int,
        name: String,
        defaults: Defaults,
        identity: Identity = .init(),
        release: ReleaseSettings = .init(primaryLanguage: "en-US"),
        featurePattern: FeaturePattern,
        rules: Rules
    ) throws {
        self.schemaVersion = schemaVersion
        self.name = name
        self.defaults = defaults
        self.identity = identity
        self.release = release
        self.featurePattern = featurePattern
        self.rules = rules
        try validate()
    }
}

extension Profile: StrictSchema {
    static let schemaName = "Profile"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case name
        case defaults
        case identity
        case release
        case featurePattern
        case rules
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        self.name = try c.decode(String.self, forKey: .name)
        self.defaults = try c.decode(Defaults.self, forKey: .defaults)
        self.identity = try c.decodeIfPresent(Identity.self, forKey: .identity) ?? .init()
        self.release = try c.decodeIfPresent(ReleaseSettings.self, forKey: .release) ?? .init(primaryLanguage: "en-US")
        self.featurePattern = try c.decode(FeaturePattern.self, forKey: .featurePattern)
        self.rules = try c.decode(Rules.self, forKey: .rules)
        try validate()
    }

    func validate() throws {
        guard schemaVersion == 1 else {
            throw SchemaValidationError.unsupportedSchemaVersion(
                schema: Self.schemaName,
                expected: 1,
                actual: schemaVersion
            )
        }
    }
}

extension Profile {
    public struct Defaults: Codable, Sendable {
        public let deploymentTarget: String
        public let appTargets: AppTargets

        public init(deploymentTarget: String, appTargets: AppTargets) {
            self.deploymentTarget = deploymentTarget
            self.appTargets = appTargets
        }
    }

    public struct Identity: Codable, Sendable {
        public let companyName: String?
        public let appName: String?
        public let appIdentifier: String?
        public let appleTeamId: String?

        public init(
            companyName: String? = nil,
            appName: String? = nil,
            appIdentifier: String? = nil,
            appleTeamId: String? = nil
        ) {
            self.companyName = Self.normalized(companyName)
            self.appName = Self.normalized(appName)
            self.appIdentifier = Self.normalized(appIdentifier)
            self.appleTeamId = Self.normalized(appleTeamId)
        }
    }

    public struct ReleaseSettings: Codable, Sendable {
        public let primaryLanguage: String
        public let sku: String?
        public let appStoreAppId: String?
        public let matchGitURL: String?

        public init(
            primaryLanguage: String = "en-US",
            sku: String? = nil,
            appStoreAppId: String? = nil,
            matchGitURL: String? = nil
        ) {
            self.primaryLanguage = primaryLanguage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "en-US"
                : primaryLanguage.trimmingCharacters(in: .whitespacesAndNewlines)
            self.sku = Identity.normalized(sku)
            self.appStoreAppId = Identity.normalized(appStoreAppId)
            self.matchGitURL = Identity.normalized(matchGitURL)
        }
    }

    public struct AppTargets: Codable, Sendable {
        public let controlsExtension: Bool
        public let uiTests: Bool

        public init(controlsExtension: Bool, uiTests: Bool) {
            self.controlsExtension = controlsExtension
            self.uiTests = uiTests
        }
    }

    public struct FeaturePattern: Codable, Sendable {
        public let sourcesInterface: Bool
        public let designFolder: Bool

        public init(sourcesInterface: Bool, designFolder: Bool) {
            self.sourcesInterface = sourcesInterface
            self.designFolder = designFolder
        }
    }

    public struct Rules: Codable, Sendable {
        public let testingStyle: String
        public let forbidPatterns: [String]

        public init(testingStyle: String, forbidPatterns: [String]) throws {
            self.testingStyle = testingStyle
            self.forbidPatterns = forbidPatterns
            try validate()
        }
    }
}

extension Profile.Identity {
    fileprivate static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension Profile.ReleaseSettings {
    fileprivate static let `default` = Profile.ReleaseSettings(primaryLanguage: "en-US")
}

extension Profile.Defaults {
    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case deploymentTarget
        case appTargets
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: "Profile.defaults",
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.deploymentTarget = try c.decode(String.self, forKey: .deploymentTarget)
        self.appTargets = try c.decode(Profile.AppTargets.self, forKey: .appTargets)
    }
}

extension Profile.Identity: StrictSchema {
    static let schemaName = "Profile.identity"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case companyName
        case appName
        case appIdentifier
        case appleTeamId
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.companyName = Self.normalized(try c.decodeIfPresent(String.self, forKey: .companyName))
        self.appName = Self.normalized(try c.decodeIfPresent(String.self, forKey: .appName))
        self.appIdentifier = Self.normalized(try c.decodeIfPresent(String.self, forKey: .appIdentifier))
        self.appleTeamId = Self.normalized(try c.decodeIfPresent(String.self, forKey: .appleTeamId))
        try validate()
    }

    func validate() throws {}
}

extension Profile.ReleaseSettings: StrictSchema {
    static let schemaName = "Profile.release"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case primaryLanguage
        case sku
        case appStoreAppId
        case matchGitURL
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.primaryLanguage = try c.decodeIfPresent(String.self, forKey: .primaryLanguage) ?? "en-US"
        self.sku = Profile.Identity.normalized(try c.decodeIfPresent(String.self, forKey: .sku))
        self.appStoreAppId = Profile.Identity.normalized(try c.decodeIfPresent(String.self, forKey: .appStoreAppId))
        self.matchGitURL = Profile.Identity.normalized(try c.decodeIfPresent(String.self, forKey: .matchGitURL))
        try validate()
    }

    func validate() throws {
        let trimmed = primaryLanguage.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: "primaryLanguage", reason: "must not be empty")
        }
        if trimmed != "en-US" && trimmed != "ko-KR" {
            throw SchemaValidationError.invalidValue(
                schema: Self.schemaName,
                field: "primaryLanguage",
                reason: "must be one of: en-US, ko-KR"
            )
        }
        if let sku, sku.isEmpty {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: "sku", reason: "must not be empty when provided")
        }
        if let appStoreAppId,
           appStoreAppId.wholeMatch(of: #/[0-9]+/#) == nil {
            throw SchemaValidationError.invalidValue(
                schema: Self.schemaName,
                field: "appStoreAppId",
                reason: "must contain only digits when provided"
            )
        }
        if let matchGitURL, !matchGitURL.hasPrefix("https://") && !matchGitURL.hasPrefix("ssh://") && !matchGitURL.hasPrefix("git@") {
            throw SchemaValidationError.invalidValue(
                schema: Self.schemaName,
                field: "matchGitURL",
                reason: "must start with https://, ssh://, or git@ when provided"
            )
        }
    }
}

extension Profile.AppTargets {
    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case controlsExtension
        case uiTests
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: "Profile.defaults.appTargets",
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.controlsExtension = try c.decode(Bool.self, forKey: .controlsExtension)
        self.uiTests = try c.decode(Bool.self, forKey: .uiTests)
    }
}

extension Profile.FeaturePattern {
    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case sourcesInterface
        case designFolder
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: "Profile.featurePattern",
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.sourcesInterface = try c.decode(Bool.self, forKey: .sourcesInterface)
        self.designFolder = try c.decode(Bool.self, forKey: .designFolder)
    }
}

extension Profile.Rules: StrictSchema {
    static let schemaName = "Profile.rules"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case testingStyle
        case forbidPatterns
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.testingStyle = try c.decode(String.self, forKey: .testingStyle)
        self.forbidPatterns = try c.decode([String].self, forKey: .forbidPatterns)
        try validate()
    }

    func validate() throws {
        if forbidPatterns.isEmpty {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: "forbidPatterns", reason: "must not be empty")
        }
    }
}
