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
    case metadataValidate = "metadata-validate"
    case screenshotsValidate = "screenshots-validate"
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
    public let releasePolicy: ReleasePolicy
    public let screenshotPlanPath: URL?
    public let screenshotPlan: ScreenshotPlan?

    public init(
        projectRoot: URL,
        blueprint: Blueprint,
        profile: Profile,
        environment: [String: String],
        stage: ReleaseRunStage,
        allowSigningWrite: Bool = false,
        releasePolicy: ReleasePolicy = .defaultPolicy(),
        screenshotPlanPath: URL? = nil,
        screenshotPlan: ScreenshotPlan? = nil
    ) {
        self.projectRoot = projectRoot
        self.blueprint = blueprint
        self.profile = profile
        self.environment = environment
        self.stage = stage
        self.allowSigningWrite = allowSigningWrite
        self.releasePolicy = releasePolicy
        self.screenshotPlanPath = screenshotPlanPath
        self.screenshotPlan = screenshotPlan
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

public protocol ReleaseRunMetadataValidating: Sendable {
    func validate(projectRoot: URL, profile: Profile, environment: [String: String]) throws -> String
}

public protocol ReleaseRunScreenshotsValidating: Sendable {
    func validate(projectRoot: URL, planPath: URL, plan: ScreenshotPlan) throws -> String
}

struct ReleaseRunValidationFailure: Error {
    let summary: String
}

public struct LiveReleaseRunMetadataValidator: ReleaseRunMetadataValidating {
    private let engine: MetadataEngine

    public init(engine: MetadataEngine = .init()) {
        self.engine = engine
    }

    public func validate(projectRoot: URL, profile: Profile, environment: [String: String]) throws -> String {
        do {
            let result = try engine.run(
                request: MetadataRequest(
                    projectRoot: projectRoot,
                    profile: profile,
                    environment: environment,
                    subcommand: .validate
                )
            )
            return result.summary
        } catch let error as MetadataEngineError {
            switch error {
            case .failed(_, let summary, _, _, _, _):
                throw ReleaseRunValidationFailure(summary: summary)
            }
        }
    }
}

public struct LiveReleaseRunScreenshotsValidator: ReleaseRunScreenshotsValidating {
    private let engine: ScreenshotsEngine

    public init(engine: ScreenshotsEngine = .init()) {
        self.engine = engine
    }

    public func validate(projectRoot: URL, planPath: URL, plan: ScreenshotPlan) throws -> String {
        do {
            let result = try engine.run(
                request: ScreenshotRequest(
                    projectRoot: projectRoot,
                    planPath: planPath,
                    plan: plan,
                    subcommand: .validate
                )
            )
            return result.summary
        } catch let error as ScreenshotsEngineError {
            switch error {
            case .failed(_, let summary, _, _, _, _, _, _, _, _, _):
                throw ReleaseRunValidationFailure(summary: summary)
            }
        }
    }
}

public struct ReleaseRunEngine: Sendable {
    private let runner: any ReleaseRunCommandRunning
    private let releaseChecker: any ReleaseCheckPerforming
    private let releaseInitEngine: ReleaseInitEngine
    private let metadataValidator: any ReleaseRunMetadataValidating
    private let screenshotsValidator: any ReleaseRunScreenshotsValidating

    public init(
        runner: any ReleaseRunCommandRunning,
        releaseChecker: any ReleaseCheckPerforming,
        releaseInitEngine: ReleaseInitEngine = .init(),
        metadataValidator: any ReleaseRunMetadataValidating = LiveReleaseRunMetadataValidator(),
        screenshotsValidator: any ReleaseRunScreenshotsValidating = LiveReleaseRunScreenshotsValidator()
    ) {
        self.runner = runner
        self.releaseChecker = releaseChecker
        self.releaseInitEngine = releaseInitEngine
        self.metadataValidator = metadataValidator
        self.screenshotsValidator = screenshotsValidator
    }

    public func run(request: ReleaseRunRequest) throws -> ReleaseRunResult {
        let root = request.projectRoot.standardizedFileURL
        defer { ProjectBuildSupport.cleanupGeneratedProjectArtifacts(at: root) }

        let effectiveEnvironment = ReleaseEnvironment.effectiveEnvironment(
            profile: request.profile,
            environment: request.environment
        )
        let commandEnvironment = makeCommandEnvironment(
            from: effectiveEnvironment,
            releasePolicy: request.releasePolicy
        )
        let sanitizedEnvironment = commandEnvironment
        let scheme = ProjectBuildSupport.resolveBuildScheme(
            projectRoot: root,
            profileName: request.profile.name
        )
        let stamp = RuntimeSupport.timestamp()
        let bundle = try AdapterArtifacts.makeBundle(command: "release-run", projectRoot: root, stamp: stamp)
        let buildOutputDir = bundle.directory.appending(path: "artifacts")
        let ipaFileName = "\(AppRegistrationSupport.slug(scheme, fallback: "app")).ipa"
        let ipaPath = buildOutputDir.appending(path: ipaFileName)
        let artifactList = bundle.artifacts + [ipaPath.path(percentEncoded: false)]
        let policySigningMode: ReleaseCheckMode = request.releasePolicy.signingMode == .syncCerts ? .syncCerts : .readonlyCerts
        let signingMode: ReleaseCheckMode = request.allowSigningWrite ? .syncCerts : policySigningMode
        let uploadStep = uploadStep(for: request.stage)
        let resumeState = resumableUploadState(
            projectRoot: root,
            stage: request.stage,
            signingMode: signingMode,
            uploadStep: uploadStep
        )

        var records: [StepRecord] = []
        var logLines: [String] = [
            "# bos release-run",
            "profile=\(request.profile.name)",
            "projectRoot=\(root.path(percentEncoded: false))",
            "stage=\(request.stage.rawValue)",
            "signingMode=\(signingMode.rawValue)",
            "scheme=\(scheme)",
            ""
        ]
        syncState(
            projectRoot: root,
            stage: request.stage,
            signingMode: signingMode,
            status: "running",
            summary: "release-run started (\(request.stage.rawValue))",
            records: records,
            nextStep: firstStep(for: request),
            failedStep: nil,
            failureCode: nil,
            artifactDirectory: bundle.directory.path(percentEncoded: false),
            ipaPath: resumeState?.ipaPath
        )

        if signingMode == .syncCerts, !request.allowSigningWrite {
            throw try fail(
                bundle: bundle,
                projectRoot: root,
                records: &records,
                logLines: &logLines,
                stage: request.stage,
                signingMode: signingMode,
                step: .releaseCheck,
                classification: .preflight,
                summary: "release policy defaultSigningMode=sync-certs requires --allow-signing-write",
                exitCode: 1,
                ipaPath: ipaPath.path(percentEncoded: false),
                artifacts: artifactList
            )
        }

        if shouldRunMetadataPreflight(for: request) {
            do {
                let localeSummary = try metadataLocalePreflightSummary(for: request)
                let validationSummary: String?
                if request.releasePolicy.submitRequirements.metadataValidation {
                    validationSummary = try metadataValidator.validate(
                        projectRoot: root,
                        profile: request.profile,
                        environment: effectiveEnvironment
                    )
                } else {
                    validationSummary = nil
                }
                let summary = [localeSummary, validationSummary]
                    .compactMap { $0 }
                    .joined(separator: "; ")
                let record = StepRecord(
                    step: .metadataValidate,
                    classification: .preflight,
                    status: "success",
                    command: nil,
                    exitCode: 0,
                    summary: summary
                )
                records.append(record)
                logLines += logEntry(for: record)
                syncState(
                    projectRoot: root,
                    stage: request.stage,
                    signingMode: signingMode,
                    status: "running",
                    summary: summary,
                    records: records,
                    nextStep: request.releasePolicy.submitRequirements.screenshotsValidation ? .screenshotsValidate : .releaseInit,
                    failedStep: nil,
                    failureCode: nil,
                    artifactDirectory: bundle.directory.path(percentEncoded: false),
                    ipaPath: resumeState?.ipaPath
                )
            } catch let error as ReleaseRunValidationFailure {
                throw try fail(
                    bundle: bundle,
                    projectRoot: root,
                    records: &records,
                    logLines: &logLines,
                    stage: request.stage,
                    signingMode: signingMode,
                    step: .metadataValidate,
                    classification: .preflight,
                    summary: error.summary,
                    exitCode: 1,
                    ipaPath: ipaPath.path(percentEncoded: false),
                    artifacts: artifactList
                )
            }
        }

        if request.stage == .submit, request.releasePolicy.submitRequirements.screenshotsValidation {
            guard let screenshotPlanPath = request.screenshotPlanPath,
                  let screenshotPlan = request.screenshotPlan else {
                throw try fail(
                    bundle: bundle,
                    projectRoot: root,
                    records: &records,
                    logLines: &logLines,
                    stage: request.stage,
                    signingMode: signingMode,
                    step: .screenshotsValidate,
                    classification: .preflight,
                    summary: "release policy requires screenshots validation before submit",
                    exitCode: 1,
                    ipaPath: ipaPath.path(percentEncoded: false),
                    artifacts: artifactList
                )
            }
            do {
                let localeSummary = try screenshotsLocalePreflightSummary(
                    requiredLocales: request.releasePolicy.requiredLocales,
                    plan: screenshotPlan
                )
                let validationSummary = try screenshotsValidator.validate(
                    projectRoot: root,
                    planPath: screenshotPlanPath,
                    plan: screenshotPlan
                )
                let summary = [localeSummary, validationSummary]
                    .compactMap { $0 }
                    .joined(separator: "; ")
                let record = StepRecord(
                    step: .screenshotsValidate,
                    classification: .preflight,
                    status: "success",
                    command: nil,
                    exitCode: 0,
                    summary: summary
                )
                records.append(record)
                logLines += logEntry(for: record)
                syncState(
                    projectRoot: root,
                    stage: request.stage,
                    signingMode: signingMode,
                    status: "running",
                    summary: summary,
                    records: records,
                    nextStep: .releaseInit,
                    failedStep: nil,
                    failureCode: nil,
                    artifactDirectory: bundle.directory.path(percentEncoded: false),
                    ipaPath: resumeState?.ipaPath
                )
            } catch let error as ReleaseRunValidationFailure {
                throw try fail(
                    bundle: bundle,
                    projectRoot: root,
                    records: &records,
                    logLines: &logLines,
                    stage: request.stage,
                    signingMode: signingMode,
                    step: .screenshotsValidate,
                    classification: .preflight,
                    summary: error.summary,
                    exitCode: 1,
                    ipaPath: ipaPath.path(percentEncoded: false),
                    artifacts: artifactList
                )
            }
        }

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
            syncState(
                projectRoot: root,
                stage: request.stage,
                signingMode: signingMode,
                status: "running",
                summary: record.summary,
                records: records,
                nextStep: .releaseCheck,
                failedStep: nil,
                failureCode: nil,
                artifactDirectory: bundle.directory.path(percentEncoded: false),
                ipaPath: resumeState?.ipaPath
            )
        } catch let error as ReleaseInitEngineError {
            let summary = releaseInitSummary(error)
            throw try fail(
                bundle: bundle,
                projectRoot: root,
                records: &records,
                logLines: &logLines,
                stage: request.stage,
                signingMode: signingMode,
                step: .releaseInit,
                classification: .preflight,
                summary: summary,
                exitCode: 1,
                ipaPath: ipaPath.path(percentEncoded: false),
                artifacts: artifactList
            )
        }

        do {
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
            syncState(
                projectRoot: root,
                stage: request.stage,
                signingMode: signingMode,
                status: "running",
                summary: result.summary,
                records: records,
                nextStep: resumeState == nil ? .tuistInstall : uploadStep?.step,
                failedStep: nil,
                failureCode: nil,
                artifactDirectory: bundle.directory.path(percentEncoded: false),
                ipaPath: resumeState?.ipaPath
            )
        } catch let error as ReleaseCheckEngineError {
            let failure: ReleaseRunEngineError
            switch error {
            case .failed(_, _, let summary, let exitCode, _):
                failure = try fail(
                    bundle: bundle,
                    projectRoot: root,
                    records: &records,
                    logLines: &logLines,
                    stage: request.stage,
                    signingMode: signingMode,
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
        if let resumeState, let uploadStep {
            let resumeIPAPath = resumeState.ipaPath ?? ipaPath.path(percentEncoded: false)
            let reusedIPARecord = StepRecord(
                step: .fastlaneBuild,
                classification: .build,
                status: "success",
                command: nil,
                exitCode: 0,
                summary: "reusing existing IPA from \(resumeIPAPath)"
            )
            records.append(reusedIPARecord)
            logLines += logEntry(for: reusedIPARecord)
            syncState(
                projectRoot: root,
                stage: request.stage,
                signingMode: signingMode,
                status: "running",
                summary: reusedIPARecord.summary,
                records: records,
                nextStep: uploadStep.step,
                failedStep: nil,
                failureCode: nil,
                artifactDirectory: bundle.directory.path(percentEncoded: false),
                ipaPath: resumeIPAPath
            )

            var uploadEnvironment = commandEnvironment
            uploadEnvironment["IPA_PATH"] = resumeIPAPath
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
                    bundle: bundle,
                    projectRoot: root,
                    records: &records,
                    logLines: &logLines,
                    stage: request.stage,
                    signingMode: signingMode,
                    step: uploadStep.step,
                    classification: uploadStep.classification,
                    summary: uploadRecord.summary,
                    exitCode: uploadResult.exitCode,
                    ipaPath: resumeIPAPath,
                    appendRecord: false,
                    artifacts: bundle.artifacts + [resumeIPAPath]
                )
            }

            let summary = "release-run passed (\(request.stage.rawValue))"
            let resumedArtifacts = bundle.artifacts + [resumeIPAPath]
            try writeArtifact(
                bundle: bundle,
                status: "success",
                exitCode: 0,
                summary: summary,
                stage: request.stage,
                failureCode: nil,
                failedStep: nil,
                records: records,
                ipaPath: resumeIPAPath,
                artifacts: resumedArtifacts
            )
            syncState(
                projectRoot: root,
                stage: request.stage,
                signingMode: signingMode,
                status: "success",
                summary: summary,
                records: records,
                nextStep: nil,
                failedStep: nil,
                failureCode: nil,
                artifactDirectory: bundle.directory.path(percentEncoded: false),
                ipaPath: resumeIPAPath
            )

            return ReleaseRunResult(
                artifacts: resumedArtifacts,
                summary: summary,
                stage: request.stage,
                ipaPath: resumeIPAPath
            )
        }

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
            syncState(
                projectRoot: root,
                stage: request.stage,
                signingMode: signingMode,
                status: "running",
                summary: record.summary,
                records: records,
                nextStep: step == .tuistInstall ? .tuistGenerate : .workspaceResolve,
                failedStep: nil,
                failureCode: nil,
                artifactDirectory: bundle.directory.path(percentEncoded: false),
                ipaPath: nil
            )
            if result.exitCode != 0 {
                throw try fail(
                    bundle: bundle,
                    projectRoot: root,
                    records: &records,
                    logLines: &logLines,
                    stage: request.stage,
                    signingMode: signingMode,
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
                bundle: bundle,
                projectRoot: root,
                records: &records,
                logLines: &logLines,
                stage: request.stage,
                signingMode: signingMode,
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
        syncState(
            projectRoot: root,
            stage: request.stage,
            signingMode: signingMode,
            status: "running",
            summary: workspaceRecord.summary,
            records: records,
            nextStep: .fastlaneBuild,
            failedStep: nil,
            failureCode: nil,
            artifactDirectory: bundle.directory.path(percentEncoded: false),
            ipaPath: nil
        )

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
                bundle: bundle,
                projectRoot: root,
                records: &records,
                logLines: &logLines,
                stage: request.stage,
                signingMode: signingMode,
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
                bundle: bundle,
                projectRoot: root,
                records: &records,
                logLines: &logLines,
                stage: request.stage,
                signingMode: signingMode,
                step: .fastlaneBuild,
                classification: .build,
                summary: "expected IPA at \(ipaPath.path(percentEncoded: false)) after fastlane build",
                exitCode: 1,
                ipaPath: ipaPath.path(percentEncoded: false),
                artifacts: artifactList
            )
        }

        syncState(
            projectRoot: root,
            stage: request.stage,
            signingMode: signingMode,
            status: "running",
            summary: buildRecord.summary,
            records: records,
            nextStep: uploadStep?.step,
            failedStep: nil,
            failureCode: nil,
            artifactDirectory: bundle.directory.path(percentEncoded: false),
            ipaPath: ipaPath.path(percentEncoded: false)
        )

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
                    bundle: bundle,
                    projectRoot: root,
                    records: &records,
                    logLines: &logLines,
                    stage: request.stage,
                    signingMode: signingMode,
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
        try writeArtifact(
            bundle: bundle,
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
        syncState(
            projectRoot: root,
            stage: request.stage,
            signingMode: signingMode,
            status: "success",
            summary: summary,
            records: records,
            nextStep: nil,
            failedStep: nil,
            failureCode: nil,
            artifactDirectory: bundle.directory.path(percentEncoded: false),
            ipaPath: ipaPath.path(percentEncoded: false)
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

    func firstStep(for request: ReleaseRunRequest) -> ReleaseRunStep {
        if shouldRunMetadataPreflight(for: request) {
            return .metadataValidate
        }
        if request.stage == .submit {
            if request.releasePolicy.submitRequirements.screenshotsValidation {
                return .screenshotsValidate
            }
        }
        return .releaseInit
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

    func shouldRunMetadataPreflight(for request: ReleaseRunRequest) -> Bool {
        request.stage == .submit
            && (
                request.releasePolicy.submitRequirements.metadataValidation
                || !request.releasePolicy.requiredLocales.isEmpty
            )
    }

    func metadataLocalePreflightSummary(for request: ReleaseRunRequest) throws -> String? {
        let requiredLocales = request.releasePolicy.requiredLocales
        guard !requiredLocales.isEmpty else { return nil }

        let primaryLanguage = request.profile.release.primaryLanguage
        guard requiredLocales.contains(primaryLanguage) else {
            throw ReleaseRunValidationFailure(
                summary: "release policy requiredLocales must include profile primaryLanguage \(primaryLanguage)"
            )
        }

        return "release policy locale gate passed for primary language \(primaryLanguage)"
    }

    func screenshotsLocalePreflightSummary(
        requiredLocales: [String],
        plan: ScreenshotPlan
    ) throws -> String? {
        guard !requiredLocales.isEmpty else { return nil }

        let availableLocales = Set(plan.locales.map(\.locale))
        let missingLocales = requiredLocales.filter { !availableLocales.contains($0) }
        guard missingLocales.isEmpty else {
            throw ReleaseRunValidationFailure(
                summary: "release policy requiredLocales missing from screenshots plan: \(missingLocales.joined(separator: ", "))"
            )
        }

        return "release policy locale gate passed for screenshots locales \(requiredLocales.joined(separator: ", "))"
    }

    func makeCommandEnvironment(
        from environment: [String: String],
        releasePolicy: ReleasePolicy
    ) -> [String: String] {
        var merged = environment
        merged["FASTLANE_DISABLE_COLORS"] = "1"
        merged["FASTLANE_SKIP_UPDATE_CHECK"] = "1"
        merged["FASTLANE_HIDE_TIMESTAMP"] = "1"
        merged["CI"] = "1"
        merged["BOS_RELEASE_AUTOMATION"] = releasePolicy.automationMode.rawValue
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
        bundle: AdapterArtifactBundle,
        projectRoot: URL,
        records: inout [StepRecord],
        logLines: inout [String],
        stage: ReleaseRunStage,
        signingMode: ReleaseCheckMode,
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
        try writeArtifact(
            bundle: bundle,
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
        syncState(
            projectRoot: projectRoot,
            stage: stage,
            signingMode: signingMode,
            status: "failed",
            summary: summary,
            records: records,
            nextStep: resumeStep(for: step, stage: stage, ipaPath: ipaPath),
            failedStep: step,
            failureCode: classification,
            artifactDirectory: bundle.directory.path(percentEncoded: false),
            ipaPath: ipaPath
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
        bundle: AdapterArtifactBundle,
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
        _ = try AdapterArtifacts.write(
            bundle: bundle,
            envelope: AdapterRunEnvelope(
                command: "release-run",
                status: status,
                exitCode: exitCode,
                summary: summary,
                payload: ArtifactPayload(
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
            ),
            stdout: renderLog(records: records, summary: summary, stage: stage),
            stderr: "",
            extraArtifacts: [URL(fileURLWithPath: ipaPath)]
        )
    }

    func renderLog(records: [StepRecord], summary: String, stage: ReleaseRunStage) -> String {
        var lines: [String] = [
            "# bos release-run",
            "stage=\(stage.rawValue)",
            "summary=\(summary)"
        ]
        for record in records {
            lines += logEntry(for: record)
        }
        return lines.joined(separator: "\n") + "\n"
    }

    func truncate(_ text: String, limit: Int = 400) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        let end = trimmed.index(trimmed.startIndex, offsetBy: limit)
        return "\(trimmed[..<end])..."
    }

    func resumableUploadState(
        projectRoot: URL,
        stage: ReleaseRunStage,
        signingMode: ReleaseCheckMode,
        uploadStep: UploadStep?
    ) -> BootstrapLock.ReleaseRunState? {
        guard let uploadStep,
              let state = BosStateStore.releaseRunState(projectRoot: projectRoot),
              state.status == "failed",
              state.stage == stage.rawValue,
              state.signingMode == signingMode.rawValue,
              state.completedSteps.contains(ReleaseRunStep.fastlaneBuild.rawValue),
              state.nextStep == uploadStep.step.rawValue || state.failedStep == uploadStep.step.rawValue,
              let ipaPath = state.ipaPath,
              FileManager.default.fileExists(atPath: ipaPath) else {
            return nil
        }
        return state
    }

    func resumeStep(for step: ReleaseRunStep, stage: ReleaseRunStage, ipaPath: String) -> ReleaseRunStep? {
        let hasReusableIPA = FileManager.default.fileExists(atPath: ipaPath)
        switch step {
        case .fastlaneBeta where hasReusableIPA,
             .fastlaneRelease where hasReusableIPA,
             .fastlaneSubmit where hasReusableIPA:
            return step
        case .fastlaneBuild where hasReusableIPA:
            return uploadStep(for: stage)?.step
        default:
            return nil
        }
    }

    func syncState(
        projectRoot: URL,
        stage: ReleaseRunStage,
        signingMode: ReleaseCheckMode,
        status: String,
        summary: String,
        records: [StepRecord],
        nextStep: ReleaseRunStep?,
        failedStep: ReleaseRunStep?,
        failureCode: ReleaseRunFailureCode?,
        artifactDirectory: String?,
        ipaPath: String?
    ) {
        BosStateStore.updateReleaseRunState(
            projectRoot: projectRoot,
            stage: stage.rawValue,
            signingMode: signingMode.rawValue,
            status: status,
            summary: summary,
            completedSteps: records
                .filter { $0.status == "success" }
                .map { $0.step.rawValue },
            nextStep: nextStep?.rawValue,
            failedStep: failedStep?.rawValue,
            failureCode: failureCode?.rawValue,
            artifactDirectory: artifactDirectory,
            ipaPath: ipaPath
        )
    }
}
