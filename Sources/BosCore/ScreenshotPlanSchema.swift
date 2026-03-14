import Foundation

public struct ScreenshotPlan: Codable, Sendable {
    public let schemaVersion: Int
    public let defaultLocale: String
    public let locales: [LocalePlan]
    public let devices: [DevicePlan]
    public let shots: [ShotPlan]
    public let export: ExportPlan

    public init(
        schemaVersion: Int = 1,
        defaultLocale: String,
        locales: [LocalePlan],
        devices: [DevicePlan],
        shots: [ShotPlan],
        export: ExportPlan
    ) throws {
        self.schemaVersion = schemaVersion
        self.defaultLocale = defaultLocale
        self.locales = locales
        self.devices = devices
        self.shots = shots
        self.export = export
        try validate()
    }
}

extension ScreenshotPlan: StrictSchema {
    static let schemaName = "ScreenshotPlan"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case defaultLocale
        case locales
        case devices
        case shots
        case export
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        self.defaultLocale = try c.decode(String.self, forKey: .defaultLocale)
        self.locales = try c.decode([LocalePlan].self, forKey: .locales)
        self.devices = try c.decode([DevicePlan].self, forKey: .devices)
        self.shots = try c.decode([ShotPlan].self, forKey: .shots)
        self.export = try c.decode(ExportPlan.self, forKey: .export)
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
        try validateNonEmpty(defaultLocale, schema: Self.schemaName, field: "defaultLocale")
        if locales.isEmpty {
            throw SchemaValidationError.invalidValue(
                schema: Self.schemaName,
                field: "locales",
                reason: "must not be empty"
            )
        }
        if devices.isEmpty {
            throw SchemaValidationError.invalidValue(
                schema: Self.schemaName,
                field: "devices",
                reason: "must not be empty"
            )
        }
        if shots.isEmpty {
            throw SchemaValidationError.invalidValue(
                schema: Self.schemaName,
                field: "shots",
                reason: "must not be empty"
            )
        }

        let localeIds = locales.map(\.locale)
        try validateUnique(localeIds, schema: Self.schemaName, field: "locales.locale")
        if !localeIds.contains(defaultLocale) {
            throw SchemaValidationError.invalidValue(
                schema: Self.schemaName,
                field: "defaultLocale",
                reason: "must match one of locales.locale"
            )
        }

        let deviceIds = devices.map(\.id)
        try validateUnique(deviceIds, schema: Self.schemaName, field: "devices.id")

        let shotIds = shots.map(\.id)
        try validateUnique(shotIds, schema: Self.schemaName, field: "shots.id")

        let localeSet = Set(localeIds)
        let deviceSet = Set(deviceIds)
        for shot in shots {
            for locale in shot.locales where !localeSet.contains(locale) {
                throw SchemaValidationError.invalidValue(
                    schema: Self.schemaName,
                    field: "shots.locales",
                    reason: "unknown locale reference `\(locale)` in shot `\(shot.id)`"
                )
            }
            for device in shot.devices where !deviceSet.contains(device) {
                throw SchemaValidationError.invalidValue(
                    schema: Self.schemaName,
                    field: "shots.devices",
                    reason: "unknown device reference `\(device)` in shot `\(shot.id)`"
                )
            }
        }
    }
}

extension ScreenshotPlan {
    public struct LocalePlan: Codable, Sendable {
        public let locale: String
        public let displayName: String

        public init(locale: String, displayName: String) throws {
            self.locale = locale
            self.displayName = displayName
            try validate()
        }
    }

    public struct DevicePlan: Codable, Sendable {
        public let id: String
        public let name: String
        public let family: String
        public let platform: String
        public let orientation: String
        public let pixelSize: PixelSize

        public init(
            id: String,
            name: String,
            family: String,
            platform: String,
            orientation: String,
            pixelSize: PixelSize
        ) throws {
            self.id = id
            self.name = name
            self.family = family
            self.platform = platform
            self.orientation = orientation
            self.pixelSize = pixelSize
            try validate()
        }
    }

    public struct ShotPlan: Codable, Sendable {
        public let id: String
        public let screenID: String
        public let locales: [String]
        public let devices: [String]
        public let launchArguments: [String]
        public let outputName: String

        public init(
            id: String,
            screenID: String,
            locales: [String],
            devices: [String],
            launchArguments: [String] = [],
            outputName: String
        ) throws {
            self.id = id
            self.screenID = screenID
            self.locales = locales
            self.devices = devices
            self.launchArguments = launchArguments
            self.outputName = outputName
            try validate()
        }
    }

    public struct ExportPlan: Codable, Sendable {
        public let rootDirectory: String
        public let format: String
        public let includeFrame: Bool

        public init(rootDirectory: String, format: String, includeFrame: Bool) throws {
            self.rootDirectory = rootDirectory
            self.format = format
            self.includeFrame = includeFrame
            try validate()
        }
    }

    public struct PixelSize: Codable, Sendable {
        public let width: Int
        public let height: Int

        public init(width: Int, height: Int) throws {
            self.width = width
            self.height = height
            try validate()
        }
    }
}

extension ScreenshotPlan.LocalePlan: StrictSchema {
    static let schemaName = "ScreenshotPlan.locale"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case locale
        case displayName
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.locale = try c.decode(String.self, forKey: .locale)
        self.displayName = try c.decode(String.self, forKey: .displayName)
        try validate()
    }

    func validate() throws {
        try validateNonEmpty(locale, schema: Self.schemaName, field: "locale")
        try validateNonEmpty(displayName, schema: Self.schemaName, field: "displayName")
    }
}

extension ScreenshotPlan.DevicePlan: StrictSchema {
    static let schemaName = "ScreenshotPlan.device"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case id
        case name
        case family
        case platform
        case orientation
        case pixelSize
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
        self.family = try c.decode(String.self, forKey: .family)
        self.platform = try c.decode(String.self, forKey: .platform)
        self.orientation = try c.decode(String.self, forKey: .orientation)
        self.pixelSize = try c.decode(ScreenshotPlan.PixelSize.self, forKey: .pixelSize)
        try validate()
    }

    func validate() throws {
        try validateNonEmpty(id, schema: Self.schemaName, field: "id")
        try validateNonEmpty(name, schema: Self.schemaName, field: "name")
        if family != "iphone" && family != "ipad" {
            throw SchemaValidationError.invalidValue(
                schema: Self.schemaName,
                field: "family",
                reason: "must be one of: iphone, ipad"
            )
        }
        if platform != "simulator" && platform != "device" {
            throw SchemaValidationError.invalidValue(
                schema: Self.schemaName,
                field: "platform",
                reason: "must be one of: simulator, device"
            )
        }
        if orientation != "portrait" && orientation != "landscape" {
            throw SchemaValidationError.invalidValue(
                schema: Self.schemaName,
                field: "orientation",
                reason: "must be one of: portrait, landscape"
            )
        }
    }
}

extension ScreenshotPlan.ShotPlan: StrictSchema {
    static let schemaName = "ScreenshotPlan.shot"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case id
        case screenID
        case locales
        case devices
        case launchArguments
        case outputName
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.screenID = try c.decode(String.self, forKey: .screenID)
        self.locales = try c.decode([String].self, forKey: .locales)
        self.devices = try c.decode([String].self, forKey: .devices)
        self.launchArguments = try c.decodeIfPresent([String].self, forKey: .launchArguments) ?? []
        self.outputName = try c.decode(String.self, forKey: .outputName)
        try validate()
    }

    func validate() throws {
        try validateNonEmpty(id, schema: Self.schemaName, field: "id")
        try validateNonEmpty(screenID, schema: Self.schemaName, field: "screenID")
        try validateNonEmpty(outputName, schema: Self.schemaName, field: "outputName")
        if locales.isEmpty {
            throw SchemaValidationError.invalidValue(
                schema: Self.schemaName,
                field: "locales",
                reason: "must not be empty"
            )
        }
        if devices.isEmpty {
            throw SchemaValidationError.invalidValue(
                schema: Self.schemaName,
                field: "devices",
                reason: "must not be empty"
            )
        }
        try validateUnique(locales, schema: Self.schemaName, field: "locales")
        try validateUnique(devices, schema: Self.schemaName, field: "devices")
    }
}

extension ScreenshotPlan.ExportPlan: StrictSchema {
    static let schemaName = "ScreenshotPlan.export"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case rootDirectory
        case format
        case includeFrame
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.rootDirectory = try c.decode(String.self, forKey: .rootDirectory)
        self.format = try c.decode(String.self, forKey: .format)
        self.includeFrame = try c.decode(Bool.self, forKey: .includeFrame)
        try validate()
    }

    func validate() throws {
        try validateNonEmpty(rootDirectory, schema: Self.schemaName, field: "rootDirectory")
        if format != "png" {
            throw SchemaValidationError.invalidValue(
                schema: Self.schemaName,
                field: "format",
                reason: "must be png"
            )
        }
    }
}

extension ScreenshotPlan.PixelSize: StrictSchema {
    static let schemaName = "ScreenshotPlan.pixelSize"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case width
        case height
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.width = try c.decode(Int.self, forKey: .width)
        self.height = try c.decode(Int.self, forKey: .height)
        try validate()
    }

    func validate() throws {
        if width <= 0 {
            throw SchemaValidationError.invalidValue(
                schema: Self.schemaName,
                field: "width",
                reason: "must be > 0"
            )
        }
        if height <= 0 {
            throw SchemaValidationError.invalidValue(
                schema: Self.schemaName,
                field: "height",
                reason: "must be > 0"
            )
        }
    }
}
