import Foundation
import Testing
@testable import BosCore

@Suite
struct ASCBackendIntegrationTests {
    @Test func curatedEnvironmentMapsBosSigningEnvToDeterministicAscEnv() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let backend = ASCBackend()
        let curated = try backend.curatedEnvironment(
            projectRoot: root,
            environment: validEnvironment(),
            appStoreAppId: "1234567890"
        )

        #expect(curated["ASC_PRIVATE_KEY_B64"] == "c3VwZXItc2VjcmV0")
        #expect(curated["ASC_BYPASS_KEYCHAIN"] == "1")
        #expect(curated["ASC_STRICT_AUTH"] == "1")
        #expect(curated["ASC_APP_ID"] == "1234567890")
        #expect(curated["ASC_CONFIG_PATH"]?.contains(".bos/runtime/asc/no-config-") == true)
    }

    @Test func runInvokesAscWithEnvOnlyBridgeAndNoConfigFile() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let ascPath = try writeFakeASC(root: root)
        let backend = ASCBackend(runner: ProcessASCCommandRunner())
        var environment = validEnvironment()
        environment["PATH"] = "\(ascPath.deletingLastPathComponent().path(percentEncoded: false)):\(ProcessInfo.processInfo.environment["PATH"] ?? "")"

        let result = try backend.run(
            arguments: ["whoami"],
            projectRoot: root,
            environment: environment,
            appStoreAppId: "1234567890"
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("\"appId\":\"1234567890\""))
        #expect(result.stdout.contains("\"bypass\":\"1\""))
        #expect(result.stdout.contains("\"strict\":\"1\""))
        #expect(result.stdout.contains("\"privateKey\":\"c3VwZXItc2VjcmV0\""))
        #expect(result.stdout.contains("\"configExists\":\"0\""))
    }

    @Test func sanitizeSecretsRedactsAscPrivateKeyAndMatchPassword() {
        let text = "private=c3VwZXItc2VjcmV0 password=match-secret"
        let sanitized = ASCBackend.sanitizeSecrets(
            text,
            environment: [
                "ASC_KEY_P8_BASE64": "c3VwZXItc2VjcmV0",
                "ASC_PRIVATE_KEY_B64": "c3VwZXItc2VjcmV0",
                "MATCH_PASSWORD": "match-secret"
            ]
        )

        #expect(!sanitized.contains("c3VwZXItc2VjcmV0"))
        #expect(!sanitized.contains("match-secret"))
        #expect(sanitized.contains("<redacted:ASC_PRIVATE_KEY_B64>") || sanitized.contains("<redacted:ASC_KEY_P8_BASE64>"))
        #expect(sanitized.contains("<redacted:MATCH_PASSWORD>"))
    }
}

private extension ASCBackendIntegrationTests {
    func validEnvironment() -> [String: String] {
        [
            "ASC_ISSUER_ID": "123E4567-E89B-12D3-A456-426614174000",
            "ASC_KEY_ID": "AB12CD34EF",
            "ASC_KEY_P8_BASE64": "c3VwZXItc2VjcmV0",
            "MATCH_PASSWORD": "match-secret"
        ]
    }

    func makeTempDir() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("bos-asc-backend-\(ProcessInfo.processInfo.globallyUniqueString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    func writeFakeASC(root: URL) throws -> URL {
        let binDir = root.appending(path: "bin")
        let path = binDir.appending(path: "asc")
        try FileManager.default.createDirectory(at: binDir, withIntermediateDirectories: true)
        try Data(
            """
            #!/bin/sh
            if [ "$1" = "--version" ]; then
              echo "0.18.0"
              exit 0
            fi
            if [ "${ASC_BYPASS_KEYCHAIN}" != "1" ]; then
              echo "missing ASC_BYPASS_KEYCHAIN" >&2
              exit 64
            fi
            if [ "${ASC_STRICT_AUTH}" != "1" ]; then
              echo "missing ASC_STRICT_AUTH" >&2
              exit 65
            fi
            if [ -z "${ASC_PRIVATE_KEY_B64}" ]; then
              echo "missing ASC_PRIVATE_KEY_B64" >&2
              exit 66
            fi
            if [ -e "${ASC_CONFIG_PATH}" ]; then
              echo "ASC_CONFIG_PATH must not exist" >&2
              exit 67
            fi
            printf '{"appId":"%s","bypass":"%s","strict":"%s","privateKey":"%s","configExists":"0"}\n' "${ASC_APP_ID}" "${ASC_BYPASS_KEYCHAIN}" "${ASC_STRICT_AUTH}" "${ASC_PRIVATE_KEY_B64}"
            """.utf8
        ).write(to: path, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int(0o755))],
            ofItemAtPath: path.path(percentEncoded: false)
        )
        return path
    }
}
