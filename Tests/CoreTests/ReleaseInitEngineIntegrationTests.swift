import Foundation
import Testing
@testable import BosCore

@Suite
struct ReleaseInitEngineIntegrationTests {
    private let engine = ReleaseInitEngine()

    @Test func releaseInitGeneratesFastlaneFilesAndParsesDefaultLanes() throws {
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

        #expect(result.lanes == ["certs", "build", "beta", "release", "release_metadata"])
        #expect(result.generatedFiles.count == 4)
        #expect(result.artifacts.count == 2)

        let fastfile = root.appending(path: "fastlane/Fastfile")
        let appfile = root.appending(path: "fastlane/Appfile")
        let matchfile = root.appending(path: "fastlane/Matchfile")
        let metadata = root.appending(path: "fastlane/metadata/en-US/release_notes.txt")

        #expect(FileManager.default.fileExists(atPath: fastfile.path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: appfile.path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: matchfile.path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: metadata.path(percentEncoded: false)))

        let appfileContent = try String(contentsOf: appfile, encoding: .utf8)
        #expect(appfileContent.contains("app_identifier(\"com.axiomorient.daycraft\")"))
        #expect(appfileContent.contains("team_id(\"A1B2C3D4E5\")"))

        let fastfileContent = try String(contentsOf: fastfile, encoding: .utf8)
        #expect(fastfileContent.contains("private_lane :asc_api_key do"))
        #expect(fastfileContent.contains("lane :certs do"))
        #expect(fastfileContent.contains("sync_code_signing(type: \"appstore\", readonly: false, api_key: asc_api_key)"))
        #expect(fastfileContent.contains("lane :build do"))
        #expect(fastfileContent.contains("lane :beta do"))
        #expect(fastfileContent.contains("api_key = asc_api_key"))
        #expect(fastfileContent.contains("lane :release do"))
        #expect(fastfileContent.contains("lane :release_metadata do"))

        let logPath = try #require(result.artifacts.first(where: { $0.hasSuffix(".log") }))
        let log = try String(contentsOfFile: logPath, encoding: .utf8)
        #expect(log.contains("requiredEnvChecked=ASC_ISSUER_ID,ASC_KEY_ID,ASC_KEY_P8_BASE64,MATCH_GIT_URL,MATCH_PASSWORD"))
        #expect(!log.contains("super-secret"))
    }

    @Test func releaseInitFailsWhenRequiredEnvironmentIsMissing() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        var env = requiredEnvironment()
        env["MATCH_PASSWORD"] = nil
        env["ASC_KEY_ID"] = ""

        do {
            _ = try engine.releaseInit(
                request: ReleaseInitRequest(
                    projectRoot: root,
                    blueprint: try makeBlueprint(),
                    profile: try makeProfile(name: "daycraft"),
                    environment: env
                )
            )
            Issue.record("expected ReleaseInitEngineError.missingRequiredEnvironment to be thrown")
        } catch ReleaseInitEngineError.missingRequiredEnvironment(let keys) {
            #expect(keys == ["ASC_KEY_ID", "MATCH_PASSWORD"])
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test func releaseInitFailsWhenRequiredEnvironmentFormatIsInvalid() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        var env = requiredEnvironment()
        env["ASC_ISSUER_ID"] = "issuer-id"
        env["ASC_KEY_ID"] = "bad"
        env["ASC_KEY_P8_BASE64"] = "not-base64"
        env["MATCH_GIT_URL"] = "ftp://example.com/repo"

        do {
            _ = try engine.releaseInit(
                request: ReleaseInitRequest(
                    projectRoot: root,
                    blueprint: try makeBlueprint(),
                    profile: try makeProfile(name: "daycraft"),
                    environment: env
                )
            )
            Issue.record("expected ReleaseInitEngineError.invalidEnvironmentFormat to be thrown")
        } catch ReleaseInitEngineError.invalidEnvironmentFormat(let details) {
            #expect(details.contains("ASC_ISSUER_ID(UUID format)"))
            #expect(details.contains("ASC_KEY_ID(10 uppercase letters/digits)"))
            #expect(details.contains("ASC_KEY_P8_BASE64(valid base64-encoded key content)"))
            #expect(details.contains("MATCH_GIT_URL(git@host:path(.git) or https://... or ssh://...)"))
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test func releaseInitUpdatesBootstrapStateSummaryOnSuccess() throws {
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
        #expect(state.contains("releaseSummary:"))
        #expect(state.contains("status: \"success\""))
        #expect(state.contains("message: \"release-init completed\""))
    }

    @Test func releaseInitUpdatesBootstrapStateSummaryOnMissingEnvironmentFailure() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeBootstrapStateFixture(root: root)

        var env = requiredEnvironment()
        env["MATCH_PASSWORD"] = nil

        do {
            _ = try engine.releaseInit(
                request: ReleaseInitRequest(
                    projectRoot: root,
                    blueprint: try makeBlueprint(),
                    profile: try makeProfile(name: "daycraft"),
                    environment: env
                )
            )
            Issue.record("expected ReleaseInitEngineError.missingRequiredEnvironment to be thrown")
        } catch ReleaseInitEngineError.missingRequiredEnvironment(let keys) {
            #expect(keys == ["MATCH_PASSWORD"])
        } catch {
            Issue.record("unexpected error: \(error)")
        }

        let statePath = root.appending(path: ".bos/state/bos.state.yaml")
        let state = try String(contentsOf: statePath, encoding: .utf8)
        #expect(state.contains("releaseSummary:"))
        #expect(state.contains("status: \"failed\""))
        #expect(state.contains("missing required environment: MATCH_PASSWORD"))
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
