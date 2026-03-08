import Foundation

public struct SigningEnvironmentIssue: Equatable, Sendable {
    public let key: String
    public let rule: String
    public let actual: String

    public init(key: String, rule: String, actual: String) {
        self.key = key
        self.rule = rule
        self.actual = actual
    }
}

public struct SigningEnvironmentCheckResult: Equatable, Sendable {
    public let missingKeys: [String]
    public let invalidIssues: [SigningEnvironmentIssue]

    public init(missingKeys: [String], invalidIssues: [SigningEnvironmentIssue]) {
        self.missingKeys = missingKeys
        self.invalidIssues = invalidIssues
    }

    public var isValid: Bool {
        missingKeys.isEmpty && invalidIssues.isEmpty
    }
}

public enum SigningEnvironmentPolicy {
    public static let requiredKeys: [String] = [
        "ASC_ISSUER_ID",
        "ASC_KEY_ID",
        "ASC_KEY_P8_BASE64",
        "MATCH_GIT_URL",
        "MATCH_PASSWORD"
    ]

    public static let expectedRuleSummary =
        "ASC_ISSUER_ID(uuid), ASC_KEY_ID([A-Z0-9]{10}), ASC_KEY_P8_BASE64(base64), MATCH_GIT_URL(git|https|ssh), MATCH_PASSWORD(non-empty)"

    public static func validate(environment: [String: String]) -> SigningEnvironmentCheckResult {
        let missing = requiredKeys.filter { key in
            guard let value = environment[key] else { return true }
            return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.sorted()

        var invalid: [SigningEnvironmentIssue] = []

        if let raw = normalizedValue(for: "ASC_ISSUER_ID", in: environment),
           !matches(raw, regex: uuidRegex) {
            invalid.append(
                SigningEnvironmentIssue(
                    key: "ASC_ISSUER_ID",
                    rule: "UUID format",
                    actual: "non-uuid value"
                )
            )
        }

        if let raw = normalizedValue(for: "ASC_KEY_ID", in: environment),
           !matches(raw, regex: keyIdRegex) {
            invalid.append(
                SigningEnvironmentIssue(
                    key: "ASC_KEY_ID",
                    rule: "10 uppercase letters/digits",
                    actual: "invalid key id format"
                )
            )
        }

        if let raw = normalizedValue(for: "ASC_KEY_P8_BASE64", in: environment),
           Data(base64Encoded: raw, options: [.ignoreUnknownCharacters]) == nil {
            invalid.append(
                SigningEnvironmentIssue(
                    key: "ASC_KEY_P8_BASE64",
                    rule: "valid base64-encoded key content",
                    actual: "not base64"
                )
            )
        }

        if let raw = normalizedValue(for: "MATCH_GIT_URL", in: environment),
           !isValidGitURL(raw) {
            invalid.append(
                SigningEnvironmentIssue(
                    key: "MATCH_GIT_URL",
                    rule: "git@host:path(.git) or https://... or ssh://...",
                    actual: "unsupported git url format"
                )
            )
        }

        return SigningEnvironmentCheckResult(
            missingKeys: missing,
            invalidIssues: invalid.sorted { lhs, rhs in lhs.key < rhs.key }
        )
    }
}

private extension SigningEnvironmentPolicy {
    static let uuidRegex = try! NSRegularExpression(
        pattern: #"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"#
    )
    static let keyIdRegex = try! NSRegularExpression(pattern: #"^[A-Z0-9]{10}$"#)

    static func normalizedValue(for key: String, in environment: [String: String]) -> String? {
        guard let value = environment[key] else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func matches(_ value: String, regex: NSRegularExpression) -> Bool {
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return regex.firstMatch(in: value, range: range) != nil
    }

    static func isValidGitURL(_ value: String) -> Bool {
        if value.hasPrefix("https://") || value.hasPrefix("ssh://") {
            return value.contains("/")
        }
        if value.hasPrefix("git@") {
            return value.contains(":") && value.contains("/")
        }
        return false
    }
}
