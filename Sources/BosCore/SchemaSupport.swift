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

struct AnyCodingKey: CodingKey {
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

protocol StrictSchema {
    static var schemaName: String { get }
    func validate() throws
}

func rejectUnknownKeys(
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

func validateNonEmpty(_ value: String, schema: String, field: String) throws {
    if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        throw SchemaValidationError.invalidValue(
            schema: schema,
            field: field,
            reason: "must not be empty"
        )
    }
}

func validateUnique(_ values: [String], schema: String, field: String) throws {
    if Set(values).count != values.count {
        throw SchemaValidationError.invalidValue(
            schema: schema,
            field: field,
            reason: "must not contain duplicates"
        )
    }
}
