import Foundation
import Testing
@testable import BosCore

@Suite
struct ASCAppStoreAppResolverTests {
    @Test func returnsProfileAppStoreAppIdWithoutLookup() throws {
        let runner = StubASCCommandRunner(result: .init(exitCode: 0))
        let resolver = ASCAppStoreAppResolver(
            backend: ASCBackend(runner: runner)
        )

        let resolution = try resolver.resolve(
            profile: try makeProfile(appStoreAppId: "1234567890"),
            projectRoot: makeTempDir(),
            environment: validEnvironment()
        )

        #expect(resolution.source == .profile)
        #expect(resolution.appStoreAppId == "1234567890")
        #expect(runner.commands.isEmpty)
    }

    @Test func resolvesAppStoreAppIdByBundleIdentifierAndBackfillsProfile() throws {
        let payload = """
        {
          "data": [
            {
              "id": "1234567890",
              "attributes": {
                "bundleId": "com.axiomorient.daycraft"
              }
            }
          ]
        }
        """
        let runner = StubASCCommandRunner(result: .init(exitCode: 0, stdout: payload))
        let resolver = ASCAppStoreAppResolver(
            backend: ASCBackend(runner: runner)
        )

        let resolution = try resolver.resolve(
            profile: try makeProfile(),
            projectRoot: makeTempDir(),
            environment: validEnvironment()
        )

        #expect(resolution.source == .lookup)
        #expect(resolution.appStoreAppId == "1234567890")
        #expect(resolution.updatedProfile.release.appStoreAppId == "1234567890")
        #expect(runner.commands == [["asc", "apps", "list", "--bundle-id", "com.axiomorient.daycraft", "--output", "json"]])

        let encoded = try JSONEncoder().encode(resolution.updatedProfile)
        let decoded = try JSONDecoder().decode(Profile.self, from: encoded)
        #expect(decoded.release.appStoreAppId == "1234567890")
    }

    @Test func failsWhenLookupFindsNoApps() throws {
        let runner = StubASCCommandRunner(result: .init(exitCode: 0, stdout: "{\"data\":[]}"))
        let resolver = ASCAppStoreAppResolver(
            backend: ASCBackend(runner: runner)
        )

        #expect(throws: ASCAppStoreAppResolverError.appNotFound(bundleIdentifier: "com.axiomorient.daycraft")) {
            try resolver.resolve(
                profile: try makeProfile(),
                projectRoot: makeTempDir(),
                environment: validEnvironment()
            )
        }
    }

    @Test func failsWhenLookupIsAmbiguous() throws {
        let payload = """
        {
          "data": [
            {
              "id": "1234567890",
              "attributes": {
                "bundleId": "com.axiomorient.daycraft"
              }
            },
            {
              "id": "9999999999",
              "attributes": {
                "bundleId": "com.axiomorient.daycraft"
              }
            }
          ]
        }
        """
        let runner = StubASCCommandRunner(result: .init(exitCode: 0, stdout: payload))
        let resolver = ASCAppStoreAppResolver(
            backend: ASCBackend(runner: runner)
        )

        #expect(
            throws: ASCAppStoreAppResolverError.ambiguous(
                bundleIdentifier: "com.axiomorient.daycraft",
                appStoreAppIds: ["1234567890", "9999999999"]
            )
        ) {
            try resolver.resolve(
                profile: try makeProfile(),
                projectRoot: makeTempDir(),
                environment: validEnvironment()
            )
        }
    }
}

private extension ASCAppStoreAppResolverTests {
    final class StubASCCommandRunner: ASCCommandRunning, @unchecked Sendable {
        private(set) var commands: [[String]] = []
        private let result: ASCCommandResult

        init(result: ASCCommandResult) {
            self.result = result
        }

        func run(command: [String], in workingDirectory: URL, environment: [String : String]) throws -> ASCCommandResult {
            commands.append(command)
            return result
        }
    }

    func makeTempDir() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("bos-asc-resolver-\(ProcessInfo.processInfo.globallyUniqueString)", isDirectory: true)
    }

    func validEnvironment() -> [String: String] {
        [
            "ASC_ISSUER_ID": "123E4567-E89B-12D3-A456-426614174000",
            "ASC_KEY_ID": "AB12CD34EF",
            "ASC_KEY_P8_BASE64": "c3VwZXItc2VjcmV0"
        ]
    }

    func makeProfile(appStoreAppId: String? = nil) throws -> Profile {
        try Profile(
            schemaVersion: 1,
            name: "daycraft",
            defaults: .init(
                deploymentTarget: "18.0",
                appTargets: .init(controlsExtension: false, uiTests: true)
            ),
            identity: .init(
                companyName: "Axiom Orient",
                appName: "Daycraft",
                appIdentifier: "com.axiomorient.daycraft",
                appleTeamId: "A1B2C3D4E5"
            ),
            release: .init(
                primaryLanguage: "en-US",
                sku: "axiom-orient.daycraft.04805b02",
                appStoreAppId: appStoreAppId,
                matchGitURL: "git@github.com:org/certs.git"
            ),
            featurePattern: .init(sourcesInterface: true, designFolder: false),
            rules: try .init(
                testingStyle: "swift-testing",
                forbidPatterns: ["@unchecked Sendable", "Date()", "UUID()"]
            )
        )
    }
}
