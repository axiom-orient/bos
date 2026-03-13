import Foundation
import os
import Testing
@testable import BosCore

@Suite
struct ReleaseCheckEngineIntegrationTests {
    @Test func connectivityModeRunsMatchProbeAndAuthOnly() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeFastlaneScaffold(root: root)

        let runner = RecordingReleaseCheckRunner(
            scriptedResults: [
                ReleaseCheckCommandResult(exitCode: 0, stdout: "ok")
            ]
        )
        let engine = ReleaseCheckEngine(
            runner: runner,
            authChecker: StubAppStoreConnectChecker(result: .success(.init(summary: "auth ok")))
        )

        let result = try engine.releaseCheck(
            request: ReleaseCheckRequest(
                projectRoot: root,
                profile: try makeProfile(name: "daycraft"),
                environment: requiredEnvironment(),
                mode: .connectivity
            )
        )

        #expect(result.mode == .connectivity)
        #expect(result.failureCode == nil)
        #expect(runner.commands.count == 1)
        #expect(runner.commands[0] == ["git", "ls-remote", "git@github.com:org/certs.git", "HEAD"])
    }

    @Test func readonlyCertsRunsFastlaneReadonlyLaneAndUpdatesStateSummary() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeFastlaneScaffold(root: root)
        try writeBootstrapStateFixture(root: root)

        let runner = RecordingReleaseCheckRunner(
            scriptedResults: [
                ReleaseCheckCommandResult(exitCode: 0, stdout: "git ok"),
                ReleaseCheckCommandResult(exitCode: 0, stdout: "certs readonly ok")
            ]
        )
        let engine = ReleaseCheckEngine(
            runner: runner,
            authChecker: StubAppStoreConnectChecker(result: .success(.init(summary: "auth ok")))
        )

        let result = try engine.releaseCheck(
            request: ReleaseCheckRequest(
                projectRoot: root,
                profile: try makeProfile(name: "daycraft"),
                environment: requiredEnvironment(),
                mode: .readonlyCerts
            )
        )

        #expect(result.summary == "Release check passed (readonly-certs)")
        #expect(runner.commands == [
            ["git", "ls-remote", "git@github.com:org/certs.git", "HEAD"],
            ["fastlane", "ios", "certs_readonly"]
        ])

        let state = try String(contentsOf: root.appending(path: ".bos/state/bos.state.yaml"), encoding: .utf8)
        #expect(state.contains("releaseCheckSummary:"))
        #expect(state.contains("message: \"Release check passed (readonly-certs)\""))
    }

    @Test func syncCertsRunsWritableLane() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeFastlaneScaffold(root: root)

        let runner = RecordingReleaseCheckRunner(
            scriptedResults: [
                ReleaseCheckCommandResult(exitCode: 0, stdout: "git ok"),
                ReleaseCheckCommandResult(exitCode: 0, stdout: "certs ok")
            ]
        )
        let engine = ReleaseCheckEngine(
            runner: runner,
            authChecker: StubAppStoreConnectChecker(result: .success(.init(summary: "auth ok")))
        )

        _ = try engine.releaseCheck(
            request: ReleaseCheckRequest(
                projectRoot: root,
                profile: try makeProfile(name: "daycraft"),
                environment: requiredEnvironment(),
                mode: .syncCerts
            )
        )

        #expect(runner.commands == [
            ["git", "ls-remote", "git@github.com:org/certs.git", "HEAD"],
            ["fastlane", "ios", "certs"]
        ])
    }

    @Test func readonlyCertsFailsEarlyWhenDiscoveredSigningTeamDiffersFromProfile() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeFastlaneScaffold(root: root)

        let runner = RecordingReleaseCheckRunner(
            scriptedResults: [
                ReleaseCheckCommandResult(exitCode: 0, stdout: "git ok"),
                ReleaseCheckCommandResult(
                    exitCode: 0,
                    stdout: """
                    | Development Team ID | sigh_com.axiomorient.daycraft_appstore_team-id | 7WR76382QB |
                    | Certificate Name    | Apple Distribution: Axient Inc. (7WR76382QB)   |
                    """
                )
            ]
        )
        let engine = ReleaseCheckEngine(
            runner: runner,
            authChecker: StubAppStoreConnectChecker(result: .success(.init(summary: "auth ok")))
        )

        do {
            _ = try engine.releaseCheck(
                request: ReleaseCheckRequest(
                    projectRoot: root,
                    profile: try makeProfile(
                        name: "daycraft",
                        identity: .init(appleTeamId: "8GT6LT258Y")
                    ),
                    environment: requiredEnvironment(),
                    mode: .readonlyCerts
                )
            )
            Issue.record("expected ReleaseCheckEngineError.failed")
        } catch ReleaseCheckEngineError.failed(let classification, let step, let summary, _, _) {
            #expect(classification == .certSync)
            #expect(step == .certSync)
            #expect(summary == "signing team mismatch: configured appleTeamId=8GT6LT258Y, discovered team=7WR76382QB")
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test func syncCertsFailsEarlyWhenCertificateUserIDDiffersFromProfile() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeFastlaneScaffold(root: root)

        let runner = RecordingReleaseCheckRunner(
            scriptedResults: [
                ReleaseCheckCommandResult(exitCode: 0, stdout: "git ok"),
                ReleaseCheckCommandResult(
                    exitCode: 0,
                    stdout: """
                    | User ID           | 7WR76382QB                                   |
                    | Organisation Unit | 7WR76382QB                                   |
                    """
                )
            ]
        )
        let engine = ReleaseCheckEngine(
            runner: runner,
            authChecker: StubAppStoreConnectChecker(result: .success(.init(summary: "auth ok")))
        )

        do {
            _ = try engine.releaseCheck(
                request: ReleaseCheckRequest(
                    projectRoot: root,
                    profile: try makeProfile(
                        name: "daycraft",
                        identity: .init(appleTeamId: "8GT6LT258Y")
                    ),
                    environment: requiredEnvironment(),
                    mode: .syncCerts
                )
            )
            Issue.record("expected ReleaseCheckEngineError.failed")
        } catch ReleaseCheckEngineError.failed(let classification, let step, let summary, _, _) {
            #expect(classification == .certSync)
            #expect(step == .certSync)
            #expect(summary == "signing team mismatch: configured appleTeamId=8GT6LT258Y, discovered team=7WR76382QB")
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test func missingFastlaneScaffoldFailsWithFastlaneClassification() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let engine = ReleaseCheckEngine(
            runner: RecordingReleaseCheckRunner(scriptedResults: []),
            authChecker: StubAppStoreConnectChecker(result: .success(.init(summary: "auth ok")))
        )

        do {
            _ = try engine.releaseCheck(
                request: ReleaseCheckRequest(
                    projectRoot: root,
                    profile: try makeProfile(name: "daycraft"),
                    environment: requiredEnvironment(),
                    mode: .readonlyCerts
                )
            )
            Issue.record("expected ReleaseCheckEngineError.failed")
        } catch ReleaseCheckEngineError.failed(let classification, let step, let summary, _, let artifacts) {
            #expect(classification == .fastlane)
            #expect(step == .fastlaneScaffold)
            #expect(summary.contains("run `bos release-init` first"))
            #expect(artifacts.count == 2)
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test func authFailureIsClassifiedAsAppStoreConnectAuth() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeFastlaneScaffold(root: root)

        let engine = ReleaseCheckEngine(
            runner: RecordingReleaseCheckRunner(
                scriptedResults: [ReleaseCheckCommandResult(exitCode: 0, stdout: "git ok")]
            ),
            authChecker: StubAppStoreConnectChecker(
                result: .failure(NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "401 unauthorized"]))
            )
        )

        do {
            _ = try engine.releaseCheck(
                request: ReleaseCheckRequest(
                    projectRoot: root,
                    profile: try makeProfile(name: "daycraft"),
                    environment: requiredEnvironment(),
                    mode: .connectivity
                )
            )
            Issue.record("expected ReleaseCheckEngineError.failed")
        } catch ReleaseCheckEngineError.failed(let classification, let step, let summary, _, _) {
            #expect(classification == .appStoreConnectAuth)
            #expect(step == .appStoreConnectAuth)
            #expect(summary.contains("App Store Connect authentication failed"))
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test func certSyncFailureRedactsSecretsInArtifacts() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeFastlaneScaffold(root: root)

        let env = requiredEnvironment()
        let runner = RecordingReleaseCheckRunner(
            scriptedResults: [
                ReleaseCheckCommandResult(exitCode: 0, stdout: "git ok"),
                ReleaseCheckCommandResult(
                    exitCode: 1,
                    stderr: "MATCH_PASSWORD=match-secret ASC_KEY_P8_BASE64=c3VwZXItc2VjcmV0"
                )
            ]
        )
        let engine = ReleaseCheckEngine(
            runner: runner,
            authChecker: StubAppStoreConnectChecker(result: .success(.init(summary: "auth ok")))
        )

        do {
            _ = try engine.releaseCheck(
                request: ReleaseCheckRequest(
                    projectRoot: root,
                    profile: try makeProfile(name: "daycraft"),
                    environment: env,
                    mode: .readonlyCerts
                )
            )
            Issue.record("expected ReleaseCheckEngineError.failed")
        } catch ReleaseCheckEngineError.failed(_, _, _, _, let artifacts) {
            let logPath = try #require(artifacts.first(where: { $0.hasSuffix(".log") }))
            let log = try String(contentsOfFile: logPath, encoding: .utf8)
            #expect(!log.contains("match-secret"))
            #expect(!log.contains("c3VwZXItc2VjcmV0"))
            #expect(log.contains("<redacted:MATCH_PASSWORD>"))
            #expect(log.contains("<redacted:ASC_KEY_P8_BASE64>"))
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test func releaseCheckUsesProfileMatchGitURLWhenEnvironmentOmitsLegacyKey() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeFastlaneScaffold(root: root)

        var env = requiredEnvironment()
        env["MATCH_GIT_URL"] = nil

        let runner = RecordingReleaseCheckRunner(
            scriptedResults: [
                ReleaseCheckCommandResult(exitCode: 0, stdout: "git ok")
            ]
        )
        let engine = ReleaseCheckEngine(
            runner: runner,
            authChecker: StubAppStoreConnectChecker(result: .success(.init(summary: "auth ok")))
        )

        _ = try engine.releaseCheck(
            request: ReleaseCheckRequest(
                projectRoot: root,
                profile: try makeProfile(
                    name: "daycraft",
                    release: .init(
                        primaryLanguage: "en-US",
                        matchGitURL: "https://github.com/axiom-orient/AppStoreConnect"
                    )
                ),
                environment: env,
                mode: .connectivity
            )
        )

        #expect(runner.commands == [
            ["git", "ls-remote", "https://github.com/axiom-orient/AppStoreConnect", "HEAD"]
        ])
    }

    @Test func appStoreReadinessFailureIsClassifiedSeparately() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeFastlaneScaffold(root: root)

        let engine = ReleaseCheckEngine(
            runner: RecordingReleaseCheckRunner(
                scriptedResults: [ReleaseCheckCommandResult(exitCode: 0, stdout: "git ok")]
            ),
            authChecker: StubAppStoreConnectChecker(result: .success(.init(summary: "auth ok"))),
            readinessChecker: StubReadinessChecker(
                result: .failure(NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "status missing app store fields"]))
            )
        )

        do {
            _ = try engine.releaseCheck(
                request: ReleaseCheckRequest(
                    projectRoot: root,
                    profile: try makeProfile(name: "daycraft"),
                    environment: requiredEnvironment(),
                    mode: .connectivity
                )
            )
            Issue.record("expected ReleaseCheckEngineError.failed")
        } catch ReleaseCheckEngineError.failed(let classification, let step, let summary, _, _) {
            #expect(classification == .appStoreReadiness)
            #expect(step == .appStoreReadiness)
            #expect(summary.contains("App Store readiness failed"))
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }
}

private extension ReleaseCheckEngineIntegrationTests {
    final class RecordingReleaseCheckRunner: ReleaseCheckCommandRunning {
        private let commandsLock = OSAllocatedUnfairLock(initialState: [[String]]())
        private let environmentLock = OSAllocatedUnfairLock(initialState: [[String: String]]())
        private let scriptedResultsLock: OSAllocatedUnfairLock<[ReleaseCheckCommandResult]>

        init(scriptedResults: [ReleaseCheckCommandResult]) {
            self.scriptedResultsLock = OSAllocatedUnfairLock(initialState: scriptedResults)
        }

        var commands: [[String]] { commandsLock.withLock { $0 } }
        var environments: [[String: String]] { environmentLock.withLock { $0 } }

        func run(command: [String], in workingDirectory: URL, environment: [String: String]) throws -> ReleaseCheckCommandResult {
            commandsLock.withLock { $0.append(command) }
            environmentLock.withLock { $0.append(environment) }
            return scriptedResultsLock.withLock { state in
                guard !state.isEmpty else { return ReleaseCheckCommandResult(exitCode: 0) }
                return state.removeFirst()
            }
        }
    }

    struct StubAppStoreConnectChecker: AppStoreConnectAuthChecking {
        let result: Result<AppStoreConnectPingResult, Error>

        func ping(environment: [String : String]) throws -> AppStoreConnectPingResult {
            switch result {
            case .success(let value):
                return value
            case .failure(let error):
                throw error
            }
        }
    }

    struct StubReadinessChecker: AppStoreReadinessChecking {
        let result: Result<AppStoreReadinessCheckResult, Error>

        func check(projectRoot: URL, profile: Profile, environment: [String : String]) throws -> AppStoreReadinessCheckResult {
            switch result {
            case .success(let value):
                return value
            case .failure(let error):
                throw error
            }
        }
    }

    func makeTempDir() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("bos-release-check-\(ProcessInfo.processInfo.globallyUniqueString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    func writeFastlaneScaffold(root: URL) throws {
        let fastlane = root.appending(path: "fastlane")
        try FileManager.default.createDirectory(at: fastlane, withIntermediateDirectories: true)
        try Data("lane :auth_ping do\nend\nlane :certs_readonly do\nend\nlane :certs do\nend\n".utf8)
            .write(to: fastlane.appending(path: "Fastfile"), options: .atomic)
        try Data("app_identifier(\"com.axiomorient.daycraft\")\n".utf8)
            .write(to: fastlane.appending(path: "Appfile"), options: .atomic)
        try Data("git_url(\"git@github.com:org/certs.git\")\n".utf8)
            .write(to: fastlane.appending(path: "Matchfile"), options: .atomic)
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

    func makeProfile(
        name: String,
        identity: Profile.Identity = .init(),
        release: Profile.ReleaseSettings = .init(primaryLanguage: "en-US")
    ) throws -> Profile {
        let appTargets = Profile.AppTargets(controlsExtension: true, uiTests: true)
        let defaults = Profile.Defaults(deploymentTarget: "18.0", appTargets: appTargets)
        let pattern = Profile.FeaturePattern(sourcesInterface: true, designFolder: true)
        let rules = try Profile.Rules(
            testingStyle: "swift-testing",
            forbidPatterns: ["@unchecked Sendable", "Date()", "UUID()"]
        )
        return try Profile(
            schemaVersion: 1,
            name: name,
            defaults: defaults,
            identity: identity,
            release: release,
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
