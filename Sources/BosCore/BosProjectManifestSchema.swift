import Foundation

public struct BosProjectManifest: Codable, Sendable {
    public let schemaVersion: Int
    public let product: Product
    public let paths: Paths

    public init(schemaVersion: Int, product: Product, paths: Paths) throws {
        self.schemaVersion = schemaVersion
        self.product = product
        self.paths = paths
        try validate()
    }
}

extension BosProjectManifest: StrictSchema {
    static let schemaName = "BosProjectManifest"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case product
        case paths
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        self.product = try c.decode(Product.self, forKey: .product)
        self.paths = try c.decode(Paths.self, forKey: .paths)
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

extension BosProjectManifest {
    public struct Product: Codable, Sendable {
        public let mode: String

        public init(mode: String) throws {
            self.mode = mode
            try validate()
        }
    }

    public struct Paths: Codable, Sendable {
        public let profile: String
        public let blueprintLock: String
        public let releasePolicy: String
        public let screenshotsPlan: String
        public let signingEnv: String
        public let state: String

        public init(
            profile: String,
            blueprintLock: String,
            releasePolicy: String,
            screenshotsPlan: String,
            signingEnv: String,
            state: String
        ) throws {
            self.profile = profile
            self.blueprintLock = blueprintLock
            self.releasePolicy = releasePolicy
            self.screenshotsPlan = screenshotsPlan
            self.signingEnv = signingEnv
            self.state = state
            try validate()
        }
    }
}

extension BosProjectManifest.Product: StrictSchema {
    static let schemaName = "BosProjectManifest.product"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case mode
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.mode = try c.decode(String.self, forKey: .mode)
        try validate()
    }

    func validate() throws {
        if mode != "single-app" {
            throw SchemaValidationError.invalidValue(
                schema: Self.schemaName,
                field: "mode",
                reason: "must be single-app"
            )
        }
    }
}

extension BosProjectManifest.Paths: StrictSchema {
    static let schemaName = "BosProjectManifest.paths"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case profile
        case blueprintLock
        case releasePolicy
        case screenshotsPlan
        case signingEnv
        case state
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.profile = try c.decode(String.self, forKey: .profile)
        self.blueprintLock = try c.decode(String.self, forKey: .blueprintLock)
        self.releasePolicy = try c.decode(String.self, forKey: .releasePolicy)
        self.screenshotsPlan = try c.decode(String.self, forKey: .screenshotsPlan)
        self.signingEnv = try c.decode(String.self, forKey: .signingEnv)
        self.state = try c.decode(String.self, forKey: .state)
        try validate()
    }

    func validate() throws {
        let values: [(String, String)] = [
            ("profile", profile),
            ("blueprintLock", blueprintLock),
            ("releasePolicy", releasePolicy),
            ("screenshotsPlan", screenshotsPlan),
            ("signingEnv", signingEnv),
            ("state", state)
        ]
        for (field, value) in values where value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SchemaValidationError.invalidValue(
                schema: Self.schemaName,
                field: field,
                reason: "must not be empty"
            )
        }
    }
}
