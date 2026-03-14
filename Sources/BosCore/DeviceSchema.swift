import Foundation

public struct DeviceInventory: Codable, Sendable {
    public let schemaVersion: Int
    public let devices: [DeviceRecord]

    public init(schemaVersion: Int = 1, devices: [DeviceRecord]) throws {
        self.schemaVersion = schemaVersion
        self.devices = devices
        try validate()
    }
}

extension DeviceInventory: StrictSchema {
    static let schemaName = "DeviceInventory"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case devices
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        self.devices = try c.decode([DeviceRecord].self, forKey: .devices)
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
        try validateUnique(devices.map(\.id), schema: Self.schemaName, field: "devices.id")
    }
}

public struct DeviceRecord: Codable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let kind: String
    public let platform: String
    public let state: String
    public let runtime: String?
    public let isAvailable: Bool

    public init(
        id: String,
        name: String,
        kind: String,
        platform: String,
        state: String,
        runtime: String? = nil,
        isAvailable: Bool
    ) throws {
        self.id = id
        self.name = name
        self.kind = kind
        self.platform = platform
        self.state = state
        self.runtime = runtime
        self.isAvailable = isAvailable
        try validate()
    }
}

extension DeviceRecord: StrictSchema {
    static let schemaName = "DeviceRecord"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case id
        case name
        case kind
        case platform
        case state
        case runtime
        case isAvailable
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.kind = try c.decode(String.self, forKey: .kind)
        self.platform = try c.decode(String.self, forKey: .platform)
        self.state = try c.decode(String.self, forKey: .state)
        self.runtime = try c.decodeIfPresent(String.self, forKey: .runtime)
        self.isAvailable = try c.decode(Bool.self, forKey: .isAvailable)
        try validate()
    }

    func validate() throws {
        try validateNonEmpty(id, schema: Self.schemaName, field: "id")
        try validateNonEmpty(name, schema: Self.schemaName, field: "name")
        if kind != "simulator" && kind != "physical" {
            throw SchemaValidationError.invalidValue(
                schema: Self.schemaName,
                field: "kind",
                reason: "must be one of: simulator, physical"
            )
        }
        try validateNonEmpty(platform, schema: Self.schemaName, field: "platform")
        try validateNonEmpty(state, schema: Self.schemaName, field: "state")
    }
}

public struct DeviceDoctorReport: Codable, Sendable, Equatable {
    public let healthy: Bool
    public let findings: [String]

    public init(healthy: Bool, findings: [String]) {
        self.healthy = healthy
        self.findings = findings
    }
}

extension DeviceDoctorReport: StrictSchema {
    static let schemaName = "DeviceDoctorReport"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case healthy
        case findings
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.healthy = try c.decode(Bool.self, forKey: .healthy)
        self.findings = try c.decode([String].self, forKey: .findings)
    }

    func validate() throws {}
}
