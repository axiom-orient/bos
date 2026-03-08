import Foundation
import os
import Testing
@testable import BosCore

@Suite
struct ProfilePolicyE2ETests {
    private let applyEngine = ApplyEngine()

    @Test func applyAndVerifySucceedForDefaultPolicyFile() throws {
        let fixturesRoot = repositoryRoot().appending(path: "Tests/Fixtures")
        let daycraft = try loadProfile(from: fixturesRoot.appending(path: "daycraft.yaml"))

        try runE2E(profile: daycraft, expectedScheme: "DaycraftApp")
    }
}

private extension ProfilePolicyE2ETests {
    final class VerifyRunnerStub: VerifyCommandRunning {
        private let commandsLock = OSAllocatedUnfairLock(initialState: [[String]]())

        var commands: [[String]] { commandsLock.withLock { $0 } }

        func run(command: [String], in workingDirectory: URL) throws -> VerifyCommandResult {
            commandsLock.withLock { $0.append(command) }
            return VerifyCommandResult(exitCode: 0)
        }
    }

    func runE2E(profile: ProfileV1, expectedScheme: String) throws {
        let root = try makeTempDir(prefix: "bos-profile-e2e")
        defer { try? FileManager.default.removeItem(at: root) }

        let blueprint = try makeBlueprint(projectName: expectedScheme.replacingOccurrences(of: "App", with: ""))

        _ = try applyEngine.apply(
            request: ApplyRequest(
                projectRoot: root,
                blueprint: blueprint,
                profile: profile,
                mode: .initMode
            )
        )

        let runner = VerifyRunnerStub()
        let verifyEngine = VerifyEngine(runner: runner)
        let verifyResult = try verifyEngine.verify(
            request: VerifyRequest(projectRoot: root, profile: profile)
        )

        #expect(!verifyResult.artifacts.isEmpty)
        #expect(runner.commands.count == 4)
        #expect(runner.commands[2] == ["xcodebuild", "build", "-scheme", expectedScheme])
        #expect(FileManager.default.fileExists(atPath: root.appending(path: "Projects/App/Project.swift").path(percentEncoded: false)))
    }

    func loadProfile(from path: URL) throws -> ProfileV1 {
        let data = try Data(contentsOf: path)
        return try JSONDecoder().decode(ProfileV1.self, from: data)
    }

    func makeBlueprint(projectName: String) throws -> BlueprintV1 {
        let project = try BlueprintV1.Project(
            name: projectName,
            bundleIdPrefix: "com.axiomorient",
            deploymentTarget: "18.0"
        )
        let requirements = try BlueprintV1.Requirements(
            reqIds: ["REQ-001"],
            screens: ["SCR_HOME"]
        )
        let app = try BlueprintV1.AppModule(name: projectName)
        let modules = try BlueprintV1.Modules(
            app: app,
            features: ["Root", "Home"],
            domains: ["User"],
            services: ["Auth"],
            shared: ["Core", "DesignSystem"]
        )
        let wiring = try BlueprintV1.Wiring(rootFeature: "Root")
        let fastlane = try BlueprintV1.Fastlane(
            appIdentifier: "com.axiomorient.\(projectName.lowercased())",
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

    func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func makeTempDir(prefix: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(ProcessInfo.processInfo.globallyUniqueString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
