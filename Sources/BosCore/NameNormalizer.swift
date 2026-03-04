import Foundation

enum NameNormalizer {
    static func pascalCase(_ raw: String, fallback: String) -> String {
        let separators = CharacterSet.alphanumerics.inverted
        let tokens = raw
            .components(separatedBy: separators)
            .filter { !$0.isEmpty }
            .map(pascalToken)
        if tokens.isEmpty {
            return fallback
        }
        return tokens.joined()
    }
}

extension NameNormalizer {
    private static func pascalToken(_ token: String) -> String {
        guard !token.isEmpty else { return token }

        let normalized: String
        if token == token.lowercased() || token == token.uppercased() {
            normalized = token.lowercased()
        } else {
            normalized = token
        }

        let first = normalized.prefix(1).uppercased()
        let rest = normalized.dropFirst()
        return first + String(rest)
    }
}
