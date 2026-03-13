import Foundation
import Testing
@testable import BosCore

@Suite
struct ASCAppStoreReadinessCheckerTests {
    @Test func parsesJSONStatusOutputAndReturnsSummary() throws {
        let runner = StubRunner(
            result: .init(
                exitCode: 0,
                stdout: "{\"app\":{\"id\":\"1234567890\"}}"
            )
        )
        let checker = ASCAppStoreReadinessChecker(
            backend: ASCBackend(runner: runner),
            resolver: StubResolver(appStoreAppId: "1234567890")
        )

        let result = try checker.check(
            projectRoot: makeTempDir(),
            profile: try makeProfile(),
            environment: validEnvironment()
        )

        #expect(result.summary.contains("1234567890"))
        #expect(runner.commands == [["asc", "status", "--output", "json"]])
    }

    @Test func failsWhenStatusOutputIsNotJSON() throws {
        let runner = StubRunner(result: .init(exitCode: 0, stdout: "not-json"))
        let checker = ASCAppStoreReadinessChecker(
            backend: ASCBackend(runner: runner),
            resolver: StubResolver(appStoreAppId: "1234567890")
        )

        #expect(throws: NSError.self) {
            try checker.check(
                projectRoot: makeTempDir(),
                profile: try makeProfile(),
                environment: validEnvironment()
            )
        }
    }
}

private extension ASCAppStoreReadinessCheckerTests {
    final class StubRunner: ASCCommandRunning, @unchecked Sendable {
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

    struct StubResolver: AppStoreAppIDResolving {
        let appStoreAppId: String

        func resolve(
            profile: Profile,
            projectRoot: URL,
            environment: [String : String],
            bundleIdentifierOverride: String?
        ) throws -> ASCAppStoreAppResolution {
            ASCAppStoreAppResolution(
                appStoreAppId: appStoreAppId,
                source: .profile,
                updatedProfile: profile
            )
        }
    }

    func makeTempDir() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("bos-asc-readiness-\(ProcessInfo.processInfo.globallyUniqueString)", isDirectory: true)
    }

    func validEnvironment() -> [String: String] {
        [
            "ASC_ISSUER_ID": "123E4567-E89B-12D3-A456-426614174000",
            "ASC_KEY_ID": "AB12CD34EF",
            "ASC_KEY_P8_BASE64": "c3VwZXItc2VjcmV0"
        ]
    }

    func makeProfile() throws -> Profile {
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
                appStoreAppId: "1234567890",
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
