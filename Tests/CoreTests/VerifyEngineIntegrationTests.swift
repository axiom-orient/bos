import Foundation
import os
import Testing
@testable import BosCore

@Suite
struct VerifyEngineIntegrationTests {
    @Test func verifyRunsStandardSequenceForDaycraftAndWritesArtifacts() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let runner = RecordingVerifyRunner(
            scriptedResults: [
                VerifyCommandResult(exitCode: 0, stdout: "tuist install ok"),
                VerifyCommandResult(exitCode: 0, stdout: "tuist generate ok"),
                VerifyCommandResult(exitCode: 0, stdout: "build ok"),
                VerifyCommandResult(exitCode: 0, stdout: "test ok")
            ]
        )
        let engine = VerifyEngine(runner: runner, simulatorDestinationResolver: { nil })

        let result = try engine.verify(
            request: VerifyRequest(
                projectRoot: root,
                profile: try makeProfile(name: "daycraft")
            )
        )

        #expect(
            runner.commands ==
            [
                ["tuist", "install"],
                ["tuist", "generate", "--no-open"],
                ["xcodebuild", "build", "-scheme", "DaycraftApp", "CODE_SIGNING_ALLOWED=NO", "CODE_SIGNING_REQUIRED=NO"],
                ["xcodebuild", "test", "-scheme", "DaycraftApp", "CODE_SIGNING_ALLOWED=NO", "CODE_SIGNING_REQUIRED=NO"]
            ]
        )

        let rootPath = root.path(percentEncoded: false)
        #expect(runner.workingDirectories == [rootPath, rootPath, rootPath, rootPath])

        let jsonPath = try #require(result.artifacts.first(where: { $0.hasSuffix("/run.json") }))
        let stdoutPath = try #require(result.artifacts.first(where: { $0.hasSuffix("/stdout.log") }))
        let stderrPath = try #require(result.artifacts.first(where: { $0.hasSuffix("/stderr.log") }))
        let manifestPath = try #require(result.artifacts.first(where: { $0.hasSuffix("/manifest.json") }))
        #expect(FileManager.default.fileExists(atPath: jsonPath))
        #expect(FileManager.default.fileExists(atPath: stdoutPath))
        #expect(FileManager.default.fileExists(atPath: stderrPath))
        #expect(FileManager.default.fileExists(atPath: manifestPath))

        let log = try String(contentsOfFile: stdoutPath, encoding: .utf8)
        #expect(log.contains("tuist install"))
        #expect(log.contains("xcodebuild build -scheme DaycraftApp"))
        #expect(log.contains("xcodebuild test -scheme DaycraftApp"))

        let payloadData = try Data(contentsOf: URL(fileURLWithPath: jsonPath))
        let envelope = try JSONDecoder().decode(AdapterRunEnvelope<VerifyArtifactPayload>.self, from: payloadData)
        let payload = envelope.payload
        #expect(envelope.command == "verify")
        #expect(envelope.status == "success")
        #expect(envelope.exitCode == 0)
        #expect(payload.failureCode == nil)
        #expect(payload.failedStep == nil)

        let manifestData = try Data(contentsOf: URL(fileURLWithPath: manifestPath))
        let manifest = try JSONDecoder().decode(AdapterArtifactManifest.self, from: manifestData)
        #expect(manifest.files.map(\.kind) == ["run", "stdout", "stderr", "manifest"])
    }

    @Test func verifyUsesSanitizedProfileNameWhenProjectSchemeMissing() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let runner = RecordingVerifyRunner(
            scriptedResults: Array(repeating: VerifyCommandResult(exitCode: 0), count: 4)
        )
        let engine = VerifyEngine(runner: runner, simulatorDestinationResolver: { nil })

        _ = try engine.verify(
            request: VerifyRequest(
                projectRoot: root,
                profile: try makeProfile(name: "ios_native")
            )
        )

        #expect(runner.commands[2] == ["xcodebuild", "build", "-scheme", "IosNativeApp", "CODE_SIGNING_ALLOWED=NO", "CODE_SIGNING_REQUIRED=NO"])
        #expect(runner.commands[3] == ["xcodebuild", "test", "-scheme", "IosNativeApp", "CODE_SIGNING_ALLOWED=NO", "CODE_SIGNING_REQUIRED=NO"])
    }

    @Test func verifyAppendsResolvedSimulatorDestinationToTestCommand() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let runner = RecordingVerifyRunner(
            scriptedResults: Array(repeating: VerifyCommandResult(exitCode: 0), count: 4)
        )
        let engine = VerifyEngine(runner: runner, simulatorDestinationResolver: { "id=SIM-DEVICE-1234" })

        let result = try engine.verify(
            request: VerifyRequest(
                projectRoot: root,
                profile: try makeProfile(name: "daycraft")
            )
        )

        #expect(
            runner.commands[3] ==
            ["xcodebuild", "test", "-scheme", "DaycraftApp", "-destination", "id=SIM-DEVICE-1234", "CODE_SIGNING_ALLOWED=NO", "CODE_SIGNING_REQUIRED=NO"]
        )

        let stdoutPath = try #require(result.artifacts.first(where: { $0.hasSuffix("/stdout.log") }))
        let log = try String(contentsOfFile: stdoutPath, encoding: .utf8)
        #expect(log.contains("testDestination=id=SIM-DEVICE-1234"))
    }

    @Test func verifyCleansGeneratedBuildArtifactsFromProjectRoot() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let fm = FileManager.default
        let workspace = root.appending(path: "Daycraft.xcworkspace")
        let xcodeproj = root.appending(path: "Projects/App/DaycraftApp.xcodeproj")
        let derived = root.appending(path: "Projects/App/Derived")
        let temporary = root.appending(path: "TemporaryDirectory.ABC123")
        let tuistBuild = root.appending(path: "Tuist/.build")
        let tuistResolved = root.appending(path: "Tuist/Package.resolved")
        let swiftGenerated = root.appending(path: "swift-generated-sources")
        let lockFile = root.appending(path: "_private_tmp_example.lock")

        try fm.createDirectory(at: workspace, withIntermediateDirectories: true)
        try fm.createDirectory(at: xcodeproj, withIntermediateDirectories: true)
        try fm.createDirectory(at: derived, withIntermediateDirectories: true)
        try fm.createDirectory(at: temporary, withIntermediateDirectories: true)
        try fm.createDirectory(at: tuistBuild, withIntermediateDirectories: true)
        try Data("resolved".utf8).write(to: tuistResolved)
        try fm.createDirectory(at: swiftGenerated, withIntermediateDirectories: true)
        try Data("lock".utf8).write(to: lockFile)

        let runner = RecordingVerifyRunner(
            scriptedResults: Array(repeating: VerifyCommandResult(exitCode: 0), count: 4)
        )
        let engine = VerifyEngine(runner: runner, simulatorDestinationResolver: { nil })

        _ = try engine.verify(
            request: VerifyRequest(
                projectRoot: root,
                profile: try makeProfile(name: "daycraft")
            )
        )

        #expect(!fm.fileExists(atPath: workspace.path(percentEncoded: false)))
        #expect(!fm.fileExists(atPath: xcodeproj.path(percentEncoded: false)))
        #expect(!fm.fileExists(atPath: derived.path(percentEncoded: false)))
        #expect(!fm.fileExists(atPath: temporary.path(percentEncoded: false)))
        #expect(!fm.fileExists(atPath: tuistBuild.path(percentEncoded: false)))
        #expect(!fm.fileExists(atPath: tuistResolved.path(percentEncoded: false)))
        #expect(!fm.fileExists(atPath: swiftGenerated.path(percentEncoded: false)))
        #expect(!fm.fileExists(atPath: lockFile.path(percentEncoded: false)))
    }

    @Test func verifyFailureAtTuistInstallIsClassifiedAsToolchain() throws {
        try assertFailureClassification(
            scriptedResults: [VerifyCommandResult(exitCode: 127, stderr: "command not found")],
            expectedClassification: .toolchain,
            expectedStep: .tuistInstall
        )
    }

    @Test func verifyFailureAtTuistGenerateIsClassifiedAsGeneration() throws {
        try assertFailureClassification(
            scriptedResults: [
                VerifyCommandResult(exitCode: 0),
                VerifyCommandResult(exitCode: 1, stderr: "graph failed")
            ],
            expectedClassification: .generation,
            expectedStep: .tuistGenerate
        )
    }

    @Test func verifyFailureAtBuildIsClassifiedAsBuild() throws {
        try assertFailureClassification(
            scriptedResults: [
                VerifyCommandResult(exitCode: 0),
                VerifyCommandResult(exitCode: 0),
                VerifyCommandResult(exitCode: 65, stderr: "compile error")
            ],
            expectedClassification: .build,
            expectedStep: .xcodebuildBuild
        )
    }

    @Test func verifyFailureAtTestIsClassifiedAsTest() throws {
        try assertFailureClassification(
            scriptedResults: [
                VerifyCommandResult(exitCode: 0),
                VerifyCommandResult(exitCode: 0),
                VerifyCommandResult(exitCode: 0),
                VerifyCommandResult(exitCode: 65, stderr: "test failed")
            ],
            expectedClassification: .test,
            expectedStep: .xcodebuildTest
        )
    }

    @Test func verifyPrefersAppProjectSchemeOverProfileName() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        let appProject = root.appending(path: "Projects/App/Project.swift")
        try FileManager.default.createDirectory(at: appProject.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(
            """
            import ProjectDescription
            let appName = "CustomApp"
            let project = Project(name: appName)
            """.utf8
        ).write(to: appProject, options: .atomic)

        let runner = RecordingVerifyRunner(
            scriptedResults: Array(repeating: VerifyCommandResult(exitCode: 0), count: 4)
        )
        let engine = VerifyEngine(runner: runner, simulatorDestinationResolver: { nil })

        _ = try engine.verify(
            request: VerifyRequest(
                projectRoot: root,
                profile: try makeProfile(name: "ignored_profile_name")
            )
        )

        #expect(runner.commands[2] == ["xcodebuild", "build", "-scheme", "CustomApp", "CODE_SIGNING_ALLOWED=NO", "CODE_SIGNING_REQUIRED=NO"])
        #expect(runner.commands[3] == ["xcodebuild", "test", "-scheme", "CustomApp", "CODE_SIGNING_ALLOWED=NO", "CODE_SIGNING_REQUIRED=NO"])
    }

    @Test func verifyUpdatesBootstrapStateSummaryOnSuccess() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeBootstrapStateFixture(root: root)

        let runner = RecordingVerifyRunner(
            scriptedResults: Array(repeating: VerifyCommandResult(exitCode: 0), count: 4)
        )
        let engine = VerifyEngine(runner: runner, simulatorDestinationResolver: { nil })

        _ = try engine.verify(
            request: VerifyRequest(
                projectRoot: root,
                profile: try makeProfile(name: "daycraft")
            )
        )

        let statePath = root.appending(path: ".bos/state/bos.state.yaml")
        let state = try String(contentsOf: statePath, encoding: .utf8)
        #expect(state.contains("verifySummary:"))
        #expect(state.contains("status: success"))
        #expect(state.contains("Verify pipeline passed"))
    }

    @Test func verifyUpdatesBootstrapStateSummaryOnFailure() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeBootstrapStateFixture(root: root)

        let runner = RecordingVerifyRunner(
            scriptedResults: [
                VerifyCommandResult(exitCode: 0),
                VerifyCommandResult(exitCode: 0),
                VerifyCommandResult(exitCode: 0),
                VerifyCommandResult(exitCode: 65, stderr: "test failed")
            ]
        )
        let engine = VerifyEngine(runner: runner, simulatorDestinationResolver: { nil })

        do {
            _ = try engine.verify(
                request: VerifyRequest(
                    projectRoot: root,
                    profile: try makeProfile(name: "daycraft")
                )
            )
            Issue.record("expected VerifyEngineError.commandFailed to be thrown")
        } catch VerifyEngineError.commandFailed(let classification, let step, _, _) {
            #expect(classification == .test)
            #expect(step == .xcodebuildTest)
        } catch {
            Issue.record("unexpected error: \(error)")
        }

        let statePath = root.appending(path: ".bos/state/bos.state.yaml")
        let state = try String(contentsOf: statePath, encoding: .utf8)
        #expect(state.contains("verifySummary:"))
        #expect(state.contains("status: failed"))
        #expect(state.contains("Verify failed at xcodebuild-test (E-TEST)"))
    }
}

private extension VerifyEngineIntegrationTests {
    struct VerifyArtifactPayload: Codable {
        let command: String
        let status: String
        let exitCode: Int
        let summary: String
        let failureCode: String?
        let failedStep: String?
        let artifacts: [String]
    }

    final class RecordingVerifyRunner: VerifyCommandRunning {
        private struct State {
            var scriptedResults: [VerifyCommandResult]
            var commands: [[String]] = []
            var workingDirectories: [String] = []
        }

        private let state: OSAllocatedUnfairLock<State>

        var commands: [[String]] { state.withLock { $0.commands } }
        var workingDirectories: [String] { state.withLock { $0.workingDirectories } }

        init(scriptedResults: [VerifyCommandResult]) {
            state = OSAllocatedUnfairLock(initialState: State(scriptedResults: scriptedResults))
        }

        func run(command: [String], in workingDirectory: URL) throws -> VerifyCommandResult {
            state.withLock { s in
                s.commands.append(command)
                s.workingDirectories.append(workingDirectory.path(percentEncoded: false))
                if s.scriptedResults.isEmpty {
                    return VerifyCommandResult(exitCode: 0)
                }
                return s.scriptedResults.removeFirst()
            }
        }
    }

    func assertFailureClassification(
        scriptedResults: [VerifyCommandResult],
        expectedClassification: VerifyFailureCode,
        expectedStep: VerifyStep
    ) throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let runner = RecordingVerifyRunner(scriptedResults: scriptedResults)
        let engine = VerifyEngine(runner: runner, simulatorDestinationResolver: { nil })

        do {
            _ = try engine.verify(
                request: VerifyRequest(
                    projectRoot: root,
                    profile: try makeProfile(name: "daycraft")
                )
            )
            Issue.record("expected VerifyEngineError.commandFailed to be thrown")
        } catch VerifyEngineError.commandFailed(let classification, let step, let exitCode, let artifacts) {
            #expect(classification == expectedClassification)
            #expect(step == expectedStep)
            #expect(exitCode != 0)
            let jsonPath = try #require(artifacts.first(where: { $0.hasSuffix("/run.json") }))
            let payloadData = try Data(contentsOf: URL(fileURLWithPath: jsonPath))
            let envelope = try JSONDecoder().decode(AdapterRunEnvelope<VerifyArtifactPayload>.self, from: payloadData)
            let payload = envelope.payload
            #expect(envelope.status == "failed")
            #expect(envelope.exitCode == 4)
            #expect(payload.failureCode == expectedClassification.rawValue)
            #expect(payload.failedStep == expectedStep.rawValue)
            #expect(payload.artifacts.count == 4)
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    func makeTempDir() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("bos-verify-\(ProcessInfo.processInfo.globallyUniqueString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    func makeProfile(name: String) throws -> Profile {
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
