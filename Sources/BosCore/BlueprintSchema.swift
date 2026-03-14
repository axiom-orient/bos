import Foundation

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
    static let schemaName = "Blueprint"

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
    static let schemaName = "Blueprint.project"

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

    func validate() throws {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: "name", reason: "must not be empty")
        }
    }
}

extension Blueprint.Requirements: StrictSchema {
    static let schemaName = "Blueprint.requirements"

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

    func validate() throws {
        if reqIds.isEmpty {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: "reqIds", reason: "must not be empty")
        }
    }
}

extension Blueprint.Modules: StrictSchema {
    static let schemaName = "Blueprint.modules"

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

    func validate() throws {
        if features.isEmpty {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: "features", reason: "must not be empty")
        }
    }
}

extension Blueprint.AppModule: StrictSchema {
    static let schemaName = "Blueprint.modules.app"

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

    func validate() throws {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: "name", reason: "must not be empty")
        }
    }
}

extension Blueprint.Wiring: StrictSchema {
    static let schemaName = "Blueprint.wiring"

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

    func validate() throws {
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
    static let schemaName = "Blueprint.release.fastlane"

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

    func validate() throws {
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
