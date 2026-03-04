import Foundation
import XCTest
@testable import BosCore

final class VerifyEngineIntegrationTests: XCTestCase {
    func testVerifyRunsStandardSequenceForDaycraftAndWritesArtifacts() throws {
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

        XCTAssertEqual(
            runner.commands,
            [
                ["tuist", "install"],
                ["tuist", "generate", "--no-open"],
                ["xcodebuild", "build", "-scheme", "DaycraftApp"],
                ["xcodebuild", "test", "-scheme", "DaycraftApp"]
            ]
        )

        let rootPath = root.path(percentEncoded: false)
        XCTAssertEqual(runner.workingDirectories, [rootPath, rootPath, rootPath, rootPath])

        let jsonPath = try XCTUnwrap(result.artifacts.first(where: { $0.hasSuffix(".json") }))
        let logPath = try XCTUnwrap(result.artifacts.first(where: { $0.hasSuffix(".log") }))
        XCTAssertTrue(FileManager.default.fileExists(atPath: jsonPath))
        XCTAssertTrue(FileManager.default.fileExists(atPath: logPath))

        let log = try String(contentsOfFile: logPath, encoding: .utf8)
        XCTAssertTrue(log.contains("tuist install"))
        XCTAssertTrue(log.contains("xcodebuild build -scheme DaycraftApp"))
        XCTAssertTrue(log.contains("xcodebuild test -scheme DaycraftApp"))

        let payloadData = try Data(contentsOf: URL(fileURLWithPath: jsonPath))
        let payload = try JSONDecoder().decode(VerifyArtifactPayload.self, from: payloadData)
        XCTAssertEqual(payload.command, "verify")
        XCTAssertEqual(payload.status, "success")
        XCTAssertEqual(payload.exitCode, 0)
        XCTAssertNil(payload.failureCode)
        XCTAssertNil(payload.failedStep)
    }

    func testVerifyUsesSanitizedProfileNameWhenProjectSchemeMissing() throws {
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

        XCTAssertEqual(runner.commands[2], ["xcodebuild", "build", "-scheme", "IosNativeApp"])
        XCTAssertEqual(
            runner.commands[3],
            ["xcodebuild", "test", "-scheme", "IosNativeApp"]
        )
    }

    func testVerifyAppendsResolvedSimulatorDestinationToTestCommand() throws {
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

        XCTAssertEqual(
            runner.commands[3],
            ["xcodebuild", "test", "-scheme", "DaycraftApp", "-destination", "id=SIM-DEVICE-1234"]
        )

        let logPath = try XCTUnwrap(result.artifacts.first(where: { $0.hasSuffix(".log") }))
        let log = try String(contentsOfFile: logPath, encoding: .utf8)
        XCTAssertTrue(log.contains("testDestination=id=SIM-DEVICE-1234"))
    }

    func testVerifyCleansGeneratedBuildArtifactsFromProjectRoot() throws {
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

        XCTAssertFalse(fm.fileExists(atPath: workspace.path(percentEncoded: false)))
        XCTAssertFalse(fm.fileExists(atPath: xcodeproj.path(percentEncoded: false)))
        XCTAssertFalse(fm.fileExists(atPath: derived.path(percentEncoded: false)))
        XCTAssertFalse(fm.fileExists(atPath: temporary.path(percentEncoded: false)))
        XCTAssertFalse(fm.fileExists(atPath: tuistBuild.path(percentEncoded: false)))
        XCTAssertFalse(fm.fileExists(atPath: tuistResolved.path(percentEncoded: false)))
        XCTAssertFalse(fm.fileExists(atPath: swiftGenerated.path(percentEncoded: false)))
        XCTAssertFalse(fm.fileExists(atPath: lockFile.path(percentEncoded: false)))
    }

    func testVerifyFailureAtTuistInstallIsClassifiedAsToolchain() throws {
        try assertFailureClassification(
            scriptedResults: [VerifyCommandResult(exitCode: 127, stderr: "command not found")],
            expectedClassification: .toolchain,
            expectedStep: .tuistInstall
        )
    }

    func testVerifyFailureAtTuistGenerateIsClassifiedAsGeneration() throws {
        try assertFailureClassification(
            scriptedResults: [
                VerifyCommandResult(exitCode: 0),
                VerifyCommandResult(exitCode: 1, stderr: "graph failed")
            ],
            expectedClassification: .generation,
            expectedStep: .tuistGenerate
        )
    }

    func testVerifyFailureAtBuildIsClassifiedAsBuild() throws {
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

    func testVerifyFailureAtTestIsClassifiedAsTest() throws {
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

    func testVerifyPrefersAppProjectSchemeOverProfileName() throws {
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

        XCTAssertEqual(runner.commands[2], ["xcodebuild", "build", "-scheme", "CustomApp"])
        XCTAssertEqual(
            runner.commands[3],
            ["xcodebuild", "test", "-scheme", "CustomApp"]
        )
    }

    func testVerifyUpdatesBootstrapStateSummaryOnSuccess() throws {
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
        XCTAssertTrue(state.contains("verifySummary:"))
        XCTAssertTrue(state.contains("status: \"success\""))
        XCTAssertTrue(state.contains("Verify pipeline passed"))
    }

    func testVerifyUpdatesBootstrapStateSummaryOnFailure() throws {
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

        XCTAssertThrowsError(
            try engine.verify(
                request: VerifyRequest(
                    projectRoot: root,
                    profile: try makeProfile(name: "daycraft")
                )
            )
        ) { error in
            guard case VerifyEngineError.commandFailed(let classification, let step, _, _) = error else {
                return XCTFail("unexpected error: \(error)")
            }
            XCTAssertEqual(classification, .test)
            XCTAssertEqual(step, .xcodebuildTest)
        }

        let statePath = root.appending(path: ".bos/state/bos.state.yaml")
        let state = try String(contentsOf: statePath, encoding: .utf8)
        XCTAssertTrue(state.contains("verifySummary:"))
        XCTAssertTrue(state.contains("status: \"failed\""))
        XCTAssertTrue(state.contains("Verify failed at xcodebuild-test (E-TEST)"))
    }
}

private extension VerifyEngineIntegrationTests {
    struct VerifyArtifactPayload: Decodable {
        let command: String
        let status: String
        let exitCode: Int
        let summary: String
        let failureCode: String?
        let failedStep: String?
        let artifacts: [String]
    }

    final class RecordingVerifyRunner: VerifyCommandRunning {
        private var scriptedResults: [VerifyCommandResult]
        private(set) var commands: [[String]] = []
        private(set) var workingDirectories: [String] = []

        init(scriptedResults: [VerifyCommandResult]) {
            self.scriptedResults = scriptedResults
        }

        func run(command: [String], in workingDirectory: URL) throws -> VerifyCommandResult {
            commands.append(command)
            workingDirectories.append(workingDirectory.path(percentEncoded: false))
            if scriptedResults.isEmpty {
                return VerifyCommandResult(exitCode: 0)
            }
            return scriptedResults.removeFirst()
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

        XCTAssertThrowsError(
            try engine.verify(
                request: VerifyRequest(
                    projectRoot: root,
                    profile: try makeProfile(name: "daycraft")
                )
            )
        ) { error in
            guard case VerifyEngineError.commandFailed(let classification, let step, let exitCode, let artifacts) = error else {
                return XCTFail("unexpected error: \(error)")
            }
            XCTAssertEqual(classification, expectedClassification)
            XCTAssertEqual(step, expectedStep)
            XCTAssertNotEqual(exitCode, 0)
            do {
                let jsonPath = try XCTUnwrap(artifacts.first(where: { $0.hasSuffix(".json") }))
                let payloadData = try Data(contentsOf: URL(fileURLWithPath: jsonPath))
                let payload = try JSONDecoder().decode(VerifyArtifactPayload.self, from: payloadData)
                XCTAssertEqual(payload.status, "failed")
                XCTAssertEqual(payload.exitCode, 4)
                XCTAssertEqual(payload.failureCode, expectedClassification.rawValue)
                XCTAssertEqual(payload.failedStep, expectedStep.rawValue)
                XCTAssertEqual(payload.artifacts.count, 2)
            } catch {
                XCTFail("failed to decode verify artifact: \(error)")
            }
        }
    }

    func makeTempDir() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("bos-verify-\(ProcessInfo.processInfo.globallyUniqueString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
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
