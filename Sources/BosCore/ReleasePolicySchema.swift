import Foundation

public struct ReleasePolicy: Codable, Sendable {
    public let schemaVersion: Int
    public let submitRequirements: SubmitRequirements
    public let defaultSigningMode: String
    public let releaseAutomation: String
    public let requiredLocales: [String]

    public init(
        schemaVersion: Int = 1,
        submitRequirements: SubmitRequirements,
        defaultSigningMode: String,
        releaseAutomation: String,
        requiredLocales: [String] = []
    ) throws {
        self.schemaVersion = schemaVersion
        self.submitRequirements = submitRequirements
        self.defaultSigningMode = defaultSigningMode
        self.releaseAutomation = releaseAutomation
        self.requiredLocales = requiredLocales
        try validate()
    }
}

extension ReleasePolicy: StrictSchema {
    static let schemaName = "ReleasePolicy"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case submitRequirements
        case defaultSigningMode
        case releaseAutomation
        case requiredLocales
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        self.submitRequirements = try c.decode(SubmitRequirements.self, forKey: .submitRequirements)
        self.defaultSigningMode = try c.decode(String.self, forKey: .defaultSigningMode)
        self.releaseAutomation = try c.decode(String.self, forKey: .releaseAutomation)
        self.requiredLocales = try c.decodeIfPresent([String].self, forKey: .requiredLocales) ?? []
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
        if defaultSigningMode != "readonly-certs" && defaultSigningMode != "sync-certs" {
            throw SchemaValidationError.invalidValue(
                schema: Self.schemaName,
                field: "defaultSigningMode",
                reason: "must be one of: readonly-certs, sync-certs"
            )
        }
        if releaseAutomation != "manual" && releaseAutomation != "auto" && releaseAutomation != "phased" {
            throw SchemaValidationError.invalidValue(
                schema: Self.schemaName,
                field: "releaseAutomation",
                reason: "must be one of: manual, auto, phased"
            )
        }
        try validateUnique(requiredLocales, schema: Self.schemaName, field: "requiredLocales")
        if requiredLocales.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            throw SchemaValidationError.invalidValue(
                schema: Self.schemaName,
                field: "requiredLocales",
                reason: "must not include empty locale"
            )
        }
    }
}

extension ReleasePolicy {
    public enum DefaultSigningMode: String, Codable, Sendable {
        case readonlyCerts = "readonly-certs"
        case syncCerts = "sync-certs"
    }

    public enum ReleaseAutomationMode: String, Codable, Sendable {
        case manual
        case auto
        case phased
    }

    public struct SubmitRequirements: Codable, Sendable {
        public let metadataValidation: Bool
        public let screenshotsValidation: Bool

        public init(metadataValidation: Bool, screenshotsValidation: Bool) {
            self.metadataValidation = metadataValidation
            self.screenshotsValidation = screenshotsValidation
        }
    }

    public static func defaultPolicy() -> ReleasePolicy {
        try! ReleasePolicy(
            submitRequirements: .init(
                metadataValidation: false,
                screenshotsValidation: false
            ),
            defaultSigningMode: "readonly-certs",
            releaseAutomation: "manual",
            requiredLocales: []
        )
    }

    public var signingMode: DefaultSigningMode {
        DefaultSigningMode(rawValue: defaultSigningMode)!
    }

    public var automationMode: ReleaseAutomationMode {
        ReleaseAutomationMode(rawValue: releaseAutomation)!
    }
}

extension ReleasePolicy.SubmitRequirements: StrictSchema {
    static let schemaName = "ReleasePolicy.submitRequirements"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case metadataValidation
        case screenshotsValidation
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.metadataValidation = try c.decode(Bool.self, forKey: .metadataValidation)
        self.screenshotsValidation = try c.decode(Bool.self, forKey: .screenshotsValidation)
    }

    func validate() throws {}
}
