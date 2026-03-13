import Foundation
import BosCore
import Yams

func defaultProfileTemplate() -> String {
    """
    # bos profile (safe to commit)
    # Fill identity and release values before app-register or release commands.
    schemaVersion: 1
    name: default
    defaults:
      deploymentTarget: "18.0"
      appTargets:
        controlsExtension: false
        uiTests: true
    identity:
      # Example: Example Inc.
      companyName:
      # Example: Example App
      appName:
      # Example: com.example.app
      appIdentifier:
      # Example: A1B2C3D4E5
      appleTeamId:
    release:
      primaryLanguage: "en-US"
      # Example: example.app.20260312
      sku:
      # Optional stable ASC app ID. Leave empty until discovered or created.
      appStoreAppId:
      # Example: git@github.com:your-org/certificates.git
      matchGitURL:
    featurePattern:
      sourcesInterface: true
      designFolder: false
    rules:
      testingStyle: swift-testing
      forbidPatterns:
        - "@unchecked Sendable"
        - "Date()"
        - "UUID()"
    """
}

enum SigningEnvironmentFileError: Error {
    case unreadable(path: String, details: String)
    case invalidLine(line: Int, details: String)
}

func defaultSigningEnvironmentPath(projectRoot: URL) -> URL {
    projectRoot.appending(path: ".bos/config/signing.env")
}

func hardenSigningEnvironmentFilePermissions(at path: URL) {
    try? FileManager.default.setAttributes(
        [.posixPermissions: NSNumber(value: Int(0o600))],
        ofItemAtPath: path.path(percentEncoded: false)
    )
}

func signingEnvironmentLoadErrorMessage(_ error: Error, projectRoot: URL) -> String {
    let path = defaultSigningEnvironmentPath(projectRoot: projectRoot).path(percentEncoded: false)
    if let signingError = error as? SigningEnvironmentFileError {
        switch signingError {
        case .unreadable(let sourcePath, let details):
            return "failed to read signing env at \(sourcePath): \(details)"
        case .invalidLine(let line, let details):
            return "invalid signing env in \(path): line \(line) (\(details))"
        }
    }
    return "failed to load signing env at \(path): \(error.localizedDescription)"
}

func signingEnvironmentTemplate() -> String {
    """
    # bos signing environment (do not commit this file)
    # Fill all values before release-init, release-check, or release-run.
    # ASC_ISSUER_ID: App Store Connect API issuer ID
    # ASC_KEY_ID: App Store Connect API key ID
    # ASC_KEY_P8_BASE64: base64 of AuthKey_<KEY_ID>.p8
    # MATCH_PASSWORD: password used by fastlane match
    # MATCH_GIT_URL belongs in .bos/config/profile.yaml release.matchGitURL.
    ASC_ISSUER_ID=
    ASC_KEY_ID=
    ASC_KEY_P8_BASE64=
    MATCH_PASSWORD=
    """
}

func ensureSigningEnvironmentTemplate(projectRoot: URL) throws -> (path: URL, created: Bool) {
    let path = defaultSigningEnvironmentPath(projectRoot: projectRoot)
    let fm = FileManager.default
    let filePath = path.path(percentEncoded: false)
    if fm.fileExists(atPath: filePath) {
        hardenSigningEnvironmentFilePermissions(at: path)
        return (path, false)
    }
    try writeTextFile(signingEnvironmentTemplate(), to: path)
    hardenSigningEnvironmentFilePermissions(at: path)
    return (path, true)
}

func parseEnvironmentFile(at path: URL) throws -> [String: String] {
    let text: String
    do {
        text = try readTextFile(path)
    } catch {
        throw SigningEnvironmentFileError.unreadable(
            path: path.path(percentEncoded: false),
            details: error.localizedDescription
        )
    }
    var environment: [String: String] = [:]

    let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    for (index, rawLine) in lines.enumerated() {
        var line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if line.isEmpty || line.hasPrefix("#") {
            continue
        }

        if line.hasPrefix("export ") {
            line = String(line.dropFirst("export ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let equals = line.firstIndex(of: "=") else {
            throw SigningEnvironmentFileError.invalidLine(
                line: index + 1,
                details: "expected KEY=VALUE"
            )
        }

        let key = line[..<equals].trimmingCharacters(in: .whitespacesAndNewlines)
        var value = String(line[line.index(after: equals)...]).trimmingCharacters(in: .whitespacesAndNewlines)

        if key.isEmpty {
            throw SigningEnvironmentFileError.invalidLine(
                line: index + 1,
                details: "empty key"
            )
        }

        if (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) {
            value = String(value.dropFirst().dropLast())
        }

        environment[key] = value
    }

    return environment
}

func mergeProcessEnvironment(
    processEnvironment: [String: String],
    fileEnvironment: [String: String]
) -> [String: String] {
    var merged = fileEnvironment
    for (key, value) in processEnvironment {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            continue
        }
        merged[key] = value
    }
    return merged
}

func resolveSigningEnvironment(
    projectRoot: URL,
    profile: Profile? = nil,
    processEnvironment: [String: String]
) throws -> (environment: [String: String], note: String?) {
    let template = try ensureSigningEnvironmentTemplate(projectRoot: projectRoot)
    let fileEnvironment = try parseEnvironmentFile(at: template.path)
    let merged = mergeProcessEnvironment(processEnvironment: processEnvironment, fileEnvironment: fileEnvironment)
    let effective = profile.map { ReleaseEnvironment.effectiveEnvironment(profile: $0, environment: merged) } ?? merged

    if template.created {
        return (effective, "Created signing env template at \(template.path.path(percentEncoded: false))")
    }
    return (effective, nil)
}

private struct ToolchainLockSchemaProbe: Decodable {
    let schemaVersion: Int
}

func decodeToolchainLock(at path: URL) throws -> ToolchainLock {
    let text = try readTextFile(path)
    let decoder = YAMLDecoder()

    if let probe = try? decoder.decode(ToolchainLockSchemaProbe.self, from: text),
       probe.schemaVersion == 1 {
        throw NSError(
            domain: "BosCLI.Decode",
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey:
                    "unsupported legacy toolchain lock schemaVersion 1 at \(path.path(percentEncoded: false)); delete it and rerun `bos doctor` to regenerate schemaVersion 2"
            ]
        )
    }

    do {
        return try decoder.decode(ToolchainLock.self, from: text)
    } catch {
        throw NSError(
            domain: "BosCLI.Decode",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "failed to decode toolchain lock at \(path.path(percentEncoded: false)): \(error)"]
        )
    }
}

func readTextFile(_ path: URL) throws -> String {
    try String(contentsOf: path, encoding: .utf8)
}

func writeTextFile(_ text: String, to path: URL) throws {
    let fm = FileManager.default
    try fm.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(text.utf8).write(to: path, options: .atomic)
}

func decodeYAMLOrJSON<T: Decodable>(_ type: T.Type, at path: URL) throws -> T {
    let text = try readTextFile(path)
    do {
        return try YAMLDecoder().decode(T.self, from: text)
    } catch {
        throw NSError(
            domain: "BosCLI.Decode",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "failed to decode \(path.path(percentEncoded: false)): \(error)"]
        )
    }
}

func encodeYAML<T: Encodable>(_ value: T) throws -> String {
    try YAMLEncoder().encode(value)
}
