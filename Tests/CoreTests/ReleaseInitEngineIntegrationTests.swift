import Foundation
import XCTest
@testable import BosCore

final class ReleaseInitEngineIntegrationTests: XCTestCase {
    private let engine = ReleaseInitEngine()

    func testReleaseInitGeneratesFastlaneFilesAndParsesDefaultLanes() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let result = try engine.releaseInit(
            request: ReleaseInitRequest(
                projectRoot: root,
                blueprint: try makeBlueprint(),
                profile: try makeProfile(name: "daycraft"),
                environment: requiredEnvironment()
            )
        )

        XCTAssertEqual(result.lanes, ["certs", "build", "beta", "release", "release_metadata"])
        XCTAssertEqual(result.generatedFiles.count, 4)
        XCTAssertEqual(result.artifacts.count, 2)

        let fastfile = root.appending(path: "fastlane/Fastfile")
        let appfile = root.appending(path: "fastlane/Appfile")
        let matchfile = root.appending(path: "fastlane/Matchfile")
        let metadata = root.appending(path: "fastlane/metadata/en-US/release_notes.txt")

        XCTAssertTrue(FileManager.default.fileExists(atPath: fastfile.path(percentEncoded: false)))
        XCTAssertTrue(FileManager.default.fileExists(atPath: appfile.path(percentEncoded: false)))
        XCTAssertTrue(FileManager.default.fileExists(atPath: matchfile.path(percentEncoded: false)))
        XCTAssertTrue(FileManager.default.fileExists(atPath: metadata.path(percentEncoded: false)))

        let appfileContent = try String(contentsOf: appfile, encoding: .utf8)
        XCTAssertTrue(appfileContent.contains("app_identifier(\"com.axiomorient.daycraft\")"))
        XCTAssertTrue(appfileContent.contains("team_id(\"A1B2C3D4E5\")"))

        let fastfileContent = try String(contentsOf: fastfile, encoding: .utf8)
        XCTAssertTrue(fastfileContent.contains("private_lane :asc_api_key do"))
        XCTAssertTrue(fastfileContent.contains("lane :certs do"))
        XCTAssertTrue(fastfileContent.contains("sync_code_signing(type: \"appstore\", readonly: false, api_key: asc_api_key)"))
        XCTAssertTrue(fastfileContent.contains("lane :build do"))
        XCTAssertTrue(fastfileContent.contains("lane :beta do"))
        XCTAssertTrue(fastfileContent.contains("api_key = asc_api_key"))
        XCTAssertTrue(fastfileContent.contains("lane :release do"))
        XCTAssertTrue(fastfileContent.contains("lane :release_metadata do"))

        let logPath = try XCTUnwrap(result.artifacts.first(where: { $0.hasSuffix(".log") }))
        let log = try String(contentsOfFile: logPath, encoding: .utf8)
        XCTAssertTrue(log.contains("requiredEnvChecked=ASC_ISSUER_ID,ASC_KEY_ID,ASC_KEY_P8_BASE64,MATCH_GIT_URL,MATCH_PASSWORD"))
        XCTAssertFalse(log.contains("super-secret"))
    }

    func testReleaseInitFailsWhenRequiredEnvironmentIsMissing() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        var env = requiredEnvironment()
        env["MATCH_PASSWORD"] = nil
        env["ASC_KEY_ID"] = ""

        XCTAssertThrowsError(
            try engine.releaseInit(
                request: ReleaseInitRequest(
                    projectRoot: root,
                    blueprint: try makeBlueprint(),
                    profile: try makeProfile(name: "daycraft"),
                    environment: env
                )
            )
        ) { error in
            guard case ReleaseInitEngineError.missingRequiredEnvironment(let keys) = error else {
                return XCTFail("unexpected error: \(error)")
            }
            XCTAssertEqual(keys, ["ASC_KEY_ID", "MATCH_PASSWORD"])
        }
    }

    func testReleaseInitFailsWhenRequiredEnvironmentFormatIsInvalid() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        var env = requiredEnvironment()
        env["ASC_ISSUER_ID"] = "issuer-id"
        env["ASC_KEY_ID"] = "bad"
        env["ASC_KEY_P8_BASE64"] = "not-base64"
        env["MATCH_GIT_URL"] = "ftp://example.com/repo"

        XCTAssertThrowsError(
            try engine.releaseInit(
                request: ReleaseInitRequest(
                    projectRoot: root,
                    blueprint: try makeBlueprint(),
                    profile: try makeProfile(name: "daycraft"),
                    environment: env
                )
            )
        ) { error in
            guard case ReleaseInitEngineError.invalidEnvironmentFormat(let details) = error else {
                return XCTFail("unexpected error: \(error)")
            }
            XCTAssertTrue(details.contains("ASC_ISSUER_ID(UUID format)"))
            XCTAssertTrue(details.contains("ASC_KEY_ID(10 uppercase letters/digits)"))
            XCTAssertTrue(details.contains("ASC_KEY_P8_BASE64(valid base64-encoded key content)"))
            XCTAssertTrue(details.contains("MATCH_GIT_URL(git@host:path(.git) or https://... or ssh://...)"))
        }
    }

    func testReleaseInitUpdatesBootstrapStateSummaryOnSuccess() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeBootstrapStateFixture(root: root)

        _ = try engine.releaseInit(
            request: ReleaseInitRequest(
                projectRoot: root,
                blueprint: try makeBlueprint(),
                profile: try makeProfile(name: "daycraft"),
                environment: requiredEnvironment()
            )
        )

        let statePath = root.appending(path: ".bos/state/bos.state.yaml")
        let state = try String(contentsOf: statePath, encoding: .utf8)
        XCTAssertTrue(state.contains("releaseSummary:"))
        XCTAssertTrue(state.contains("status: \"success\""))
        XCTAssertTrue(state.contains("message: \"release-init completed\""))
    }

    func testReleaseInitUpdatesBootstrapStateSummaryOnMissingEnvironmentFailure() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeBootstrapStateFixture(root: root)

        var env = requiredEnvironment()
        env["MATCH_PASSWORD"] = nil

        XCTAssertThrowsError(
            try engine.releaseInit(
                request: ReleaseInitRequest(
                    projectRoot: root,
                    blueprint: try makeBlueprint(),
                    profile: try makeProfile(name: "daycraft"),
                    environment: env
                )
            )
        ) { error in
            guard case ReleaseInitEngineError.missingRequiredEnvironment(let keys) = error else {
                return XCTFail("unexpected error: \(error)")
            }
            XCTAssertEqual(keys, ["MATCH_PASSWORD"])
        }

        let statePath = root.appending(path: ".bos/state/bos.state.yaml")
        let state = try String(contentsOf: statePath, encoding: .utf8)
        XCTAssertTrue(state.contains("releaseSummary:"))
        XCTAssertTrue(state.contains("status: \"failed\""))
        XCTAssertTrue(state.contains("missing required environment: MATCH_PASSWORD"))
    }
}

private extension ReleaseInitEngineIntegrationTests {
    func makeTempDir() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("bos-release-init-\(ProcessInfo.processInfo.globallyUniqueString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    func requiredEnvironment() -> [String: String] {
        [
            "ASC_ISSUER_ID": "123E4567-E89B-12D3-A456-426614174000",
            "ASC_KEY_ID": "AB12CD34EF",
            "ASC_KEY_P8_BASE64": "c3VwZXItc2VjcmV0",
            "MATCH_GIT_URL": "git@github.com:org/certs.git",
            "MATCH_PASSWORD": "match-secret"
        ]
    }

    func makeBlueprint() throws -> BlueprintV1 {
        let project = try BlueprintV1.Project(
            name: "Daycraft",
            bundleIdPrefix: "com.axiomorient",
            deploymentTarget: "18.0"
        )
        let requirements = try BlueprintV1.Requirements(
            reqIds: ["REQ-001"],
            screens: ["SCR_TODAY_HOME"]
        )
        let app = try BlueprintV1.AppModule(name: "Daycraft")
        let modules = try BlueprintV1.Modules(
            app: app,
            features: ["Root", "Today"],
            domains: ["User"],
            services: ["Auth"],
            shared: ["Core", "DesignSystem"]
        )
        let wiring = try BlueprintV1.Wiring(rootFeature: "Root")
        let fastlane = try BlueprintV1.Fastlane(
            appIdentifier: "com.axiomorient.daycraft",
            appleTeamId: "A1B2C3D4E5"
        )
        let release = BlueprintV1.Release(fastlane: fastlane)
        return try BlueprintV1(
            schemaVersion: 1,
            project: project,
            requirements: requirements,
            modules: modules,
            wiring: wiring,
            release: release
        )
    }

    func makeProfile(name: String) throws -> ProfileV1 {
        let appTargets = ProfileV1.AppTargets(controlsExtension: true, uiTests: true)
        let defaults = ProfileV1.Defaults(deploymentTarget: "18.0", appTargets: appTargets)
        let pattern = ProfileV1.FeaturePattern(sourcesInterface: true, designFolder: true)
        let rules = try ProfileV1.Rules(
            testingStyle: "swift-testing",
            forbidPatterns: ["@unchecked Sendable", "Date()", "UUID()"]
        )
        return try ProfileV1(
            schemaVersion: 1,
            name: name,
            defaults: defaults,
            featurePattern: pattern,
            rules: rules
        )
    }

    func writeBootstrapStateFixture(root: URL) throws {
        let statePath = root.appending(path: ".bos/state/bos.state.yaml")
        try FileManager.default.createDirectory(at: statePath.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(
            """
            appliedAt: "2026-03-04T00:00:00Z"
            blueprintHash: "x"
            profileHash: "y"
            managedFiles:
              - /tmp/mock/AppComposition.swift
            verifySummary:
              status: "not-run"
              message: "verify not executed in apply step"
            releaseSummary:
              status: "not-run"
              message: "release-init not executed in apply step"
            """.utf8
        ).write(to: statePath, options: .atomic)
    }
}
