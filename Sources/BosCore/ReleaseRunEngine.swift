import Foundation

public enum ReleaseRunStage: String, Codable, Sendable, Equatable {
    case build
    case beta
    case release
    case submit
}

public enum ReleaseRunFailureCode: String, Codable, Sendable, Equatable {
    case preflight = "E-PREFLIGHT"
    case generation = "E-GENERATION"
    case workspace = "E-WORKSPACE"
    case build = "E-BUILD"
    case upload = "E-UPLOAD"
    case submit = "E-SUBMIT"
}

public enum ReleaseRunStep: String, Codable, Sendable, Equatable {
    case releaseInit = "release-init"
    case releaseCheck = "release-check"
    case tuistInstall = "tuist-install"
    case tuistGenerate = "tuist-generate"
    case workspaceResolve = "workspace-resolve"
    case fastlaneBuild = "fastlane-build"
    case fastlaneBeta = "fastlane-beta"
    case fastlaneRelease = "fastlane-release"
    case fastlaneSubmit = "fastlane-submit"
}

public protocol ReleaseRunCommandRunning: Sendable {
    func run(command: [String], in workingDirectory: URL, environment: [String: String]) throws -> ReleaseRunCommandResult
}

public struct ReleaseRunCommandResult: Sendable, Equatable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

    public init(exitCode: Int32, stdout: String = "", stderr: String = "") {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }
}

public protocol ReleaseCheckPerforming: Sendable {
    func releaseCheck(request: ReleaseCheckRequest) throws -> ReleaseCheckResult
}

extension ReleaseCheckEngine: ReleaseCheckPerforming {}

public struct ReleaseRunRequest: Sendable {
    public let projectRoot: URL
    public let blueprint: Blueprint
    public let profile: Profile
    public let environment: [String: String]
    public let stage: ReleaseRunStage
    public let allowSigningWrite: Bool

    public init(
        projectRoot: URL,
        blueprint: Blueprint,
        profile: Profile,
        environment: [String: String],
        stage: ReleaseRunStage,
        allowSigningWrite: Bool = false
    ) {
        self.projectRoot = projectRoot
        self.blueprint = blueprint
        self.profile = profile
        self.environment = environment
        self.stage = stage
        self.allowSigningWrite = allowSigningWrite
    }
}

public struct ReleaseRunResult: Sendable, Equatable {
    public let artifacts: [String]
    public let summary: String
    public let stage: ReleaseRunStage
    public let ipaPath: String

    public init(
        artifacts: [String],
        summary: String,
        stage: ReleaseRunStage,
        ipaPath: String
    ) {
        self.artifacts = artifacts
        self.summary = summary
        self.stage = stage
        self.ipaPath = ipaPath
    }
}

public enum ReleaseRunEngineError: Error, Equatable {
    case failed(
        classification: ReleaseRunFailureCode,
        step: ReleaseRunStep,
        summary: String,
        exitCode: Int32,
        artifacts: [String]
    )
}

public struct ReleaseRunEngine: Sendable {
    private let runner: any ReleaseRunCommandRunning
    private let releaseChecker: any ReleaseCheckPerforming
    private let releaseInitEngine: ReleaseInitEngine

    public init(
        runner: any ReleaseRunCommandRunning,
        releaseChecker: any ReleaseCheckPerforming,
        releaseInitEngine: ReleaseInitEngine = .init()
    ) {
        self.runner = runner
        self.releaseChecker = releaseChecker
        self.releaseInitEngine = releaseInitEngine
    }

    public func run(request: ReleaseRunRequest) throws -> ReleaseRunResult {
        let root = request.projectRoot.standardizedFileURL
        defer { ProjectBuildSupport.cleanupGeneratedProjectArtifacts(at: root) }

        let effectiveEnvironment = ReleaseEnvironment.effectiveEnvironment(
            profile: request.profile,
            environment: request.environment
        )
        let sanitizedEnvironment = effectiveEnvironment
        let scheme = ProjectBuildSupport.resolveBuildScheme(
            projectRoot: root,
            profileName: request.profile.name
        )
        let artifactsDir = try RuntimeArtifacts.makeDirectory(for: "release-run", projectRoot: root)
        let stamp = RuntimeSupport.timestamp()
        let jsonPath = artifactsDir.appending(path: "release-run-\(stamp).json")
        let logPath = artifactsDir.appending(path: "release-run-\(stamp).log")
        let buildOutputDir = artifactsDir.appending(path: "ipa-\(stamp)")
        let ipaFileName = "\(AppRegistrationSupport.slug(scheme, fallback: "app")).ipa"
        let ipaPath = buildOutputDir.appending(path: ipaFileName)
        let artifactList = [
            jsonPath.path(percentEncoded: false),
            logPath.path(percentEncoded: false),
            ipaPath.path(percentEncoded: false)
        ]

        var records: [StepRecord] = []
        var logLines: [String] = [
            "# bos release-run",
            "profile=\(request.profile.name)",
            "projectRoot=\(root.path(percentEncoded: false))",
            "stage=\(request.stage.rawValue)",
            "signingMode=\(request.allowSigningWrite ? ReleaseCheckMode.syncCerts.rawValue : ReleaseCheckMode.readonlyCerts.rawValue)",
            "scheme=\(scheme)",
            ""
        ]

        do {
            _ = try releaseInitEngine.releaseInit(
                request: ReleaseInitRequest(
                    projectRoot: root,
                    blueprint: request.blueprint,
                    profile: request.profile,
                    environment: effectiveEnvironment
                )
            )
            let record = StepRecord(
                step: .releaseInit,
                classification: .preflight,
                status: "success",
                command: nil,
                exitCode: 0,
                summary: "fastlane scaffold ensured"
            )
            records.append(record)
            logLines += logEntry(for: record)
        } catch let error as ReleaseInitEngineError {
            let summary = releaseInitSummary(error)
            throw try fail(
                jsonPath: jsonPath,
                logPath: logPath,
                projectRoot: root,
                records: &records,
                logLines: &logLines,
                stage: request.stage,
                step: .releaseInit,
                classification: .preflight,
                summary: summary,
                exitCode: 1,
                ipaPath: ipaPath.path(percentEncoded: false),
                artifacts: artifactList
            )
        }

        do {
            let signingMode: ReleaseCheckMode = request.allowSigningWrite ? .syncCerts : .readonlyCerts
            let result = try releaseChecker.releaseCheck(
                request: ReleaseCheckRequest(
                    projectRoot: root,
                    profile: request.profile,
                    environment: effectiveEnvironment,
                    mode: signingMode
                )
            )
            let record = StepRecord(
                step: .releaseCheck,
                classification: .preflight,
                status: "success",
                command: nil,
                exitCode: 0,
                summary: result.summary
            )
            records.append(record)
            logLines += logEntry(for: record)
        } catch let error as ReleaseCheckEngineError {
            let failure: ReleaseRunEngineError
            switch error {
            case .failed(_, _, let summary, let exitCode, _):
                failure = try fail(
                    jsonPath: jsonPath,
                    logPath: logPath,
                    projectRoot: root,
                    records: &records,
                    logLines: &logLines,
                    stage: request.stage,
                    step: .releaseCheck,
                    classification: .preflight,
                    summary: summary,
                    exitCode: exitCode,
                    ipaPath: ipaPath.path(percentEncoded: false),
                    artifacts: artifactList
                )
            }
            throw failure
        }

        let commandEnvironment = makeCommandEnvironment(from: effectiveEnvironment)
        let generationSteps: [(ReleaseRunStep, [String])] = [
            (.tuistInstall, ["tuist", "install"]),
            (.tuistGenerate, ["tuist", "generate", "--no-open"])
        ]
        for (step, command) in generationSteps {
            let result = try runCommand(command: command, workingDirectory: root, environment: commandEnvironment)
            let record = makeCommandRecord(
                step: step,
                classification: .generation,
                command: command,
                result: result,
                successSummary: "\(step.rawValue) completed",
                sanitizedEnvironment: sanitizedEnvironment
            )
            records.append(record)
            logLines += logEntry(
                for: record,
                stdout: SecretRedactionSupport.redact(
                    result.stdout,
                    environment: sanitizedEnvironment,
                    keys: ["ASC_KEY_P8_BASE64", "MATCH_PASSWORD"]
                ),
                stderr: SecretRedactionSupport.redact(
                    result.stderr,
                    environment: sanitizedEnvironment,
                    keys: ["ASC_KEY_P8_BASE64", "MATCH_PASSWORD"]
                )
            )
            if result.exitCode != 0 {
                throw try fail(
                    jsonPath: jsonPath,
                    logPath: logPath,
                    projectRoot: root,
                    records: &records,
                    logLines: &logLines,
                    stage: request.stage,
                    step: step,
                    classification: .generation,
                    summary: record.summary,
                    exitCode: result.exitCode,
                    ipaPath: ipaPath.path(percentEncoded: false),
                    appendRecord: false,
                    artifacts: artifactList
                )
            }
        }

        guard let workspacePath = ProjectBuildSupport.resolveWorkspacePath(projectRoot: root) else {
            throw try fail(
                jsonPath: jsonPath,
                logPath: logPath,
                projectRoot: root,
                records: &records,
                logLines: &logLines,
                stage: request.stage,
                step: .workspaceResolve,
                classification: .workspace,
                summary: "generated workspace not found after `tuist generate`",
                exitCode: 1,
                ipaPath: ipaPath.path(percentEncoded: false),
                artifacts: artifactList
            )
        }

        let workspaceRecord = StepRecord(
            step: .workspaceResolve,
            classification: .workspace,
            status: "success",
            command: nil,
            exitCode: 0,
            summary: "resolved workspace \(workspacePath.lastPathComponent)"
        )
        records.append(workspaceRecord)
        logLines += logEntry(for: workspaceRecord)

        var buildEnvironment = commandEnvironment
        buildEnvironment["BOS_WORKSPACE_PATH"] = workspacePath.path(percentEncoded: false)
        buildEnvironment["BOS_SCHEME"] = scheme
        buildEnvironment["BOS_IPA_OUTPUT_DIR"] = buildOutputDir.path(percentEncoded: false)
        buildEnvironment["BOS_IPA_OUTPUT_NAME"] = ipaFileName

        let buildResult = try runCommand(
            command: ["fastlane", "ios", "build"],
            workingDirectory: root,
            environment: buildEnvironment
        )
        let buildRecord = makeCommandRecord(
            step: .fastlaneBuild,
            classification: .build,
            command: ["fastlane", "ios", "build"],
            result: buildResult,
            successSummary: "fastlane build completed",
            sanitizedEnvironment: sanitizedEnvironment
        )
        records.append(buildRecord)
        logLines += logEntry(
            for: buildRecord,
            stdout: SecretRedactionSupport.redact(
                buildResult.stdout,
                environment: sanitizedEnvironment,
                keys: ["ASC_KEY_P8_BASE64", "MATCH_PASSWORD"]
            ),
            stderr: SecretRedactionSupport.redact(
                buildResult.stderr,
                environment: sanitizedEnvironment,
                keys: ["ASC_KEY_P8_BASE64", "MATCH_PASSWORD"]
            )
        )
        if buildResult.exitCode != 0 {
            throw try fail(
                jsonPath: jsonPath,
                logPath: logPath,
                projectRoot: root,
                records: &records,
                logLines: &logLines,
                stage: request.stage,
                step: .fastlaneBuild,
                classification: .build,
                summary: buildRecord.summary,
                exitCode: buildResult.exitCode,
                ipaPath: ipaPath.path(percentEncoded: false),
                appendRecord: false,
                artifacts: artifactList
            )
        }

        if !FileManager.default.fileExists(atPath: ipaPath.path(percentEncoded: false)) {
            throw try fail(
                jsonPath: jsonPath,
                logPath: logPath,
                projectRoot: root,
                records: &records,
                logLines: &logLines,
                stage: request.stage,
                step: .fastlaneBuild,
                classification: .build,
                summary: "expected IPA at \(ipaPath.path(percentEncoded: false)) after fastlane build",
                exitCode: 1,
                ipaPath: ipaPath.path(percentEncoded: false),
                artifacts: artifactList
            )
        }

        let uploadStep = uploadStep(for: request.stage)
        if let uploadStep {
            var uploadEnvironment = buildEnvironment
            uploadEnvironment["IPA_PATH"] = ipaPath.path(percentEncoded: false)
            let uploadResult = try runCommand(
                command: uploadStep.command,
                workingDirectory: root,
                environment: uploadEnvironment
            )
            let uploadRecord = makeCommandRecord(
                step: uploadStep.step,
                classification: uploadStep.classification,
                command: uploadStep.command,
                result: uploadResult,
                successSummary: uploadStep.successSummary,
                sanitizedEnvironment: sanitizedEnvironment
            )
            records.append(uploadRecord)
            logLines += logEntry(
                for: uploadRecord,
                stdout: SecretRedactionSupport.redact(
                    uploadResult.stdout,
                    environment: sanitizedEnvironment,
                    keys: ["ASC_KEY_P8_BASE64", "MATCH_PASSWORD"]
                ),
                stderr: SecretRedactionSupport.redact(
                    uploadResult.stderr,
                    environment: sanitizedEnvironment,
                    keys: ["ASC_KEY_P8_BASE64", "MATCH_PASSWORD"]
                )
            )
            if uploadResult.exitCode != 0 {
                throw try fail(
                    jsonPath: jsonPath,
                    logPath: logPath,
                    projectRoot: root,
                    records: &records,
                    logLines: &logLines,
                    stage: request.stage,
                    step: uploadStep.step,
                    classification: uploadStep.classification,
                    summary: uploadRecord.summary,
                    exitCode: uploadResult.exitCode,
                    ipaPath: ipaPath.path(percentEncoded: false),
                    appendRecord: false,
                    artifacts: artifactList
                )
            }
        }

        let summary = "release-run passed (\(request.stage.rawValue))"
        try RuntimeSupport.writeFile(to: logPath, content: logLines.joined(separator: "\n") + "\n")
        try writeArtifact(
            to: jsonPath,
            status: "success",
            exitCode: 0,
            summary: summary,
            stage: request.stage,
            failureCode: nil,
            failedStep: nil,
            records: records,
            ipaPath: ipaPath.path(percentEncoded: false),
            artifacts: artifactList
        )
        BosStateStore.updateSummary(
            projectRoot: root,
            kind: .releaseRun,
            status: "success",
            message: summary
        )

        return ReleaseRunResult(
            artifacts: artifactList,
            summary: summary,
            stage: request.stage,
            ipaPath: ipaPath.path(percentEncoded: false)
        )
    }
}

private extension ReleaseRunEngine {
    struct StepRecord: Codable, Equatable {
        let step: ReleaseRunStep
        let classification: ReleaseRunFailureCode
        let status: String
        let command: [String]?
        let exitCode: Int?
        let summary: String
    }

    struct ArtifactPayload: Codable {
        let command: String
        let status: String
        let exitCode: Int
        let summary: String
        let stage: String
        let failureCode: String?
        let failedStep: String?
        let ipaPath: String
        let steps: [StepRecord]
        let artifacts: [String]
    }

    struct UploadStep {
        let step: ReleaseRunStep
        let classification: ReleaseRunFailureCode
        let command: [String]
        let successSummary: String
    }

    func uploadStep(for stage: ReleaseRunStage) -> UploadStep? {
        switch stage {
        case .build:
            return nil
        case .beta:
            return UploadStep(
                step: .fastlaneBeta,
                classification: .upload,
                command: ["fastlane", "ios", "beta"],
                successSummary: "TestFlight upload completed"
            )
        case .release:
            return UploadStep(
                step: .fastlaneRelease,
                classification: .upload,
                command: ["fastlane", "ios", "release"],
                successSummary: "App Store upload completed"
            )
        case .submit:
            return UploadStep(
                step: .fastlaneSubmit,
                classification: .submit,
                command: ["fastlane", "ios", "submit"],
                successSummary: "App Store submission completed"
            )
        }
    }

    func releaseInitSummary(_ error: ReleaseInitEngineError) -> String {
        switch error {
        case .missingRequiredEnvironment(let keys):
            return "release-init failed: missing required environment: \(keys.joined(separator: ", "))"
        case .invalidEnvironmentFormat(let details):
            return "release-init failed: invalid environment format: \(details.joined(separator: ", "))"
        case .laneParseFailed(let path):
            return "release-init failed: could not parse required lanes from \(path)"
        }
    }

    func makeCommandEnvironment(from environment: [String: String]) -> [String: String] {
        var merged = environment
        merged["FASTLANE_DISABLE_COLORS"] = "1"
        merged["FASTLANE_SKIP_UPDATE_CHECK"] = "1"
        merged["FASTLANE_HIDE_TIMESTAMP"] = "1"
        merged["CI"] = "1"
        return merged
    }

    func runCommand(
        command: [String],
        workingDirectory: URL,
        environment: [String: String]
    ) throws -> ReleaseRunCommandResult {
        do {
            return try runner.run(command: command, in: workingDirectory, environment: environment)
        } catch {
            return ReleaseRunCommandResult(
                exitCode: 127,
                stdout: "",
                stderr: "runner-error: \(error)"
            )
        }
    }

    func makeCommandRecord(
        step: ReleaseRunStep,
        classification: ReleaseRunFailureCode,
        command: [String],
        result: ReleaseRunCommandResult,
        successSummary: String,
        sanitizedEnvironment: [String: String]
    ) -> StepRecord {
        let summary: String
        if result.exitCode == 0 {
            summary = successSummary
        } else {
            let details = SecretRedactionSupport.redact(
                result.stderr.isEmpty ? result.stdout : result.stderr,
                environment: sanitizedEnvironment,
                keys: ["ASC_KEY_P8_BASE64", "MATCH_PASSWORD"]
            )
            summary = details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "command failed"
                : truncate(details)
        }
        return StepRecord(
            step: step,
            classification: classification,
            status: result.exitCode == 0 ? "success" : "failed",
            command: command,
            exitCode: Int(result.exitCode),
            summary: summary
        )
    }

    func logEntry(
        for record: StepRecord,
        stdout: String? = nil,
        stderr: String? = nil
    ) -> [String] {
        var lines: [String] = [
            "[\(RuntimeSupport.isoNow())] step=\(record.step.rawValue)",
            "classification=\(record.classification.rawValue)",
            "status=\(record.status)"
        ]
        if let command = record.command {
            lines.append("$ \(command.joined(separator: " "))")
        }
        if let exitCode = record.exitCode {
            lines.append("exit=\(exitCode)")
        }
        lines.append("summary=\(record.summary)")
        if let stdout, !stdout.isEmpty {
            lines.append("stdout:")
            lines.append(stdout)
        }
        if let stderr, !stderr.isEmpty {
            lines.append("stderr:")
            lines.append(stderr)
        }
        lines.append("")
        return lines
    }

    func fail(
        jsonPath: URL,
        logPath: URL,
        projectRoot: URL,
        records: inout [StepRecord],
        logLines: inout [String],
        stage: ReleaseRunStage,
        step: ReleaseRunStep,
        classification: ReleaseRunFailureCode,
        summary: String,
        exitCode: Int32,
        ipaPath: String,
        appendRecord: Bool = true,
        artifacts: [String]
    ) throws -> ReleaseRunEngineError {
        if appendRecord {
            let record = StepRecord(
                step: step,
                classification: classification,
                status: "failed",
                command: nil,
                exitCode: Int(exitCode),
                summary: summary
            )
            records.append(record)
            logLines += logEntry(for: record)
        }
        try RuntimeSupport.writeFile(to: logPath, content: logLines.joined(separator: "\n") + "\n")
        try writeArtifact(
            to: jsonPath,
            status: "failed",
            exitCode: 9,
            summary: summary,
            stage: stage,
            failureCode: classification,
            failedStep: step,
            records: records,
            ipaPath: ipaPath,
            artifacts: artifacts
        )
        BosStateStore.updateSummary(
            projectRoot: projectRoot,
            kind: .releaseRun,
            status: "failed",
            message: summary
        )
        return ReleaseRunEngineError.failed(
            classification: classification,
            step: step,
            summary: summary,
            exitCode: exitCode,
            artifacts: artifacts
        )
    }

    func writeArtifact(
        to path: URL,
        status: String,
        exitCode: Int,
        summary: String,
        stage: ReleaseRunStage,
        failureCode: ReleaseRunFailureCode?,
        failedStep: ReleaseRunStep?,
        records: [StepRecord],
        ipaPath: String,
        artifacts: [String]
    ) throws {
        let payload = ArtifactPayload(
            command: "release-run",
            status: status,
            exitCode: exitCode,
            summary: summary,
            stage: stage.rawValue,
            failureCode: failureCode?.rawValue,
            failedStep: failedStep?.rawValue,
            ipaPath: ipaPath,
            steps: records,
            artifacts: artifacts
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        try RuntimeSupport.writeFile(to: path, data: data)
    }

    func truncate(_ text: String, limit: Int = 400) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        let end = trimmed.index(trimmed.startIndex, offsetBy: limit)
        return "\(trimmed[..<end])..."
    }
}
