import Foundation

public protocol VerifyCommandRunning: Sendable {
    func run(command: [String], in workingDirectory: URL) throws -> VerifyCommandResult
}

public struct VerifyCommandResult: Sendable, Equatable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

    public init(exitCode: Int32, stdout: String = "", stderr: String = "") {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }
}

public struct VerifyRequest: Sendable {
    public let projectRoot: URL
    public let profile: Profile

    public init(projectRoot: URL, profile: Profile) {
        self.projectRoot = projectRoot
        self.profile = profile
    }
}

public struct VerifyResult: Sendable {
    public let artifacts: [String]
    public let summary: String

    public init(artifacts: [String], summary: String) {
        self.artifacts = artifacts
        self.summary = summary
    }
}

public enum VerifyFailureCode: String, Sendable, Equatable {
    case toolchain = "E-TOOLCHAIN"
    case generation = "E-GENERATION"
    case build = "E-BUILD"
    case test = "E-TEST"
}

public enum VerifyStep: String, Sendable, Equatable {
    case tuistInstall = "tuist-install"
    case tuistGenerate = "tuist-generate"
    case xcodebuildBuild = "xcodebuild-build"
    case xcodebuildTest = "xcodebuild-test"
}

public enum VerifyEngineError: Error, Equatable {
    case commandFailed(classification: VerifyFailureCode, step: VerifyStep, exitCode: Int32, artifacts: [String])
}

public struct VerifyEngine: Sendable {
    private let runner: any VerifyCommandRunning
    private let simulatorDestinationResolver: @Sendable () -> String?

    public init(
        runner: any VerifyCommandRunning,
        simulatorDestinationResolver: (@Sendable () -> String?)? = nil
    ) {
        self.runner = runner
        self.simulatorDestinationResolver = simulatorDestinationResolver ?? VerifyEngine.detectPreferredSimulatorDestination
    }

    public func verify(request: VerifyRequest) throws -> VerifyResult {
        let root = request.projectRoot.standardizedFileURL
        defer { ProjectBuildSupport.cleanupGeneratedProjectArtifacts(at: root) }

        let policy = verifyPolicy(for: request.profile, projectRoot: root)
        let testDestination = simulatorDestinationResolver()
        let steps = makeSteps(policy: policy, testDestination: testDestination)

        let stamp = RuntimeSupport.timestamp()
        let bundle = try AdapterArtifacts.makeBundle(command: "verify", projectRoot: root, stamp: stamp)
        let artifactList = bundle.artifacts

        var logLines: [String] = [
            "# bos verify",
            "profile=\(request.profile.name)",
            "projectRoot=\(root.path(percentEncoded: false))",
            ""
        ]
        if let testDestination {
            logLines.append("testDestination=\(testDestination)")
            logLines.append("")
        }

        for step in steps {
            let result: VerifyCommandResult
            do {
                result = try runner.run(command: step.command, in: root)
            } catch {
                result = VerifyCommandResult(exitCode: 127, stderr: "runner-error: \(error)")
            }

            logLines += logEntry(for: step, result: result)

            if result.exitCode != 0 {
                let summary = "Verify failed at \(step.kind.rawValue) (\(step.classification.rawValue))"
                try writeArtifact(
                    bundle: bundle,
                    status: "failed",
                    exitCode: 4,
                    summary: summary,
                    failureCode: step.classification.rawValue,
                    failedStep: step.kind.rawValue,
                    artifacts: artifactList,
                    stdout: logLines.joined(separator: "\n") + "\n"
                )
                BosStateStore.updateSummary(
                    projectRoot: root,
                    kind: .verify,
                    status: "failed",
                    message: summary
                )
                throw VerifyEngineError.commandFailed(
                    classification: step.classification,
                    step: step.kind,
                    exitCode: result.exitCode,
                    artifacts: artifactList
                )
            }
        }

        let summary = "Verify pipeline passed (tuist install/generate + xcodebuild build/test)"
        try writeArtifact(
            bundle: bundle,
            status: "success",
            exitCode: 0,
            summary: summary,
            failureCode: nil,
            failedStep: nil,
            artifacts: artifactList,
            stdout: logLines.joined(separator: "\n") + "\n"
        )
        BosStateStore.updateSummary(
            projectRoot: root,
            kind: .verify,
            status: "success",
            message: summary
        )

        return VerifyResult(artifacts: artifactList, summary: summary)
    }
}

extension VerifyEngine {
    private struct StepSpec {
        let kind: VerifyStep
        let classification: VerifyFailureCode
        let command: [String]
    }

    private struct VerifyPolicy {
        let buildScheme: String
    }

    private struct ArtifactPayload: Codable {
        let command: String
        let status: String
        let exitCode: Int
        let summary: String
        let failureCode: String?
        let failedStep: String?
        let artifacts: [String]
    }

    private func verifyPolicy(for profile: Profile, projectRoot: URL) -> VerifyPolicy {
        let buildScheme = ProjectBuildSupport.resolveBuildScheme(
            projectRoot: projectRoot,
            profileName: profile.name
        )
        return VerifyPolicy(buildScheme: buildScheme)
    }

    private func makeSteps(policy: VerifyPolicy, testDestination: String?) -> [StepSpec] {
        let signingOverrides = [
            "CODE_SIGNING_ALLOWED=NO",
            "CODE_SIGNING_REQUIRED=NO"
        ]

        var testCommand = ["xcodebuild", "test", "-scheme", policy.buildScheme]
        if let testDestination, !testDestination.isEmpty {
            testCommand.append(contentsOf: ["-destination", testDestination])
        }
        testCommand.append(contentsOf: signingOverrides)
        return [
            StepSpec(kind: .tuistInstall, classification: .toolchain, command: ["tuist", "install"]),
            StepSpec(kind: .tuistGenerate, classification: .generation, command: ["tuist", "generate", "--no-open"]),
            StepSpec(
                kind: .xcodebuildBuild,
                classification: .build,
                command: ["xcodebuild", "build", "-scheme", policy.buildScheme] + signingOverrides
            ),
            StepSpec(kind: .xcodebuildTest, classification: .test, command: testCommand)
        ]
    }

    private static func detectPreferredSimulatorDestination() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["xcrun", "simctl", "list", "devices", "available", "-j"]

        let stdoutPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }

        let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        guard !data.isEmpty else { return nil }

        struct SimctlDeviceList: Decodable {
            struct Device: Decodable {
                let udid: String
                let name: String
                let state: String?
            }
            let devices: [String: [Device]]
        }

        guard let list = try? JSONDecoder().decode(SimctlDeviceList.self, from: data) else {
            return nil
        }

        let candidates = list.devices.values
            .flatMap { $0 }
            .filter { $0.name.hasPrefix("iPhone") }
            .sorted { lhs, rhs in
                let lhsBooted = lhs.state == "Booted"
                let rhsBooted = rhs.state == "Booted"
                if lhsBooted != rhsBooted {
                    return lhsBooted
                }
                if lhs.name != rhs.name {
                    return lhs.name < rhs.name
                }
                return lhs.udid < rhs.udid
            }

        guard let selected = candidates.first else { return nil }
        return "id=\(selected.udid)"
    }
    private func logEntry(for step: StepSpec, result: VerifyCommandResult) -> [String] {
        var lines = [
            "[\(RuntimeSupport.isoNow())] step=\(step.kind.rawValue)",
            "$ \(step.command.joined(separator: " "))",
            "exit=\(result.exitCode)"
        ]
        if !result.stdout.isEmpty {
            lines += ["stdout:", result.stdout]
        }
        if !result.stderr.isEmpty {
            lines += ["stderr:", result.stderr]
        }
        lines.append("")
        return lines
    }

    private func writeArtifact(
        bundle: AdapterArtifactBundle,
        status: String,
        exitCode: Int,
        summary: String,
        failureCode: String?,
        failedStep: String?,
        artifacts: [String],
        stdout: String
    ) throws {
        _ = try AdapterArtifacts.write(
            bundle: bundle,
            envelope: AdapterRunEnvelope(
                command: "verify",
                status: status,
                exitCode: exitCode,
                summary: summary,
                payload: ArtifactPayload(
                    command: "verify",
                    status: status,
                    exitCode: exitCode,
                    summary: summary,
                    failureCode: failureCode,
                    failedStep: failedStep,
                    artifacts: artifacts
                )
            ),
            stdout: stdout,
            stderr: ""
        )
    }
}
