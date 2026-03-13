import Foundation

enum SecretRedactionSupport {
    static func redact(_ text: String, environment: [String: String], keys: [String]) -> String {
        let replacements = orderedReplacements(environment: environment, keys: keys)
        guard !replacements.isEmpty else { return text }

        return replacements.reduce(text) { partial, replacement in
            partial.replacingOccurrences(of: replacement.secret, with: replacement.placeholder)
        }
    }

    private static func orderedReplacements(
        environment: [String: String],
        keys: [String]
    ) -> [(secret: String, placeholder: String)] {
        var seenSecrets = Set<String>()
        var replacements: [(secret: String, placeholder: String)] = []

        for key in keys {
            guard let value = environment[key], !value.isEmpty else { continue }
            guard seenSecrets.insert(value).inserted else { continue }
            replacements.append((secret: value, placeholder: "<redacted:\(key)>"))
        }

        return replacements
    }
}
