import Foundation

public struct MetadataDirectoryContract: Codable, Sendable {
    public let schemaVersion: Int
    public let rootDirectory: String
    public let defaultLocale: String
    public let localeDirectories: [LocaleDirectory]
    public let requiredFiles: [String]
    public let optionalFiles: [String]

    public init(
        schemaVersion: Int = 1,
        rootDirectory: String,
        defaultLocale: String,
        localeDirectories: [LocaleDirectory],
        requiredFiles: [String],
        optionalFiles: [String] = []
    ) throws {
        self.schemaVersion = schemaVersion
        self.rootDirectory = rootDirectory
        self.defaultLocale = defaultLocale
        self.localeDirectories = localeDirectories
        self.requiredFiles = requiredFiles
        self.optionalFiles = optionalFiles
        try validate()
    }
}

extension MetadataDirectoryContract: StrictSchema {
    static let schemaName = "MetadataDirectoryContract"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case rootDirectory
        case defaultLocale
        case localeDirectories
        case requiredFiles
        case optionalFiles
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        self.rootDirectory = try c.decode(String.self, forKey: .rootDirectory)
        self.defaultLocale = try c.decode(String.self, forKey: .defaultLocale)
        self.localeDirectories = try c.decode([LocaleDirectory].self, forKey: .localeDirectories)
        self.requiredFiles = try c.decode([String].self, forKey: .requiredFiles)
        self.optionalFiles = try c.decodeIfPresent([String].self, forKey: .optionalFiles) ?? []
        try validate()
    }

    func validate() throws {
        if schemaVersion != 1 {
            throw SchemaValidationError.unsupportedSchemaVersion(
                schema: Self.schemaName,
                expected: 1,
                actual: schemaVersion
            )
        }
        try validateNonEmpty(rootDirectory, field: "rootDirectory")
        try validateNonEmpty(defaultLocale, field: "defaultLocale")
        if localeDirectories.isEmpty {
            throw SchemaValidationError.invalidValue(
                schema: Self.schemaName,
                field: "localeDirectories",
                reason: "must not be empty"
            )
        }
        let locales = localeDirectories.map(\.locale)
        if !locales.contains(defaultLocale) {
            throw SchemaValidationError.invalidValue(
                schema: Self.schemaName,
                field: "defaultLocale",
                reason: "must match one of localeDirectories.locale"
            )
        }
        try validateUnique(localeDirectories.map(\.locale), field: "localeDirectories.locale")
        try validateUnique(requiredFiles, field: "requiredFiles")
        try validateUnique(optionalFiles, field: "optionalFiles")
        if !Set(requiredFiles).isDisjoint(with: Set(optionalFiles)) {
            throw SchemaValidationError.invalidValue(
                schema: Self.schemaName,
                field: "optionalFiles",
                reason: "must not overlap requiredFiles"
            )
        }
    }
}

extension MetadataDirectoryContract {
    public struct LocaleDirectory: Codable, Sendable {
        public let locale: String
        public let relativePath: String

        public init(locale: String, relativePath: String) throws {
            self.locale = locale
            self.relativePath = relativePath
            try validate()
        }
    }
}

extension MetadataDirectoryContract.LocaleDirectory: StrictSchema {
    static let schemaName = "MetadataDirectoryContract.localeDirectory"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case locale
        case relativePath
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.locale = try c.decode(String.self, forKey: .locale)
        self.relativePath = try c.decode(String.self, forKey: .relativePath)
        try validate()
    }

    func validate() throws {
        try validateNonEmpty(locale, field: "locale")
        try validateNonEmpty(relativePath, field: "relativePath")
    }
}

public struct MetadataLocaleSnapshot: Codable, Sendable {
    public let locale: String
    public let relativePath: String
    public let files: [MetadataFileSnapshot]

    public init(locale: String, relativePath: String, files: [MetadataFileSnapshot]) throws {
        self.locale = locale
        self.relativePath = relativePath
        self.files = files
        try validate()
    }
}

extension MetadataLocaleSnapshot: StrictSchema {
    static let schemaName = "MetadataLocaleSnapshot"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case locale
        case relativePath
        case files
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.locale = try c.decode(String.self, forKey: .locale)
        self.relativePath = try c.decode(String.self, forKey: .relativePath)
        self.files = try c.decode([MetadataFileSnapshot].self, forKey: .files)
        try validate()
    }

    func validate() throws {
        try validateNonEmpty(locale, field: "locale")
        try validateNonEmpty(relativePath, field: "relativePath")
        try validateUnique(files.map(\.relativePath), field: "files.relativePath")
    }
}

public struct MetadataFileSnapshot: Codable, Sendable {
    public let key: String
    public let relativePath: String
    public let required: Bool
    public let byteCount: Int

    public init(key: String, relativePath: String, required: Bool, byteCount: Int) throws {
        self.key = key
        self.relativePath = relativePath
        self.required = required
        self.byteCount = byteCount
        try validate()
    }
}

extension MetadataFileSnapshot: StrictSchema {
    static let schemaName = "MetadataFileSnapshot"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case key
        case relativePath
        case required
        case byteCount
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.key = try c.decode(String.self, forKey: .key)
        self.relativePath = try c.decode(String.self, forKey: .relativePath)
        self.required = try c.decode(Bool.self, forKey: .required)
        self.byteCount = try c.decode(Int.self, forKey: .byteCount)
        try validate()
    }

    func validate() throws {
        try validateNonEmpty(key, field: "key")
        try validateNonEmpty(relativePath, field: "relativePath")
        if byteCount < 0 {
            throw SchemaValidationError.invalidValue(
                schema: Self.schemaName,
                field: "byteCount",
                reason: "must be >= 0"
            )
        }
    }
}

public struct MetadataDiffReport: Codable, Sendable {
    public let hasChanges: Bool
    public let changedFiles: [String]
    public let missingLocales: [String]
    public let extraFiles: [String]

    public init(
        hasChanges: Bool,
        changedFiles: [String],
        missingLocales: [String],
        extraFiles: [String]
    ) throws {
        self.hasChanges = hasChanges
        self.changedFiles = changedFiles
        self.missingLocales = missingLocales
        self.extraFiles = extraFiles
        try validate()
    }
}

extension MetadataDiffReport: StrictSchema {
    static let schemaName = "MetadataDiffReport"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case hasChanges
        case changedFiles
        case missingLocales
        case extraFiles
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.hasChanges = try c.decode(Bool.self, forKey: .hasChanges)
        self.changedFiles = try c.decodeIfPresent([String].self, forKey: .changedFiles) ?? []
        self.missingLocales = try c.decodeIfPresent([String].self, forKey: .missingLocales) ?? []
        self.extraFiles = try c.decodeIfPresent([String].self, forKey: .extraFiles) ?? []
        try validate()
    }

    func validate() throws {}
}

public struct MetadataValidationReport: Codable, Sendable {
    public let valid: Bool
    public let missingLocales: [String]
    public let missingRequiredFiles: [String]
    public let emptyRequiredFiles: [String]

    public init(
        valid: Bool,
        missingLocales: [String],
        missingRequiredFiles: [String],
        emptyRequiredFiles: [String]
    ) throws {
        self.valid = valid
        self.missingLocales = missingLocales
        self.missingRequiredFiles = missingRequiredFiles
        self.emptyRequiredFiles = emptyRequiredFiles
        try validate()
    }
}

extension MetadataValidationReport: StrictSchema {
    static let schemaName = "MetadataValidationReport"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case valid
        case missingLocales
        case missingRequiredFiles
        case emptyRequiredFiles
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.valid = try c.decode(Bool.self, forKey: .valid)
        self.missingLocales = try c.decodeIfPresent([String].self, forKey: .missingLocales) ?? []
        self.missingRequiredFiles = try c.decodeIfPresent([String].self, forKey: .missingRequiredFiles) ?? []
        self.emptyRequiredFiles = try c.decodeIfPresent([String].self, forKey: .emptyRequiredFiles) ?? []
        try validate()
    }

    func validate() throws {}
}

private extension MetadataDirectoryContract {
    func validateNonEmpty(_ value: String, field: String) throws {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: field, reason: "must not be empty")
        }
    }

    func validateUnique(_ values: [String], field: String) throws {
        if Set(values).count != values.count {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: field, reason: "must not contain duplicates")
        }
    }
}

private extension MetadataDirectoryContract.LocaleDirectory {
    func validateNonEmpty(_ value: String, field: String) throws {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: field, reason: "must not be empty")
        }
    }
}

private extension MetadataLocaleSnapshot {
    func validateNonEmpty(_ value: String, field: String) throws {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: field, reason: "must not be empty")
        }
    }

    func validateUnique(_ values: [String], field: String) throws {
        if Set(values).count != values.count {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: field, reason: "must not contain duplicates")
        }
    }
}

private extension MetadataFileSnapshot {
    func validateNonEmpty(_ value: String, field: String) throws {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: field, reason: "must not be empty")
        }
    }
}
