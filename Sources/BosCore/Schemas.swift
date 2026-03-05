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

public struct BlueprintV1: Codable, Sendable {
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

extension BlueprintV1: StrictSchema {
    fileprivate static let schemaName = "BlueprintV1"

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

extension BlueprintV1 {
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

        public init(appIdentifier: String, appleTeamId: String) throws {
            self.appIdentifier = appIdentifier
            self.appleTeamId = appleTeamId
            try validate()
        }
    }
}

extension BlueprintV1.Project: StrictSchema {
    fileprivate static let schemaName = "BlueprintV1.project"

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

extension BlueprintV1.Requirements: StrictSchema {
    fileprivate static let schemaName = "BlueprintV1.requirements"

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

extension BlueprintV1.Modules: StrictSchema {
    fileprivate static let schemaName = "BlueprintV1.modules"

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
        self.app = try c.decode(BlueprintV1.AppModule.self, forKey: .app)
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

extension BlueprintV1.AppModule: StrictSchema {
    fileprivate static let schemaName = "BlueprintV1.modules.app"

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

extension BlueprintV1.Wiring: StrictSchema {
    fileprivate static let schemaName = "BlueprintV1.wiring"

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

extension BlueprintV1.Release {
    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case fastlane
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: "BlueprintV1.release",
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.fastlane = try c.decode(BlueprintV1.Fastlane.self, forKey: .fastlane)
    }
}

extension BlueprintV1.Fastlane: StrictSchema {
    fileprivate static let schemaName = "BlueprintV1.release.fastlane"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
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
        self.appIdentifier = try c.decode(String.self, forKey: .appIdentifier)
        self.appleTeamId = try c.decode(String.self, forKey: .appleTeamId)
        try validate()
    }

    fileprivate func validate() throws {
        if appIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: "appIdentifier", reason: "must not be empty")
        }
        if appleTeamId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: "appleTeamId", reason: "must not be empty")
        }
    }
}

public struct ProfileV1: Codable, Sendable {
    public let schemaVersion: Int
    public let name: String
    public let defaults: Defaults
    public let featurePattern: FeaturePattern
    public let rules: Rules

    public init(
        schemaVersion: Int,
        name: String,
        defaults: Defaults,
        featurePattern: FeaturePattern,
        rules: Rules
    ) throws {
        self.schemaVersion = schemaVersion
        self.name = name
        self.defaults = defaults
        self.featurePattern = featurePattern
        self.rules = rules
        try validate()
    }
}

extension ProfileV1: StrictSchema {
    fileprivate static let schemaName = "ProfileV1"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case name
        case defaults
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

extension ProfileV1 {
    public struct Defaults: Codable, Sendable {
        public let deploymentTarget: String
        public let appTargets: AppTargets

        public init(deploymentTarget: String, appTargets: AppTargets) {
            self.deploymentTarget = deploymentTarget
            self.appTargets = appTargets
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

extension ProfileV1.Defaults {
    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case deploymentTarget
        case appTargets
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: "ProfileV1.defaults",
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.deploymentTarget = try c.decode(String.self, forKey: .deploymentTarget)
        self.appTargets = try c.decode(ProfileV1.AppTargets.self, forKey: .appTargets)
    }
}

extension ProfileV1.AppTargets {
    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case controlsExtension
        case uiTests
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: "ProfileV1.defaults.appTargets",
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.controlsExtension = try c.decode(Bool.self, forKey: .controlsExtension)
        self.uiTests = try c.decode(Bool.self, forKey: .uiTests)
    }
}

extension ProfileV1.FeaturePattern {
    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case sourcesInterface
        case designFolder
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: "ProfileV1.featurePattern",
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.sourcesInterface = try c.decode(Bool.self, forKey: .sourcesInterface)
        self.designFolder = try c.decode(Bool.self, forKey: .designFolder)
    }
}

extension ProfileV1.Rules: StrictSchema {
    fileprivate static let schemaName = "ProfileV1.rules"

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

public struct ToolchainLockV1: Codable, Sendable {
    public let schemaVersion: Int
    public let swift: String
    public let tuist: String
    public let fastlane: String
    public let tmaPluginRef: TMAPluginRef

    public init(
        schemaVersion: Int,
        swift: String,
        tuist: String,
        fastlane: String,
        tmaPluginRef: TMAPluginRef
    ) throws {
        self.schemaVersion = schemaVersion
        self.swift = swift
        self.tuist = tuist
        self.fastlane = fastlane
        self.tmaPluginRef = tmaPluginRef
        try validate()
    }
}

extension ToolchainLockV1: StrictSchema {
    fileprivate static let schemaName = "ToolchainLockV1"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case swift
        case tuist
        case fastlane
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
        self.swift = try c.decode(String.self, forKey: .swift)
        self.tuist = try c.decode(String.self, forKey: .tuist)
        self.fastlane = try c.decode(String.self, forKey: .fastlane)
        self.tmaPluginRef = try c.decode(TMAPluginRef.self, forKey: .tmaPluginRef)
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

extension ToolchainLockV1 {
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

extension ToolchainLockV1.TMAPluginRef: StrictSchema {
    fileprivate static let schemaName = "ToolchainLockV1.tmaPluginRef"

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

public struct ToolchainLockV2: Codable, Sendable {
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

extension ToolchainLockV2: StrictSchema {
    fileprivate static let schemaName = "ToolchainLockV2"

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

extension ToolchainLockV2 {
    public struct Tools: Codable, Sendable {
        public let swift: ToolRequirement
        public let tuist: ToolRequirement
        public let fastlane: ToolRequirement

        public init(swift: ToolRequirement, tuist: ToolRequirement, fastlane: ToolRequirement) throws {
            self.swift = swift
            self.tuist = tuist
            self.fastlane = fastlane
            try validate()
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

extension ToolchainLockV2.Tools: StrictSchema {
    fileprivate static let schemaName = "ToolchainLockV2.tools"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case swift
        case tuist
        case fastlane
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.swift = try c.decode(ToolchainLockV2.ToolRequirement.self, forKey: .swift)
        self.tuist = try c.decode(ToolchainLockV2.ToolRequirement.self, forKey: .tuist)
        self.fastlane = try c.decode(ToolchainLockV2.ToolRequirement.self, forKey: .fastlane)
        try validate()
    }

    fileprivate func validate() throws {}
}

extension ToolchainLockV2.ToolRequirement: StrictSchema {
    fileprivate static let schemaName = "ToolchainLockV2.tools.toolRequirement"

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
        self.versionRule = try c.decode(ToolchainLockV2.VersionRule.self, forKey: .versionRule)
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

extension ToolchainLockV2.VersionRule: StrictSchema {
    fileprivate static let schemaName = "ToolchainLockV2.tools.versionRule"

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

extension ToolchainLockV2.TMAPluginRef: StrictSchema {
    fileprivate static let schemaName = "ToolchainLockV2.tmaPluginRef"

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

extension ToolchainLockV2 {
    public static let commandPlan = "plan"
    public static let commandApply = "apply"
    public static let commandVerify = "verify"
    public static let commandReleaseInit = "release-init"
    public static let commandDoctor = "doctor"

    public static var coreCommands: [String] {
        [commandPlan, commandApply, commandVerify]
    }

    public static var allCommands: [String] {
        [commandPlan, commandApply, commandVerify, commandReleaseInit]
    }

    public static func defaultPolicy(tmaPluginRef: TMAPluginRef) throws -> ToolchainLockV2 {
        let swiftRule = try VersionRule(kind: "semver-range", value: ">=6.0 <7.0")
        let tuistRule = try VersionRule(kind: "semver-range", value: ">=4.0.0 <5.0.0")
        let fastlaneRule = try VersionRule(kind: "semver-range", value: ">=2.228.0 <3.0.0")

        return try ToolchainLockV2(
            schemaVersion: 2,
            tools: Tools(
                swift: try ToolRequirement(
                    versionRule: swiftRule,
                    requiredFor: allCommands,
                    installHints: ["xcode-select --install", "brew install swift"]
                ),
                tuist: try ToolRequirement(
                    versionRule: tuistRule,
                    requiredFor: [commandApply, commandVerify],
                    installHints: ["brew install tuist", "mise use -g tuist@latest"]
                ),
                fastlane: try ToolRequirement(
                    versionRule: fastlaneRule,
                    requiredFor: [commandReleaseInit],
                    installHints: ["brew install fastlane", "gem install fastlane -NV"]
                )
            ),
            tmaPluginRef: tmaPluginRef
        )
    }
}

extension ToolchainLockV1 {
    public func asToolchainLockV2() throws -> ToolchainLockV2 {
        func majorRange(from version: String) throws -> ToolchainLockV2.VersionRule {
            let raw = version.trimmingCharacters(in: .whitespacesAndNewlines)
            let components = raw.split(separator: ".")
            guard let majorRaw = components.first, let major = Int(majorRaw) else {
                let exactValue = raw.isEmpty ? "0" : raw
                return try ToolchainLockV2.VersionRule(kind: "exact", value: exactValue)
            }
            let upper = major + 1
            let lowerBound = components.prefix(3).joined(separator: ".")
            let value = ">=\(lowerBound) <\(upper).0.0"
            return try ToolchainLockV2.VersionRule(kind: "semver-range", value: value)
        }

        return try ToolchainLockV2(
            schemaVersion: 2,
            tools: .init(
                swift: try .init(
                    versionRule: majorRange(from: swift),
                    requiredFor: ToolchainLockV2.allCommands,
                    installHints: ["xcode-select --install", "brew install swift"]
                ),
                tuist: try .init(
                    versionRule: majorRange(from: tuist),
                    requiredFor: [ToolchainLockV2.commandApply, ToolchainLockV2.commandVerify],
                    installHints: ["brew install tuist", "mise use -g tuist@latest"]
                ),
                fastlane: try .init(
                    versionRule: majorRange(from: fastlane),
                    requiredFor: [ToolchainLockV2.commandReleaseInit],
                    installHints: ["brew install fastlane", "gem install fastlane -NV"]
                )
            ),
            tmaPluginRef: .init(type: tmaPluginRef.type, value: tmaPluginRef.value)
        )
    }
}

public struct BootstrapLockV1: Codable, Sendable {
    public let appliedAt: String
    public let blueprintHash: String
    public let profileHash: String
    public let managedFiles: [String]
    public let verifySummary: StepSummary
    public let releaseSummary: StepSummary

    public init(
        appliedAt: String,
        blueprintHash: String,
        profileHash: String,
        managedFiles: [String],
        verifySummary: StepSummary,
        releaseSummary: StepSummary
    ) throws {
        self.appliedAt = appliedAt
        self.blueprintHash = blueprintHash
        self.profileHash = profileHash
        self.managedFiles = managedFiles
        self.verifySummary = verifySummary
        self.releaseSummary = releaseSummary
        try validate()
    }
}

extension BootstrapLockV1: StrictSchema {
    fileprivate static let schemaName = "BootstrapLockV1"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case appliedAt
        case blueprintHash
        case profileHash
        case managedFiles
        case verifySummary
        case releaseSummary
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
        try validate()
    }

    fileprivate func validate() throws {
        if appliedAt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: "appliedAt", reason: "must not be empty")
        }
    }
}

extension BootstrapLockV1 {
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

extension BootstrapLockV1.StepSummary: StrictSchema {
    fileprivate static let schemaName = "BootstrapLockV1.stepSummary"

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

extension ProfileV1 {
    public static let `default`: ProfileV1 = try! ProfileV1(
        schemaVersion: 1,
        name: "default",
        defaults: .init(
            deploymentTarget: "18.0",
            appTargets: .init(controlsExtension: false, uiTests: true)
        ),
        featurePattern: .init(sourcesInterface: true, designFolder: false),
        rules: try! .init(
            testingStyle: "swift-testing",
            forbidPatterns: ["@unchecked Sendable", "Date()", "UUID()"]
        )
    )
}
