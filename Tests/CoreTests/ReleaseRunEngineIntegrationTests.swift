import Foundation
import os
import Testing
@testable import BosCore

@Suite
struct ReleaseRunEngineIntegrationTests {
    @Test func releaseRunBuildStageExecutesDeterministicPipelineAndWritesIPA() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeBootstrapStateFixture(root: root)

        let runner = RecordingRunner(
            scriptedResults: [
                ReleaseRunCommandResult(exitCode: 0, stdout: "tuist install ok"),
                ReleaseRunCommandResult(exitCode: 0, stdout: "tuist generate ok"),
                ReleaseRunCommandResult(exitCode: 0, stdout: "fastlane build ok")
            ]
        )
        let releaseChecker = StubReleaseChecker(result: .success(.init(
            artifacts: [],
            summary: "Release check passed (readonly-certs)",
            mode: .readonlyCerts,
            failureCode: nil,
            failedStep: nil
        )))
        let engine = ReleaseRunEngine(runner: runner, releaseChecker: releaseChecker)

        let result = try engine.run(
            request: ReleaseRunRequest(
                projectRoot: root,
                blueprint: try makeBlueprint(),
                profile: try makeProfile(name: "daycraft"),
                environment: requiredEnvironment(),
                stage: .build
            )
        )

        #expect(releaseChecker.modes == [.readonlyCerts])
        #expect(runner.commands == [
            ["tuist", "install"],
            ["tuist", "generate", "--no-open"],
            ["fastlane", "ios", "build"]
        ])
        #expect(FileManager.default.fileExists(atPath: result.ipaPath))
        #expect(result.summary == "release-run passed (build)")

        let buildEnvironment = try #require(runner.environments.last)
        #expect(buildEnvironment["BOS_SCHEME"] == "DaycraftApp")
        #expect(buildEnvironment["BOS_IPA_OUTPUT_NAME"] == "daycraftapp.ipa")
        #expect(buildEnvironment["BOS_WORKSPACE_PATH"]?.isEmpty == false)

        let state = try String(contentsOf: root.appending(path: ".bos/state/bos.state.yaml"), encoding: .utf8)
        #expect(state.contains("releaseRunSummary:"))
        #expect(state.contains("status: \"success\""))
    }

    @Test func releaseRunBetaStageUsesSyncCertsWhenSigningWriteIsAllowed() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let runner = RecordingRunner(
            scriptedResults: [
                ReleaseRunCommandResult(exitCode: 0),
                ReleaseRunCommandResult(exitCode: 0),
                ReleaseRunCommandResult(exitCode: 0),
                ReleaseRunCommandResult(exitCode: 0)
            ]
        )
        let releaseChecker = StubReleaseChecker(result: .success(.init(
            artifacts: [],
            summary: "Release check passed (sync-certs)",
            mode: .syncCerts,
            failureCode: nil,
            failedStep: nil
        )))
        let engine = ReleaseRunEngine(runner: runner, releaseChecker: releaseChecker)

        _ = try engine.run(
            request: ReleaseRunRequest(
                projectRoot: root,
                blueprint: try makeBlueprint(),
                profile: try makeProfile(name: "daycraft"),
                environment: requiredEnvironment(),
                stage: .beta,
                allowSigningWrite: true
            )
        )

        #expect(releaseChecker.modes == [.syncCerts])
        #expect(runner.commands == [
            ["tuist", "install"],
            ["tuist", "generate", "--no-open"],
            ["fastlane", "ios", "build"],
            ["fastlane", "ios", "beta"]
        ])
        let uploadEnvironment = try #require(runner.environments.last)
        #expect(uploadEnvironment["IPA_PATH"]?.hasSuffix("daycraftapp.ipa") == true)
    }

    @Test func releaseRunReleaseStageUsesAppStoreUploadLane() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let runner = RecordingRunner(
            scriptedResults: [
                ReleaseRunCommandResult(exitCode: 0),
                ReleaseRunCommandResult(exitCode: 0),
                ReleaseRunCommandResult(exitCode: 0),
                ReleaseRunCommandResult(exitCode: 0)
            ]
        )
        let releaseChecker = StubReleaseChecker(result: .success(.init(
            artifacts: [],
            summary: "Release check passed (readonly-certs)",
            mode: .readonlyCerts,
            failureCode: nil,
            failedStep: nil
        )))
        let engine = ReleaseRunEngine(runner: runner, releaseChecker: releaseChecker)

        _ = try engine.run(
            request: ReleaseRunRequest(
                projectRoot: root,
                blueprint: try makeBlueprint(),
                profile: try makeProfile(name: "daycraft"),
                environment: requiredEnvironment(),
                stage: .release
            )
        )

        #expect(runner.commands == [
            ["tuist", "install"],
            ["tuist", "generate", "--no-open"],
            ["fastlane", "ios", "build"],
            ["fastlane", "ios", "release"]
        ])
    }

    @Test func releaseRunSubmitStageClassifiesSubmitLaneFailure() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeBootstrapStateFixture(root: root)

        let runner = RecordingRunner(
            scriptedResults: [
                ReleaseRunCommandResult(exitCode: 0),
                ReleaseRunCommandResult(exitCode: 0),
                ReleaseRunCommandResult(exitCode: 0),
                ReleaseRunCommandResult(exitCode: 1, stderr: "submit failed")
            ]
        )
        let releaseChecker = StubReleaseChecker(result: .success(.init(
            artifacts: [],
            summary: "Release check passed (readonly-certs)",
            mode: .readonlyCerts,
            failureCode: nil,
            failedStep: nil
        )))
        let engine = ReleaseRunEngine(runner: runner, releaseChecker: releaseChecker)

        do {
            _ = try engine.run(
                request: ReleaseRunRequest(
                    projectRoot: root,
                    blueprint: try makeBlueprint(),
                    profile: try makeProfile(name: "daycraft"),
                    environment: requiredEnvironment(),
                    stage: .submit
                )
            )
            Issue.record("expected ReleaseRunEngineError.failed")
        } catch ReleaseRunEngineError.failed(let classification, let step, let summary, _, _) {
            #expect(classification == .submit)
            #expect(step == .fastlaneSubmit)
            #expect(summary.contains("submit failed"))
        }

        #expect(runner.commands == [
            ["tuist", "install"],
            ["tuist", "generate", "--no-open"],
            ["fastlane", "ios", "build"],
            ["fastlane", "ios", "submit"]
        ])
    }

    @Test func releaseRunMapsReleaseCheckFailureToPreflightAndUpdatesState() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeBootstrapStateFixture(root: root)

        let runner = RecordingRunner(scriptedResults: [])
        let releaseChecker = StubReleaseChecker(result: .failure(.failed(
            classification: .certSync,
            step: .certSync,
            summary: "certificate sync failed",
            exitCode: 1,
            artifacts: []
        )))
        let engine = ReleaseRunEngine(runner: runner, releaseChecker: releaseChecker)

        do {
            _ = try engine.run(
                request: ReleaseRunRequest(
                    projectRoot: root,
                    blueprint: try makeBlueprint(),
                    profile: try makeProfile(name: "daycraft"),
                    environment: requiredEnvironment(),
                    stage: .submit
                )
            )
            Issue.record("expected ReleaseRunEngineError.failed")
        } catch ReleaseRunEngineError.failed(let classification, let step, let summary, _, _) {
            #expect(classification == .preflight)
            #expect(step == .releaseCheck)
            #expect(summary.contains("certificate sync failed"))
        }

        #expect(runner.commands.isEmpty)
        let state = try String(contentsOf: root.appending(path: ".bos/state/bos.state.yaml"), encoding: .utf8)
        #expect(state.contains("releaseRunSummary:"))
        #expect(state.contains("status: \"failed\""))
    }
}

private extension ReleaseRunEngineIntegrationTests {
    final class RecordingRunner: ReleaseRunCommandRunning {
        private struct State {
            var scriptedResults: [ReleaseRunCommandResult]
            var commands: [[String]] = []
            var environments: [[String: String]] = []
            var workingDirectories: [String] = []
        }

        private let state: OSAllocatedUnfairLock<State>

        var commands: [[String]] { state.withLock { $0.commands } }
        var environments: [[String: String]] { state.withLock { $0.environments } }

        init(scriptedResults: [ReleaseRunCommandResult]) {
            self.state = OSAllocatedUnfairLock(initialState: State(scriptedResults: scriptedResults))
        }

        func run(command: [String], in workingDirectory: URL, environment: [String : String]) throws -> ReleaseRunCommandResult {
            state.withLock { state in
                state.commands.append(command)
                state.environments.append(environment)
                state.workingDirectories.append(workingDirectory.path(percentEncoded: false))

                if command == ["tuist", "generate", "--no-open"] {
                    let workspace = workingDirectory.appending(path: "DaycraftApp.xcworkspace")
                    try? FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
                }
                if command == ["fastlane", "ios", "build"],
                   let outputDir = environment["BOS_IPA_OUTPUT_DIR"],
                   let outputName = environment["BOS_IPA_OUTPUT_NAME"] {
                    let outputURL = URL(fileURLWithPath: outputDir, isDirectory: true).appending(path: outputName)
                    try? FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try? Data("ipa".utf8).write(to: outputURL)
                }

                if state.scriptedResults.isEmpty {
                    return ReleaseRunCommandResult(exitCode: 0)
                }
                return state.scriptedResults.removeFirst()
            }
        }
    }

    final class StubReleaseChecker: ReleaseCheckPerforming {
        private let result: Result<ReleaseCheckResult, ReleaseCheckEngineError>
        private let lock = OSAllocatedUnfairLock(initialState: [ReleaseCheckMode]())

        var modes: [ReleaseCheckMode] { lock.withLock { $0 } }

        init(result: Result<ReleaseCheckResult, ReleaseCheckEngineError>) {
            self.result = result
        }

        func releaseCheck(request: ReleaseCheckRequest) throws -> ReleaseCheckResult {
            lock.withLock { $0.append(request.mode) }
            return try result.get()
        }
    }

    func makeTempDir() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("bos-release-run-\(ProcessInfo.processInfo.globallyUniqueString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    func makeProfile(name: String) throws -> Profile {
        let defaults = Profile.Defaults(
            deploymentTarget: "18.0",
            appTargets: .init(controlsExtension: false, uiTests: true)
        )
        let rules = try Profile.Rules(
            testingStyle: "swift-testing",
            forbidPatterns: ["@unchecked Sendable", "Date()", "UUID()"]
        )
        return try Profile(
            schemaVersion: 1,
            name: name,
            defaults: defaults,
            identity: .init(
                companyName: "Axiom Orient",
                appName: "Daycraft",
                appIdentifier: "com.axiomorient.daycraft",
                appleTeamId: "A1B2C3D4E5"
            ),
            release: .init(primaryLanguage: "en-US", sku: "axiom-orient.daycraft.04805b02", matchGitURL: "git@github.com:org/certs.git"),
            featurePattern: .init(sourcesInterface: true, designFolder: false),
            rules: rules
        )
    }

    func makeBlueprint() throws -> Blueprint {
        try Blueprint(
            schemaVersion: 1,
            project: .init(name: "Daycraft", bundleIdPrefix: "com.axiomorient", deploymentTarget: "18.0"),
            requirements: .init(reqIds: ["REQ-001"], screens: ["SCR_TODAY_HOME"]),
            modules: .init(
                app: .init(name: "Daycraft"),
                features: ["Root", "TodayHome"],
                domains: ["User"],
                services: ["UserService"],
                shared: ["Core", "DesignSystem"]
            ),
            wiring: .init(rootFeature: "Root"),
            release: .init(
                fastlane: try .init(
                    appIdentifier: "com.axiomorient.daycraft",
                    appleTeamId: "A1B2C3D4E5",
                    appName: "Daycraft",
                    sku: "axiom-orient.daycraft.04805b02",
                    primaryLanguage: "en-US",
                    companyName: "Axiom Orient"
                )
            )
        )
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
            releaseCheckSummary:
              status: "not-run"
              message: "release-check not executed in apply step"
            releaseRunSummary:
              status: "not-run"
              message: "release-run not executed in apply step"
            """.utf8
        ).write(to: statePath, options: .atomic)
    }
}
