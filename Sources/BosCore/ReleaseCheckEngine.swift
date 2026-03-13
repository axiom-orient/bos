import Foundation
import os

public enum ReleaseCheckMode: String, Codable, Sendable, Equatable {
    case connectivity
    case readonlyCerts = "readonly-certs"
    case syncCerts = "sync-certs"
}

public enum ReleaseCheckFailureCode: String, Codable, Sendable, Equatable {
    case environment = "E-ENV"
    case fastlane = "E-FASTLANE"
    case appStoreConnectAuth = "E-ASC-AUTH"
    case appStoreReadiness = "E-ASC-READINESS"
    case matchRepo = "E-MATCH-REPO"
    case certSync = "E-CERT-SYNC"
}

public enum ReleaseCheckStep: String, Codable, Sendable, Equatable {
    case environmentValidation = "environment-validation"
    case fastlaneScaffold = "fastlane-scaffold"
    case matchRepo = "match-repo"
    case appStoreConnectAuth = "app-store-connect-auth"
    case appStoreReadiness = "app-store-readiness"
    case certSync = "cert-sync"
}

public protocol ReleaseCheckCommandRunning: Sendable {
    func run(command: [String], in workingDirectory: URL, environment: [String: String]) throws -> ReleaseCheckCommandResult
}

public struct ReleaseCheckCommandResult: Sendable, Equatable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

    public init(exitCode: Int32, stdout: String = "", stderr: String = "") {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }
}

public struct ReleaseCheckRequest: Sendable {
    public let projectRoot: URL
    public let profile: Profile
    public let environment: [String: String]
    public let mode: ReleaseCheckMode

    public init(
        projectRoot: URL,
        profile: Profile,
        environment: [String: String],
        mode: ReleaseCheckMode
    ) {
        self.projectRoot = projectRoot
        self.profile = profile
        self.environment = environment
        self.mode = mode
    }
}

public struct ReleaseCheckResult: Sendable, Equatable {
    public let artifacts: [String]
    public let summary: String
    public let mode: ReleaseCheckMode
    public let failureCode: ReleaseCheckFailureCode?
    public let failedStep: ReleaseCheckStep?

    public init(
        artifacts: [String],
        summary: String,
        mode: ReleaseCheckMode,
        failureCode: ReleaseCheckFailureCode?,
        failedStep: ReleaseCheckStep?
    ) {
        self.artifacts = artifacts
        self.summary = summary
        self.mode = mode
        self.failureCode = failureCode
        self.failedStep = failedStep
    }
}

public enum ReleaseCheckEngineError: Error, Equatable {
    case failed(
        classification: ReleaseCheckFailureCode,
        step: ReleaseCheckStep,
        summary: String,
        exitCode: Int32,
        artifacts: [String]
    )
}

public protocol AppStoreConnectAuthChecking: Sendable {
    func ping(environment: [String: String]) throws -> AppStoreConnectPingResult
}

public struct AppStoreConnectPingResult: Sendable, Equatable {
    public let summary: String

    public init(summary: String) {
        self.summary = summary
    }
}

public struct ReleaseCheckEngine: Sendable {
    private let runner: any ReleaseCheckCommandRunning
    private let authChecker: any AppStoreConnectAuthChecking
    private let readinessChecker: any AppStoreReadinessChecking

    public init(
        runner: any ReleaseCheckCommandRunning,
        authChecker: any AppStoreConnectAuthChecking = LiveAppStoreConnectChecker(),
        readinessChecker: any AppStoreReadinessChecking = NoopAppStoreReadinessChecker()
    ) {
        self.runner = runner
        self.authChecker = authChecker
        self.readinessChecker = readinessChecker
    }

    public func releaseCheck(request: ReleaseCheckRequest) throws -> ReleaseCheckResult {
        let root = request.projectRoot.standardizedFileURL
        let effectiveEnvironment = ReleaseEnvironment.effectiveEnvironment(
            profile: request.profile,
            environment: request.environment
        )
        let artifactsDir = try RuntimeArtifacts.makeDirectory(for: "release-check", projectRoot: root)
        let stamp = RuntimeSupport.timestamp()
        let jsonPath = artifactsDir.appending(path: "release-check-\(stamp).json")
        let logPath = artifactsDir.appending(path: "release-check-\(stamp).log")
        let artifacts = [jsonPath.path(percentEncoded: false), logPath.path(percentEncoded: false)]

        var records: [StepRecord] = []
        var logLines: [String] = [
            "# bos release-check",
            "profile=\(request.profile.name)",
            "projectRoot=\(root.path(percentEncoded: false))",
            "mode=\(request.mode.rawValue)",
            ""
        ]

        let sanitizedEnvironment = effectiveEnvironment
        let commandEnvironment = makeCommandEnvironment(from: effectiveEnvironment)

        let envCheck = SigningEnvironmentPolicy.validate(environment: effectiveEnvironment)
        if !envCheck.missingKeys.isEmpty {
            let summary = "missing required environment: \(envCheck.missingKeys.joined(separator: ", "))"
            let record = StepRecord(
                step: .environmentValidation,
                classification: .environment,
                status: "failed",
                command: nil,
                exitCode: nil,
                summary: summary
            )
            records.append(record)
            logLines += logEntry(for: record)
            try writeFailureArtifacts(
                jsonPath: jsonPath,
                logPath: logPath,
                records: records,
                logLines: logLines,
                artifacts: artifacts,
                mode: request.mode,
                summary: summary,
                failureCode: .environment,
                failedStep: .environmentValidation
            )
            BosStateStore.updateSummary(
                projectRoot: root,
                kind: .releaseCheck,
                status: "failed",
                message: summary
            )
            throw ReleaseCheckEngineError.failed(
                classification: .environment,
                step: .environmentValidation,
                summary: summary,
                exitCode: 1,
                artifacts: artifacts
            )
        }
        if !envCheck.invalidIssues.isEmpty {
            let details = envCheck.invalidIssues.map { "\($0.key)(\($0.rule))" }.joined(separator: ", ")
            let summary = "invalid environment format: \(details)"
            let record = StepRecord(
                step: .environmentValidation,
                classification: .environment,
                status: "failed",
                command: nil,
                exitCode: nil,
                summary: summary
            )
            records.append(record)
            logLines += logEntry(for: record)
            try writeFailureArtifacts(
                jsonPath: jsonPath,
                logPath: logPath,
                records: records,
                logLines: logLines,
                artifacts: artifacts,
                mode: request.mode,
                summary: summary,
                failureCode: .environment,
                failedStep: .environmentValidation
            )
            BosStateStore.updateSummary(
                projectRoot: root,
                kind: .releaseCheck,
                status: "failed",
                message: summary
            )
            throw ReleaseCheckEngineError.failed(
                classification: .environment,
                step: .environmentValidation,
                summary: summary,
                exitCode: 1,
                artifacts: artifacts
            )
        }

        records.append(
            StepRecord(
                step: .environmentValidation,
                classification: .environment,
                status: "success",
                command: nil,
                exitCode: 0,
                summary: "signing environment validated"
            )
        )
        logLines += logEntry(for: records[records.count - 1])

        let scaffoldPaths = requiredFastlaneScaffoldPaths(projectRoot: root)
        let missingScaffold = scaffoldPaths.filter {
            !FileManager.default.fileExists(atPath: $0.path(percentEncoded: false))
        }
        if !missingScaffold.isEmpty {
            let summary = "missing fastlane scaffold: \(missingScaffold.map { $0.lastPathComponent }.joined(separator: ", ")); run `bos release-init` first"
            let record = StepRecord(
                step: .fastlaneScaffold,
                classification: .fastlane,
                status: "failed",
                command: nil,
                exitCode: nil,
                summary: summary
            )
            records.append(record)
            logLines += logEntry(for: record)
            try writeFailureArtifacts(
                jsonPath: jsonPath,
                logPath: logPath,
                records: records,
                logLines: logLines,
                artifacts: artifacts,
                mode: request.mode,
                summary: summary,
                failureCode: .fastlane,
                failedStep: .fastlaneScaffold
            )
            BosStateStore.updateSummary(
                projectRoot: root,
                kind: .releaseCheck,
                status: "failed",
                message: summary
            )
            throw ReleaseCheckEngineError.failed(
                classification: .fastlane,
                step: .fastlaneScaffold,
                summary: summary,
                exitCode: 1,
                artifacts: artifacts
            )
        }

        records.append(
            StepRecord(
                step: .fastlaneScaffold,
                classification: .fastlane,
                status: "success",
                command: nil,
                exitCode: 0,
                summary: "required fastlane scaffold present"
            )
        )
        logLines += logEntry(for: records[records.count - 1])

        let matchURL = effectiveEnvironment["MATCH_GIT_URL"] ?? ""
        let matchResult = try runCommand(
            step: .matchRepo,
            classification: .matchRepo,
            command: ["git", "ls-remote", matchURL, "HEAD"],
            workingDirectory: root,
            environment: commandEnvironment
        )
        let matchRecord = makeCommandRecord(
            step: .matchRepo,
            classification: .matchRepo,
            command: ["git", "ls-remote", matchURL, "HEAD"],
            result: matchResult,
            successSummary: "match repository reachable",
            sanitizedEnvironment: sanitizedEnvironment
        )
        records.append(matchRecord)
        logLines += logEntry(
            for: matchRecord,
            stdout: SecretRedactionSupport.redact(
                matchResult.stdout,
                environment: sanitizedEnvironment,
                keys: ["ASC_KEY_P8_BASE64", "MATCH_PASSWORD"]
            ),
            stderr: SecretRedactionSupport.redact(
                matchResult.stderr,
                environment: sanitizedEnvironment,
                keys: ["ASC_KEY_P8_BASE64", "MATCH_PASSWORD"]
            )
        )
        if matchResult.exitCode != 0 {
            let summary = "release-check failed at \(ReleaseCheckStep.matchRepo.rawValue) (\(ReleaseCheckFailureCode.matchRepo.rawValue))"
            try writeFailureArtifacts(
                jsonPath: jsonPath,
                logPath: logPath,
                records: records,
                logLines: logLines,
                artifacts: artifacts,
                mode: request.mode,
                summary: summary,
                failureCode: .matchRepo,
                failedStep: .matchRepo
            )
            BosStateStore.updateSummary(
                projectRoot: root,
                kind: .releaseCheck,
                status: "failed",
                message: summary
            )
            throw ReleaseCheckEngineError.failed(
                classification: .matchRepo,
                step: .matchRepo,
                summary: summary,
                exitCode: matchResult.exitCode,
                artifacts: artifacts
            )
        }

        do {
            let authResult = try authChecker.ping(environment: effectiveEnvironment)
            let record = StepRecord(
                step: .appStoreConnectAuth,
                classification: .appStoreConnectAuth,
                status: "success",
                command: nil,
                exitCode: 0,
                summary: authResult.summary
            )
            records.append(record)
            logLines += logEntry(for: record)
        } catch {
            let errorDetails = SecretRedactionSupport.redact(
                String(describing: error),
                environment: sanitizedEnvironment,
                keys: ["ASC_KEY_P8_BASE64", "MATCH_PASSWORD"]
            )
            let summary = "App Store Connect authentication failed: \(errorDetails)"
            let record = StepRecord(
                step: .appStoreConnectAuth,
                classification: .appStoreConnectAuth,
                status: "failed",
                command: nil,
                exitCode: nil,
                summary: summary
            )
            records.append(record)
            logLines += logEntry(for: record)
            try writeFailureArtifacts(
                jsonPath: jsonPath,
                logPath: logPath,
                records: records,
                logLines: logLines,
                artifacts: artifacts,
                mode: request.mode,
                summary: summary,
                failureCode: .appStoreConnectAuth,
                failedStep: .appStoreConnectAuth
            )
            BosStateStore.updateSummary(
                projectRoot: root,
                kind: .releaseCheck,
                status: "failed",
                message: summary
            )
            throw ReleaseCheckEngineError.failed(
                classification: .appStoreConnectAuth,
                step: .appStoreConnectAuth,
                summary: summary,
                exitCode: 1,
                artifacts: artifacts
            )
        }

        if request.mode != .connectivity {
            let lane = request.mode == .readonlyCerts ? "certs_readonly" : "certs"
            let laneCommand = ["fastlane", "ios", lane]
            let certResult = try runCommand(
                step: .certSync,
                classification: .certSync,
                command: laneCommand,
                workingDirectory: root,
                environment: commandEnvironment
            )
            let certRecord = makeCommandRecord(
                step: .certSync,
                classification: .certSync,
                command: laneCommand,
                result: certResult,
                successSummary: request.mode == .readonlyCerts
                    ? "read-only certificate sync check passed"
                    : "certificate sync completed",
                sanitizedEnvironment: sanitizedEnvironment
            )
            let certStdout = SecretRedactionSupport.redact(
                certResult.stdout,
                environment: sanitizedEnvironment,
                keys: ["ASC_KEY_P8_BASE64", "MATCH_PASSWORD"]
            )
            let certStderr = SecretRedactionSupport.redact(
                certResult.stderr,
                environment: sanitizedEnvironment,
                keys: ["ASC_KEY_P8_BASE64", "MATCH_PASSWORD"]
            )
            if certResult.exitCode != 0 {
                records.append(certRecord)
                logLines += logEntry(
                    for: certRecord,
                    stdout: certStdout,
                    stderr: certStderr
                )
                let summary = "release-check failed at \(ReleaseCheckStep.certSync.rawValue) (\(ReleaseCheckFailureCode.certSync.rawValue))"
                try writeFailureArtifacts(
                    jsonPath: jsonPath,
                    logPath: logPath,
                    records: records,
                    logLines: logLines,
                    artifacts: artifacts,
                    mode: request.mode,
                    summary: summary,
                    failureCode: .certSync,
                    failedStep: .certSync
                )
                BosStateStore.updateSummary(
                    projectRoot: root,
                    kind: .releaseCheck,
                    status: "failed",
                    message: summary
                )
                throw ReleaseCheckEngineError.failed(
                    classification: .certSync,
                    step: .certSync,
                    summary: summary,
                    exitCode: certResult.exitCode,
                    artifacts: artifacts
                )
            }
            if let mismatchSummary = signingTeamMismatchSummary(
                expectedTeamID: request.profile.configuredAppleTeamId,
                stdout: certResult.stdout,
                stderr: certResult.stderr
            ) {
                let mismatchRecord = StepRecord(
                    step: .certSync,
                    classification: .certSync,
                    status: "failed",
                    command: laneCommand,
                    exitCode: 0,
                    summary: mismatchSummary
                )
                records.append(mismatchRecord)
                logLines += logEntry(
                    for: mismatchRecord,
                    stdout: certStdout,
                    stderr: certStderr
                )
                try writeFailureArtifacts(
                    jsonPath: jsonPath,
                    logPath: logPath,
                    records: records,
                    logLines: logLines,
                    artifacts: artifacts,
                    mode: request.mode,
                    summary: mismatchSummary,
                    failureCode: .certSync,
                    failedStep: .certSync
                )
                BosStateStore.updateSummary(
                    projectRoot: root,
                    kind: .releaseCheck,
                    status: "failed",
                    message: mismatchSummary
                )
                throw ReleaseCheckEngineError.failed(
                    classification: .certSync,
                    step: .certSync,
                    summary: mismatchSummary,
                    exitCode: 1,
                    artifacts: artifacts
                )
            }
            records.append(certRecord)
            logLines += logEntry(
                for: certRecord,
                stdout: certStdout,
                stderr: certStderr
            )
        }

        do {
            let readiness = try readinessChecker.check(
                projectRoot: root,
                profile: request.profile,
                environment: effectiveEnvironment
            )
            let record = StepRecord(
                step: .appStoreReadiness,
                classification: .appStoreReadiness,
                status: "success",
                command: nil,
                exitCode: 0,
                summary: readiness.summary
            )
            records.append(record)
            logLines += logEntry(for: record)
        } catch {
            let errorDetails = SecretRedactionSupport.redact(
                String(describing: error),
                environment: sanitizedEnvironment,
                keys: ["ASC_KEY_P8_BASE64", "MATCH_PASSWORD"]
            )
            let summary = "App Store readiness failed: \(errorDetails)"
            let record = StepRecord(
                step: .appStoreReadiness,
                classification: .appStoreReadiness,
                status: "failed",
                command: nil,
                exitCode: nil,
                summary: summary
            )
            records.append(record)
            logLines += logEntry(for: record)
            try writeFailureArtifacts(
                jsonPath: jsonPath,
                logPath: logPath,
                records: records,
                logLines: logLines,
                artifacts: artifacts,
                mode: request.mode,
                summary: summary,
                failureCode: .appStoreReadiness,
                failedStep: .appStoreReadiness
            )
            BosStateStore.updateSummary(
                projectRoot: root,
                kind: .releaseCheck,
                status: "failed",
                message: summary
            )
            throw ReleaseCheckEngineError.failed(
                classification: .appStoreReadiness,
                step: .appStoreReadiness,
                summary: summary,
                exitCode: 1,
                artifacts: artifacts
            )
        }

        let summary = "Release check passed (\(request.mode.rawValue))"
        try writeSuccessArtifacts(
            jsonPath: jsonPath,
            logPath: logPath,
            records: records,
            logLines: logLines,
            artifacts: artifacts,
            mode: request.mode,
            summary: summary
        )
        BosStateStore.updateSummary(
            projectRoot: root,
            kind: .releaseCheck,
            status: "success",
            message: summary
        )
        return ReleaseCheckResult(
            artifacts: artifacts,
            summary: summary,
            mode: request.mode,
            failureCode: nil,
            failedStep: nil
        )
    }
}

extension ReleaseCheckEngine {
    private static let teamIDRegex = try! NSRegularExpression(pattern: #"[A-Z0-9]{10}"#)

    private struct StepRecord: Codable, Equatable {
        let step: ReleaseCheckStep
        let classification: ReleaseCheckFailureCode
        let status: String
        let command: [String]?
        let exitCode: Int?
        let summary: String
    }

    private struct ArtifactPayload: Codable {
        let command: String
        let status: String
        let exitCode: Int
        let summary: String
        let mode: String
        let failureCode: String?
        let failedStep: String?
        let steps: [StepRecord]
        let artifacts: [String]
    }

    private func requiredFastlaneScaffoldPaths(projectRoot: URL) -> [URL] {
        [
            projectRoot.appending(path: "fastlane/Fastfile"),
            projectRoot.appending(path: "fastlane/Appfile"),
            projectRoot.appending(path: "fastlane/Matchfile")
        ]
    }

    private func makeCommandEnvironment(from environment: [String: String]) -> [String: String] {
        var merged = environment
        merged["FASTLANE_DISABLE_COLORS"] = "1"
        merged["FASTLANE_SKIP_UPDATE_CHECK"] = "1"
        merged["FASTLANE_HIDE_TIMESTAMP"] = "1"
        merged["CI"] = "1"
        return merged
    }

    private func runCommand(
        step: ReleaseCheckStep,
        classification: ReleaseCheckFailureCode,
        command: [String],
        workingDirectory: URL,
        environment: [String: String]
    ) throws -> ReleaseCheckCommandResult {
        do {
            return try runner.run(command: command, in: workingDirectory, environment: environment)
        } catch {
            return ReleaseCheckCommandResult(
                exitCode: 127,
                stdout: "",
                stderr: "runner-error[\(classification.rawValue)/\(step.rawValue)]: \(error)"
            )
        }
    }

    private func makeCommandRecord(
        step: ReleaseCheckStep,
        classification: ReleaseCheckFailureCode,
        command: [String],
        result: ReleaseCheckCommandResult,
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

    private func logEntry(
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

    private func writeFailureArtifacts(
        jsonPath: URL,
        logPath: URL,
        records: [StepRecord],
        logLines: [String],
        artifacts: [String],
        mode: ReleaseCheckMode,
        summary: String,
        failureCode: ReleaseCheckFailureCode,
        failedStep: ReleaseCheckStep
    ) throws {
        try RuntimeSupport.writeFile(to: logPath, content: logLines.joined(separator: "\n") + "\n")
        try writeArtifact(
            to: jsonPath,
            status: "failed",
            exitCode: 7,
            summary: summary,
            mode: mode,
            failureCode: failureCode,
            failedStep: failedStep,
            records: records,
            artifacts: artifacts
        )
    }

    private func writeSuccessArtifacts(
        jsonPath: URL,
        logPath: URL,
        records: [StepRecord],
        logLines: [String],
        artifacts: [String],
        mode: ReleaseCheckMode,
        summary: String
    ) throws {
        try RuntimeSupport.writeFile(to: logPath, content: logLines.joined(separator: "\n") + "\n")
        try writeArtifact(
            to: jsonPath,
            status: "success",
            exitCode: 0,
            summary: summary,
            mode: mode,
            failureCode: nil,
            failedStep: nil,
            records: records,
            artifacts: artifacts
        )
    }

    private func writeArtifact(
        to path: URL,
        status: String,
        exitCode: Int,
        summary: String,
        mode: ReleaseCheckMode,
        failureCode: ReleaseCheckFailureCode?,
        failedStep: ReleaseCheckStep?,
        records: [StepRecord],
        artifacts: [String]
    ) throws {
        let payload = ArtifactPayload(
            command: "release-check",
            status: status,
            exitCode: exitCode,
            summary: summary,
            mode: mode.rawValue,
            failureCode: failureCode?.rawValue,
            failedStep: failedStep?.rawValue,
            steps: records,
            artifacts: artifacts
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        try RuntimeSupport.writeFile(to: path, data: data)
    }

    private func truncate(_ text: String, limit: Int = 400) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        let end = trimmed.index(trimmed.startIndex, offsetBy: limit)
        return "\(trimmed[..<end])..."
    }

    private func signingTeamMismatchSummary(
        expectedTeamID: String?,
        stdout: String,
        stderr: String
    ) -> String? {
        guard let expectedTeamID = normalizedTeamID(expectedTeamID),
              let discoveredTeamID = discoveredSigningTeamID(in: "\(stdout)\n\(stderr)"),
              discoveredTeamID != expectedTeamID else {
            return nil
        }
        return "signing team mismatch: configured appleTeamId=\(expectedTeamID), discovered team=\(discoveredTeamID)"
    }

    private func discoveredSigningTeamID(in text: String) -> String? {
        let labels = ["Development Team ID", "User ID", "Organisation Unit"]
        let lines = text.components(separatedBy: .newlines)
        for label in labels {
            for line in lines where line.contains(label) {
                if let teamID = extractTeamID(from: line) {
                    return teamID
                }
            }
        }
        return nil
    }

    private func extractTeamID(from line: String) -> String? {
        let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = Self.teamIDRegex.firstMatch(in: line, range: nsRange),
              let range = Range(match.range, in: line) else {
            return nil
        }
        return String(line[range])
    }

    private func normalizedTeamID(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

public struct LiveAppStoreConnectChecker: AppStoreConnectAuthChecking {
    public init() {}

    public func ping(environment: [String: String]) throws -> AppStoreConnectPingResult {
        let token = try makeBearerToken(environment: environment)
        let url = URL(string: "https://api.appstoreconnect.apple.com/v1/apps?limit=1")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let semaphore = DispatchSemaphore(value: 0)
        let outcomeLock = OSAllocatedUnfairLock(initialState: Result<(Data, HTTPURLResponse), Error>?.none)

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            if let error {
                outcomeLock.withLock { $0 = .failure(error) }
                return
            }
            guard let response = response as? HTTPURLResponse else {
                outcomeLock.withLock {
                    $0 = .failure(NSError(domain: "BosCore.ReleaseCheck", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: "missing HTTP response from App Store Connect"
                    ]))
                }
                return
            }
            outcomeLock.withLock { $0 = .success((data ?? Data(), response)) }
        }

        task.resume()
        if semaphore.wait(timeout: .now() + 30) == .timedOut {
            task.cancel()
            throw NSError(
                domain: "BosCore.ReleaseCheck",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "timed out waiting for App Store Connect response"]
            )
        }

        switch outcomeLock.withLock({ $0 }) {
        case .success(let (data, response)):
            guard (200..<300).contains(response.statusCode) else {
                let body = String(decoding: data, as: UTF8.self)
                throw NSError(
                    domain: "BosCore.ReleaseCheck",
                    code: response.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "App Store Connect returned HTTP \(response.statusCode): \(body)"]
                )
            }
            return AppStoreConnectPingResult(summary: "App Store Connect authentication succeeded")
        case .failure(let error):
            throw error
        case .none:
            throw NSError(
                domain: "BosCore.ReleaseCheck",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "App Store Connect request finished without a result"]
            )
        }
    }
}

private extension LiveAppStoreConnectChecker {
    func makeBearerToken(environment: [String: String]) throws -> String {
        do {
            return try AppStoreConnectTokenFactory().makeBearerToken(environment: environment)
        } catch let error as AppRegistrationEngineError {
            let description: String
            switch error {
            case .invalidEnvironment(let missingKeys, _):
                description = "missing App Store Connect API key material: \(missingKeys.joined(separator: ", "))"
            case .providerFailure(let summary, _):
                description = summary
            case .missingRequiredFields, .invalidValue:
                description = String(describing: error)
            }
            throw NSError(
                domain: "BosCore.ReleaseCheck",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: description]
            )
        } catch {
            throw error
        }
    }
}
