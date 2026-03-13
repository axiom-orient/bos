import Foundation

public enum SchemaValidationError: Error, Equatable {
    case unknownKeys(schema: String, keys: [String])
    case unsupportedSchemaVersion(schema: String, expected: Int, actual: Int)
    case invalidValue(schema: String, field: String, reason: String)
}

extension SchemaValidationError: CustomStringConvertible, LocalizedError {
    public var description: String {
        switch self {
        case .unknownKeys(let schema, let keys):
            return "\(schema): unknown keys \(keys.joined(separator: ", "))"
        case .unsupportedSchemaVersion(let schema, let expected, let actual):
            return "\(schema): unsupported schemaVersion \(actual), expected \(expected)"
        case .invalidValue(let schema, let field, let reason):
            return "\(schema).\(field): \(reason)"
        }
    }

    public var errorDescription: String? { description }
}

private struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

private protocol StrictSchema {
    static var schemaName: String { get }
    func validate() throws
}

private func rejectUnknownKeys(
    _ decoder: Decoder,
    schema: String,
    allowedKeys: some Sequence<String>
) throws {
    let known = Set(allowedKeys)
    let raw = try decoder.container(keyedBy: AnyCodingKey.self)
    let unknown = raw.allKeys
        .map(\.stringValue)
        .filter { !known.contains($0) }
        .sorted()
    if !unknown.isEmpty {
        throw SchemaValidationError.unknownKeys(schema: schema, keys: unknown)
    }
}

public struct Blueprint: Codable, Sendable {
    public let schemaVersion: Int
    public let project: Project
    public let requirements: Requirements
    public let modules: Modules
    public let wiring: Wiring
    public let release: Release

    public init(
        schemaVersion: Int,
        project: Project,
        requirements: Requirements,
        modules: Modules,
        wiring: Wiring,
        release: Release
    ) throws {
        self.schemaVersion = schemaVersion
        self.project = project
        self.requirements = requirements
        self.modules = modules
        self.wiring = wiring
        self.release = release
        try validate()
    }
}

extension Blueprint: StrictSchema {
    fileprivate static let schemaName = "Blueprint"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case project
        case requirements
        case modules
        case wiring
        case release
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        self.project = try c.decode(Project.self, forKey: .project)
        self.requirements = try c.decode(Requirements.self, forKey: .requirements)
        self.modules = try c.decode(Modules.self, forKey: .modules)
        self.wiring = try c.decode(Wiring.self, forKey: .wiring)
        self.release = try c.decode(Release.self, forKey: .release)
        try validate()
    }

    fileprivate func validate() throws {
        guard schemaVersion == 1 else {
            throw SchemaValidationError.unsupportedSchemaVersion(
                schema: Self.schemaName,
                expected: 1,
                actual: schemaVersion
            )
        }
    }
}

extension Blueprint {
    public struct Project: Codable, Sendable {
        public let name: String
        public let bundleIdPrefix: String
        public let deploymentTarget: String

        public init(name: String, bundleIdPrefix: String, deploymentTarget: String) throws {
            self.name = name
            self.bundleIdPrefix = bundleIdPrefix
            self.deploymentTarget = deploymentTarget
            try validate()
        }
    }

    public struct Requirements: Codable, Sendable {
        public let reqIds: [String]
        public let screens: [String]

        public init(reqIds: [String], screens: [String]) throws {
            self.reqIds = reqIds
            self.screens = screens
            try validate()
        }
    }

    public struct Modules: Codable, Sendable {
        public let app: AppModule
        public let features: [String]
        public let domains: [String]
        public let services: [String]
        public let shared: [String]

        public init(
            app: AppModule,
            features: [String],
            domains: [String],
            services: [String],
            shared: [String]
        ) throws {
            self.app = app
            self.features = features
            self.domains = domains
            self.services = services
            self.shared = shared
            try validate()
        }
    }

    public struct AppModule: Codable, Sendable {
        public let name: String

        public init(name: String) throws {
            self.name = name
            try validate()
        }
    }

    public struct Wiring: Codable, Sendable {
        public let rootFeature: String
        public let tabFeatures: [String]?

        public init(rootFeature: String, tabFeatures: [String]? = nil) throws {
            self.rootFeature = rootFeature
            self.tabFeatures = tabFeatures
            try validate()
        }
    }

    public struct Release: Codable, Sendable {
        public let fastlane: Fastlane

        public init(fastlane: Fastlane) {
            self.fastlane = fastlane
        }
    }

    public struct Fastlane: Codable, Sendable {
        public let appIdentifier: String
        public let appleTeamId: String
        public let appName: String?
        public let sku: String?
        public let primaryLanguage: String?
        public let companyName: String?

        public init(
            appIdentifier: String,
            appleTeamId: String,
            appName: String? = nil,
            sku: String? = nil,
            primaryLanguage: String? = nil,
            companyName: String? = nil
        ) throws {
            self.appIdentifier = appIdentifier
            self.appleTeamId = appleTeamId
            self.appName = Self.normalizedOptional(appName)
            self.sku = Self.normalizedOptional(sku)
            self.primaryLanguage = Self.normalizedOptional(primaryLanguage)
            self.companyName = Self.normalizedOptional(companyName)
            try validate()
        }
    }
}

extension Blueprint.Project: StrictSchema {
    fileprivate static let schemaName = "Blueprint.project"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case name
        case bundleIdPrefix
        case deploymentTarget
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try c.decode(String.self, forKey: .name)
        self.bundleIdPrefix = try c.decode(String.self, forKey: .bundleIdPrefix)
        self.deploymentTarget = try c.decode(String.self, forKey: .deploymentTarget)
        try validate()
    }

    fileprivate func validate() throws {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: "name", reason: "must not be empty")
        }
    }
}

extension Blueprint.Requirements: StrictSchema {
    fileprivate static let schemaName = "Blueprint.requirements"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case reqIds
        case screens
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.reqIds = try c.decode([String].self, forKey: .reqIds)
        self.screens = try c.decode([String].self, forKey: .screens)
        try validate()
    }

    fileprivate func validate() throws {
        if reqIds.isEmpty {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: "reqIds", reason: "must not be empty")
        }
    }
}

extension Blueprint.Modules: StrictSchema {
    fileprivate static let schemaName = "Blueprint.modules"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case app
        case features
        case domains
        case services
        case shared
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.app = try c.decode(Blueprint.AppModule.self, forKey: .app)
        self.features = try c.decode([String].self, forKey: .features)
        self.domains = try c.decode([String].self, forKey: .domains)
        self.services = try c.decode([String].self, forKey: .services)
        self.shared = try c.decode([String].self, forKey: .shared)
        try validate()
    }

    fileprivate func validate() throws {
        if features.isEmpty {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: "features", reason: "must not be empty")
        }
    }
}

extension Blueprint.AppModule: StrictSchema {
    fileprivate static let schemaName = "Blueprint.modules.app"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case name
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try c.decode(String.self, forKey: .name)
        try validate()
    }

    fileprivate func validate() throws {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: "name", reason: "must not be empty")
        }
    }
}

extension Blueprint.Wiring: StrictSchema {
    fileprivate static let schemaName = "Blueprint.wiring"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case rootFeature
        case tabFeatures
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.rootFeature = try c.decode(String.self, forKey: .rootFeature)
        self.tabFeatures = try c.decodeIfPresent([String].self, forKey: .tabFeatures)
        try validate()
    }

    fileprivate func validate() throws {
        if rootFeature.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: "rootFeature", reason: "must not be empty")
        }
    }
}

extension Blueprint.Release {
    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case fastlane
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: "Blueprint.release",
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.fastlane = try c.decode(Blueprint.Fastlane.self, forKey: .fastlane)
    }
}

extension Blueprint.Fastlane: StrictSchema {
    fileprivate static let schemaName = "Blueprint.release.fastlane"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case appIdentifier
        case appleTeamId
        case appName
        case sku
        case primaryLanguage
        case companyName
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.appIdentifier = try c.decode(String.self, forKey: .appIdentifier)
        self.appleTeamId = try c.decode(String.self, forKey: .appleTeamId)
        self.appName = try c.decodeIfPresent(String.self, forKey: .appName)
        self.sku = try c.decodeIfPresent(String.self, forKey: .sku)
        self.primaryLanguage = try c.decodeIfPresent(String.self, forKey: .primaryLanguage)
        self.companyName = try c.decodeIfPresent(String.self, forKey: .companyName)
        try validate()
    }

    fileprivate func validate() throws {
        if appIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: "appIdentifier", reason: "must not be empty")
        }
        if appleTeamId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: "appleTeamId", reason: "must not be empty")
        }
        if let appName, appName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: "appName", reason: "must not be empty when provided")
        }
        if let sku, sku.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: "sku", reason: "must not be empty when provided")
        }
        if let primaryLanguage, primaryLanguage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: "primaryLanguage", reason: "must not be empty when provided")
        }
        if let companyName, companyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: "companyName", reason: "must not be empty when provided")
        }
    }

    private static func normalizedOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

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
    fileprivate static let schemaName = "Profile"

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

    fileprivate func validate() throws {
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
    fileprivate static let schemaName = "Profile.identity"

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

    fileprivate func validate() throws {}
}

extension Profile.ReleaseSettings: StrictSchema {
    fileprivate static let schemaName = "Profile.release"

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

    fileprivate func validate() throws {
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
    fileprivate static let schemaName = "Profile.rules"

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

    fileprivate func validate() throws {
        if forbidPatterns.isEmpty {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: "forbidPatterns", reason: "must not be empty")
        }
    }
}


public struct ToolchainLock: Codable, Sendable {
    public let schemaVersion: Int
    public let tools: Tools
    public let tmaPluginRef: TMAPluginRef

    public init(schemaVersion: Int, tools: Tools, tmaPluginRef: TMAPluginRef) throws {
        self.schemaVersion = schemaVersion
        self.tools = tools
        self.tmaPluginRef = tmaPluginRef
        try validate()
    }
}

extension ToolchainLock: StrictSchema {
    fileprivate static let schemaName = "ToolchainLock"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case tools
        case tmaPluginRef
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        self.tools = try c.decode(Tools.self, forKey: .tools)
        self.tmaPluginRef = try c.decode(TMAPluginRef.self, forKey: .tmaPluginRef)
        try validate()
    }

    fileprivate func validate() throws {
        guard schemaVersion == 2 else {
            throw SchemaValidationError.unsupportedSchemaVersion(
                schema: Self.schemaName,
                expected: 2,
                actual: schemaVersion
            )
        }
    }
}

extension ToolchainLock {
    public struct Tools: Codable, Sendable {
        public let swift: ToolRequirement
        public let tuist: ToolRequirement
        public let fastlane: ToolRequirement
        public let asc: ToolRequirement

        public init(
            swift: ToolRequirement,
            tuist: ToolRequirement,
            fastlane: ToolRequirement,
            asc: ToolRequirement? = nil
        ) throws {
            self.swift = swift
            self.tuist = tuist
            self.fastlane = fastlane
            if let asc {
                self.asc = asc
            } else {
                self.asc = try Self.defaultASCRequirement()
            }
            try validate()
        }

        fileprivate static func defaultASCRequirement() throws -> ToolRequirement {
            try ToolRequirement(
                versionRule: .init(kind: "semver-range", value: ">=0.1.0"),
                requiredFor: [ToolchainLock.commandAppRegister, ToolchainLock.commandReleaseCheck, ToolchainLock.commandReleaseRun],
                installHints: [
                    "brew install asc",
                    "curl -fsSL https://asccli.sh/install | bash"
                ]
            )
        }
    }

    public struct ToolRequirement: Codable, Sendable {
        public let versionRule: VersionRule
        public let requiredFor: [String]
        public let installHints: [String]

        public init(versionRule: VersionRule, requiredFor: [String], installHints: [String]) throws {
            self.versionRule = versionRule
            self.requiredFor = requiredFor
            self.installHints = installHints
            try validate()
        }
    }

    public struct VersionRule: Codable, Sendable {
        public let kind: String
        public let value: String

        public init(kind: String, value: String) throws {
            self.kind = kind
            self.value = value
            try validate()
        }
    }

    public struct TMAPluginRef: Codable, Sendable {
        public let type: String
        public let value: String

        public init(type: String, value: String) throws {
            self.type = type
            self.value = value
            try validate()
        }
    }
}

extension ToolchainLock.Tools: StrictSchema {
    fileprivate static let schemaName = "ToolchainLock.tools"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case swift
        case tuist
        case fastlane
        case asc
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.swift = try c.decode(ToolchainLock.ToolRequirement.self, forKey: .swift)
        self.tuist = try c.decode(ToolchainLock.ToolRequirement.self, forKey: .tuist)
        self.fastlane = try c.decode(ToolchainLock.ToolRequirement.self, forKey: .fastlane)
        if let asc = try c.decodeIfPresent(ToolchainLock.ToolRequirement.self, forKey: .asc) {
            self.asc = asc
        } else {
            self.asc = try Self.defaultASCRequirement()
        }
        try validate()
    }

    fileprivate func validate() throws {}
}

extension ToolchainLock.ToolRequirement: StrictSchema {
    fileprivate static let schemaName = "ToolchainLock.tools.toolRequirement"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case versionRule
        case requiredFor
        case installHints
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.versionRule = try c.decode(ToolchainLock.VersionRule.self, forKey: .versionRule)
        self.requiredFor = try c.decode([String].self, forKey: .requiredFor)
        self.installHints = try c.decode([String].self, forKey: .installHints)
        try validate()
    }

    fileprivate func validate() throws {
        if requiredFor.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: "requiredFor", reason: "must not include empty command")
        }
        if installHints.isEmpty {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: "installHints", reason: "must not be empty")
        }
        if installHints.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: "installHints", reason: "must not include empty command")
        }
    }
}

extension ToolchainLock.VersionRule: StrictSchema {
    fileprivate static let schemaName = "ToolchainLock.tools.versionRule"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case kind
        case value
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.kind = try c.decode(String.self, forKey: .kind)
        self.value = try c.decode(String.self, forKey: .value)
        try validate()
    }

    fileprivate func validate() throws {
        let normalizedKind = kind.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedKind != "exact" && normalizedKind != "semver-range" {
            throw SchemaValidationError.invalidValue(
                schema: Self.schemaName,
                field: "kind",
                reason: "must be one of: exact, semver-range"
            )
        }
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: "value", reason: "must not be empty")
        }
    }
}

extension ToolchainLock.TMAPluginRef: StrictSchema {
    fileprivate static let schemaName = "ToolchainLock.tmaPluginRef"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case type
        case value
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try c.decode(String.self, forKey: .type)
        self.value = try c.decode(String.self, forKey: .value)
        try validate()
    }

    fileprivate func validate() throws {
        if type.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: "type", reason: "must not be empty")
        }
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: "value", reason: "must not be empty")
        }
    }
}

extension ToolchainLock {
    public static let commandPlan = "plan"
    public static let commandApply = "apply"
    public static let commandVerify = "verify"
    public static let commandAppRegister = "app-register"
    public static let commandReleaseInit = "release-init"
    public static let commandReleaseCheck = "release-check"
    public static let commandReleaseRun = "release-run"
    public static let commandDoctor = "doctor"

    public static var coreCommands: [String] {
        [commandPlan, commandApply, commandVerify]
    }

    public static var allCommands: [String] {
        [commandPlan, commandApply, commandVerify, commandAppRegister, commandReleaseInit, commandReleaseCheck, commandReleaseRun]
    }

    public static func defaultPolicy(tmaPluginRef: TMAPluginRef) throws -> ToolchainLock {
        let swiftRule = try VersionRule(kind: "semver-range", value: ">=6.0 <7.0")
        let tuistRule = try VersionRule(kind: "semver-range", value: ">=4.0.0 <5.0.0")
        let fastlaneRule = try VersionRule(kind: "semver-range", value: ">=2.228.0 <3.0.0")

        return try ToolchainLock(
            schemaVersion: 2,
            tools: Tools(
                swift: try ToolRequirement(
                    versionRule: swiftRule,
                    requiredFor: allCommands,
                    installHints: ["xcode-select --install", "brew install swift"]
                ),
                tuist: try ToolRequirement(
                    versionRule: tuistRule,
                    requiredFor: [commandApply, commandVerify, commandReleaseRun],
                    installHints: ["brew install tuist", "mise use -g tuist@latest"]
                ),
                fastlane: try ToolRequirement(
                    versionRule: fastlaneRule,
                    requiredFor: [commandReleaseInit, commandReleaseCheck, commandReleaseRun],
                    installHints: ["brew install fastlane", "gem install fastlane -NV"]
                ),
                asc: try ToolRequirement(
                    versionRule: .init(kind: "semver-range", value: ">=0.1.0"),
                    requiredFor: [commandAppRegister, commandReleaseCheck, commandReleaseRun],
                    installHints: ["brew install asc", "curl -fsSL https://asccli.sh/install | bash"]
                )
            ),
            tmaPluginRef: tmaPluginRef
        )
    }
}


public struct BootstrapLock: Codable, Sendable {
    public let appliedAt: String
    public let blueprintHash: String
    public let profileHash: String
    public let managedFiles: [String]
    public let verifySummary: StepSummary
    public let releaseSummary: StepSummary
    public let releaseCheckSummary: StepSummary?
    public let releaseRunSummary: StepSummary?

    public init(
        appliedAt: String,
        blueprintHash: String,
        profileHash: String,
        managedFiles: [String],
        verifySummary: StepSummary,
        releaseSummary: StepSummary,
        releaseCheckSummary: StepSummary? = nil,
        releaseRunSummary: StepSummary? = nil
    ) throws {
        self.appliedAt = appliedAt
        self.blueprintHash = blueprintHash
        self.profileHash = profileHash
        self.managedFiles = managedFiles
        self.verifySummary = verifySummary
        self.releaseSummary = releaseSummary
        self.releaseCheckSummary = releaseCheckSummary
        self.releaseRunSummary = releaseRunSummary
        try validate()
    }
}

extension BootstrapLock: StrictSchema {
    fileprivate static let schemaName = "BootstrapLock"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case appliedAt
        case blueprintHash
        case profileHash
        case managedFiles
        case verifySummary
        case releaseSummary
        case releaseCheckSummary
        case releaseRunSummary
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.appliedAt = try c.decode(String.self, forKey: .appliedAt)
        self.blueprintHash = try c.decode(String.self, forKey: .blueprintHash)
        self.profileHash = try c.decode(String.self, forKey: .profileHash)
        self.managedFiles = try c.decode([String].self, forKey: .managedFiles)
        self.verifySummary = try c.decode(StepSummary.self, forKey: .verifySummary)
        self.releaseSummary = try c.decode(StepSummary.self, forKey: .releaseSummary)
        self.releaseCheckSummary = try c.decodeIfPresent(StepSummary.self, forKey: .releaseCheckSummary)
        self.releaseRunSummary = try c.decodeIfPresent(StepSummary.self, forKey: .releaseRunSummary)
        try validate()
    }

    fileprivate func validate() throws {
        if appliedAt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: "appliedAt", reason: "must not be empty")
        }
    }
}

extension BootstrapLock {
    public struct StepSummary: Codable, Sendable {
        public let status: String
        public let message: String?

        public init(status: String, message: String?) throws {
            self.status = status
            self.message = message
            try validate()
        }
    }
}

extension BootstrapLock.StepSummary: StrictSchema {
    fileprivate static let schemaName = "BootstrapLock.stepSummary"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case status
        case message
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.status = try c.decode(String.self, forKey: .status)
        self.message = try c.decodeIfPresent(String.self, forKey: .message)
        try validate()
    }

    fileprivate func validate() throws {
        if status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: "status", reason: "must not be empty")
        }
    }
}

extension Profile {
    public static let `default`: Profile = try! Profile(
        schemaVersion: 1,
        name: "default",
        defaults: .init(
            deploymentTarget: "18.0",
            appTargets: .init(controlsExtension: false, uiTests: true)
        ),
        identity: .init(),
        release: .init(primaryLanguage: "en-US"),
        featurePattern: .init(sourcesInterface: true, designFolder: false),
        rules: try! .init(
            testingStyle: "swift-testing",
            forbidPatterns: ["@unchecked Sendable", "Date()", "UUID()"]
        )
    )
}
