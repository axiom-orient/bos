import Foundation

public protocol VerifyCommandRunning {
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
    public let profile: ProfileV1

    public init(projectRoot: URL, profile: ProfileV1) {
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

public struct VerifyEngine {
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
        defer { try? cleanupGeneratedProjectArtifacts(at: root) }

        let policy = verifyPolicy(for: request.profile, projectRoot: root)
        let testDestination = simulatorDestinationResolver()
        let steps = makeSteps(policy: policy, testDestination: testDestination)

        let artifactsDir = try RuntimeArtifacts.makeDirectory(for: "verify", projectRoot: root)

        let stamp = RuntimeSupport.timestamp()
        let logPath = artifactsDir.appending(path: "verify-\(stamp).log")
        let jsonPath = artifactsDir.appending(path: "verify-\(stamp).json")
        let artifactList = [jsonPath.path(percentEncoded: false), logPath.path(percentEncoded: false)]

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

            appendLog(lines: &logLines, step: step, result: result)

            if result.exitCode != 0 {
                let summary = "Verify failed at \(step.kind.rawValue) (\(step.classification.rawValue))"
                try RuntimeSupport.writeFile(to: logPath, content: logLines.joined(separator: "\n") + "\n")
                try writeArtifact(
                    to: jsonPath,
                    status: "failed",
                    exitCode: 4,
                    summary: summary,
                    failureCode: step.classification.rawValue,
                    failedStep: step.kind.rawValue,
                    artifacts: artifactList
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
        try RuntimeSupport.writeFile(to: logPath, content: logLines.joined(separator: "\n") + "\n")
        try writeArtifact(
            to: jsonPath,
            status: "success",
            exitCode: 0,
            summary: summary,
            failureCode: nil,
            failedStep: nil,
            artifacts: artifactList
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

    private func verifyPolicy(for profile: ProfileV1, projectRoot: URL) -> VerifyPolicy {
        let buildScheme = resolveBuildScheme(projectRoot: projectRoot, profile: profile)
        return VerifyPolicy(buildScheme: buildScheme)
    }

    private func resolveBuildScheme(projectRoot: URL, profile: ProfileV1) -> String {
        let appProjectPath = projectRoot.appending(path: "Projects/App/Project.swift")
        if let appScheme = readAppScheme(from: appProjectPath) {
            return appScheme
        }
        return "\(sanitizeModuleName(profile.name))App"
    }

    private func readAppScheme(from projectFile: URL) -> String? {
        guard let text = try? String(contentsOf: projectFile, encoding: .utf8) else {
            return nil
        }
        let pattern = #"let\s+appName\s*=\s*"([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: fullRange),
              match.numberOfRanges > 1,
              let nameRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        let name = String(text[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    private func sanitizeModuleName(_ raw: String) -> String {
        NameNormalizer.pascalCase(raw, fallback: "App")
    }

    private func makeSteps(policy: VerifyPolicy, testDestination: String?) -> [StepSpec] {
        var testCommand = ["xcodebuild", "test", "-scheme", policy.buildScheme]
        if let testDestination, !testDestination.isEmpty {
            testCommand.append(contentsOf: ["-destination", testDestination])
        }
        return [
            StepSpec(kind: .tuistInstall, classification: .toolchain, command: ["tuist", "install"]),
            StepSpec(kind: .tuistGenerate, classification: .generation, command: ["tuist", "generate", "--no-open"]),
            StepSpec(kind: .xcodebuildBuild, classification: .build, command: ["xcodebuild", "build", "-scheme", policy.buildScheme]),
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

    private func cleanupGeneratedProjectArtifacts(at root: URL) throws {
        let fm = FileManager.default

        let topLevel = try fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        for item in topLevel {
            let name = item.lastPathComponent
            if item.pathExtension == "xcworkspace" || name.hasPrefix("TemporaryDirectory.") {
                try? fm.removeItem(at: item)
            }
            if name == "swift-generated-sources" || (name.hasPrefix("_") && name.hasSuffix(".lock")) {
                try? fm.removeItem(at: item)
            }
        }

        let projectsRoot = root.appending(path: "Projects")
        if fm.fileExists(atPath: projectsRoot.path(percentEncoded: false)),
           let enumerator = fm.enumerator(
               at: projectsRoot,
               includingPropertiesForKeys: nil,
               options: [.skipsHiddenFiles]
           ) {
            for case let url as URL in enumerator {
                let name = url.lastPathComponent
                if url.pathExtension == "xcodeproj" || name == "Derived" {
                    try? fm.removeItem(at: url)
                    enumerator.skipDescendants()
                }
            }
        }

        let tuistBuild = root.appending(path: "Tuist/.build")
        if fm.fileExists(atPath: tuistBuild.path(percentEncoded: false)) {
            try? fm.removeItem(at: tuistBuild)
        }

        let tuistResolved = root.appending(path: "Tuist/Package.resolved")
        if fm.fileExists(atPath: tuistResolved.path(percentEncoded: false)) {
            try? fm.removeItem(at: tuistResolved)
        }
    }

    private func appendLog(lines: inout [String], step: StepSpec, result: VerifyCommandResult) {
        lines.append("[\(RuntimeSupport.isoNow())] step=\(step.kind.rawValue)")
        lines.append("$ \(step.command.joined(separator: " "))")
        lines.append("exit=\(result.exitCode)")
        if !result.stdout.isEmpty {
            lines.append("stdout:")
            lines.append(result.stdout)
        }
        if !result.stderr.isEmpty {
            lines.append("stderr:")
            lines.append(result.stderr)
        }
        lines.append("")
    }

    private func writeArtifact(
        to path: URL,
        status: String,
        exitCode: Int,
        summary: String,
        failureCode: String?,
        failedStep: String?,
        artifacts: [String]
    ) throws {
        let payload = ArtifactPayload(
            command: "verify",
            status: status,
            exitCode: exitCode,
            summary: summary,
            failureCode: failureCode,
            failedStep: failedStep,
            artifacts: artifacts
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        try RuntimeSupport.writeFile(to: path, data: data)
    }
}
