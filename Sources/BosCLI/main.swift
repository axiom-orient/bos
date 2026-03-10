import Foundation
import BosCore
import Yams
import os

enum ExitCode: Int32 {
    case success = 0
    case contractValidationError = 2
    case driftDetected = 3
    case verifyFailed = 4
    case releaseInitFailed = 5
    case doctorFailed = 6
    case releaseCheckFailed = 7
    case appRegisterFailed = 8
    case releaseRunFailed = 9
}

enum OutputFormat: String {
    case human
    case json
}

enum DoctorScope: String {
    case core
    case all
    case plan
    case apply
    case verify
    case appRegister = "app-register"
    case releaseInit = "release-init"
    case releaseCheck = "release-check"
    case releaseRun = "release-run"

    var commands: [String] {
        switch self {
        case .core:
            return ToolchainLock.coreCommands
        case .all:
            return ToolchainLock.allCommands
        case .plan:
            return [ToolchainLock.commandPlan]
        case .apply:
            return [ToolchainLock.commandApply]
        case .verify:
            return [ToolchainLock.commandVerify]
        case .appRegister:
            return [ToolchainLock.commandAppRegister]
        case .releaseInit:
            return [ToolchainLock.commandReleaseInit]
        case .releaseCheck:
            return [ToolchainLock.commandReleaseCheck]
        case .releaseRun:
            return [ToolchainLock.commandReleaseRun]
        }
    }
}

struct DoctorInstallAttempt: Codable {
    let tool: String
    let command: String
    let status: String
    let exitCode: Int32
    let stderr: String
}

struct DoctorCommandOutput: Codable {
    let command: String
    let status: String
    let exitCode: Int
    let summary: String
    let scope: String
    let findings: [DoctorFinding]
    let installAttempts: [DoctorInstallAttempt]
    let artifacts: [String]
}

struct ReleaseCheckCommandOutput: Codable {
    let command: String
    let status: String
    let exitCode: Int
    let summary: String
    let mode: String
    let failureCode: String?
    let failedStep: String?
    let artifacts: [String]
}

struct ReleaseRunCommandOutput: Codable {
    let command: String
    let status: String
    let exitCode: Int
    let summary: String
    let stage: String
    let failureCode: String?
    let failedStep: String?
    let ipaPath: String?
    let artifacts: [String]
}

struct AppRegisterCommandOutput: Codable {
    let command: String
    let status: String
    let exitCode: Int
    let summary: String
    let appIdentifier: String?
    let appName: String?
    let sku: String?
    let primaryLanguage: String?
    let bundleIdStatus: String?
    let appStatus: String?
    let artifacts: [String]
}

enum BosCommand: String, CaseIterable {
    case doctor
    case plan
    case apply
    case verify
    case appRegister = "app-register"
    case releaseInit = "release-init"
    case releaseCheck = "release-check"
    case releaseRun = "release-run"

    var summary: String {
        switch self {
        case .doctor:
            return "환경/버전/필수 도구 체크"
        case .plan:
            return "PRD -> blueprint 변환"
        case .apply:
            return "scaffold 생성 + 정책 패치 적용"
        case .verify:
            return "tuist/xcodebuild 검증 게이트 실행"
        case .appRegister:
            return "App Store Connect 앱/Bundle ID 등록 + profile SSOT 동기화"
        case .releaseInit:
            return "fastlane 파일/기본 lane 생성"
        case .releaseCheck:
            return "App Store Connect/match live signing 준비 검증"
        case .releaseRun:
            return "IPA build/upload/submit를 한 번에 실행"
        }
    }

    var usage: String {
        switch self {
        case .doctor:
            return "bos doctor [--for core|all|plan|apply|verify|app-register|release-init|release-check|release-run] [--project-root <path>] [--format human|json]"
        case .plan:
            return "bos plan (--prd <path> | --plan-dir <path>) [--profile <path>] [--out <blueprint.yaml>] [--project-root <path>] [--company-name <name>] [--app-name <name>] [--app-identifier <id>] [--apple-team-id <team>] [--primary-language en-US|ko-KR] [--sku <value>] [--format human|json]"
        case .apply:
            return "bos apply [--blueprint <path>] [--app-identifier <id>] [--apple-team-id <team>] [--profile <path>] [--mode init|incremental] [--fix] [--dry-run] [--project-root <path>] [--format human|json]"
        case .verify:
            return "bos verify [--profile <path>] [--project-root <path>] [--format human|json]"
        case .appRegister:
            return "bos app-register [--blueprint <path>] [--profile <path>] [--project-root <path>] [--company-name <name>] [--app-name <name>] [--app-identifier <id>] [--apple-team-id <team>] [--primary-language en-US|ko-KR] [--sku <value>] [--match-git-url <url>] [--format human|json]"
        case .releaseInit:
            return "bos release-init [--blueprint <path>] [--profile <path>] [--project-root <path>] [--format human|json]"
        case .releaseCheck:
            return "bos release-check [--profile <path>] [--project-root <path>] [--mode connectivity|readonly-certs|sync-certs] [--allow-write] [--format human|json]"
        case .releaseRun:
            return "bos release-run [--blueprint <path>] [--profile <path>] [--project-root <path>] [--stage build|beta|release|submit] [--allow-signing-write] [--format human|json]"
        }
    }
}

func printRootHelp() {
    let commandList = BosCommand.allCases
        .map { "  \($0.rawValue) - \($0.summary)" }
        .joined(separator: "\n")

    let help = """
    bos v1 (Swift CLI-only)

    Usage:
      bos <command> [options]
      bos <command> --help

    Commands:
    \(commandList)

    Global Flags:
      --project-root <path>
      --format human|json   (default: human)
      -h, --help

    Primary Path:
      bos doctor
      bos plan
      bos apply --mode init
      bos verify
      bos app-register
      bos release-init
      bos release-check
      bos release-run --stage beta
    """

    print(help)
}

func printCommandHelp(_ command: BosCommand) {
    let help = """
    Command: \(command.rawValue)
    Summary: \(command.summary)

    Usage:
      \(command.usage)
    """

    print(help)
}

struct ParsedOptions {
    var values: [String: String] = [:]
    var flags: Set<String> = []
    var missingValueFlags: [String] = []
    var unknownFlags: [String] = []
    var positional: [String] = []
}

func parseOptions(
    args: [String],
    valueFlags: Set<String>,
    booleanFlags: Set<String>
) -> ParsedOptions {
    var parsed = ParsedOptions()
    var index = 0
    while index < args.count {
        let token = args[index]
        if token.hasPrefix("--") {
            if valueFlags.contains(token) {
                let nextIndex = index + 1
                guard nextIndex < args.count, !args[nextIndex].hasPrefix("--") else {
                    parsed.missingValueFlags.append(token)
                    index += 1
                    continue
                }
                parsed.values[token] = args[nextIndex]
                index += 2
                continue
            }
            if booleanFlags.contains(token) {
                parsed.flags.insert(token)
                index += 1
                continue
            }
            parsed.unknownFlags.append(token)
            index += 1
            continue
        }

        parsed.positional.append(token)
        index += 1
    }
    return parsed
}

func assertOptionContract(
    parsed: ParsedOptions,
    command: BosCommand,
    format: OutputFormat
) {
    if !parsed.missingValueFlags.isEmpty {
        fail(
            message: "missing value for flag(s): \(parsed.missingValueFlags.joined(separator: ", "))",
            command: command,
            format: format
        )
    }
    if !parsed.unknownFlags.isEmpty {
        fail(
            message: "unknown flag(s): \(parsed.unknownFlags.joined(separator: ", "))",
            command: command,
            format: format
        )
    }
    if !parsed.positional.isEmpty {
        fail(
            message: "unexpected argument(s): \(parsed.positional.joined(separator: " "))",
            command: command,
            format: format
        )
    }
}

func parseOutputFormat(from args: [String]) -> OutputFormat {
    guard let index = args.firstIndex(of: "--format") else {
        return .human
    }
    let valueIndex = args.index(after: index)
    guard valueIndex < args.endIndex else {
        return .human
    }
    return OutputFormat(rawValue: args[valueIndex].lowercased()) ?? .human
}

func currentWorkingDirectoryURL() -> URL {
    URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
}

func resolvePath(_ raw: String, base: URL) -> URL {
    let expanded = NSString(string: raw).expandingTildeInPath
    if expanded.hasPrefix("/") {
        return URL(fileURLWithPath: expanded)
    }
    return base.appending(path: expanded)
}

func defaultProfilePath(projectRoot: URL) -> URL {
    projectRoot.appending(path: ".bos/config/profile.yaml")
}

func resolveProfilePathOrFail(
    raw: String?,
    projectRoot: URL,
    command: BosCommand,
    format: OutputFormat
) -> URL {
    if let raw {
        return resolvePath(raw, base: projectRoot)
    }

    let fallback = defaultProfilePath(projectRoot: projectRoot)
    if FileManager.default.fileExists(atPath: fallback.path(percentEncoded: false)) {
        return fallback
    }

    do {
        try writeTextFile(defaultProfileTemplate(), to: fallback)
        fputs("note: profile not found — created default at \(fallback.path(percentEncoded: false))\n", stderr)
    } catch {
        fail(message: "could not create default profile: \(error)", command: command, format: format)
    }
    return fallback
}

func defaultBlueprintPath(projectRoot: URL) -> URL {
    projectRoot.appending(path: ".bos/plan/blueprint.yaml")
}

func resolveOptionalBlueprintPath(raw: String?, projectRoot: URL) -> URL? {
    if let raw {
        return resolvePath(raw, base: projectRoot)
    }

    let path = defaultBlueprintPath(projectRoot: projectRoot)
    guard FileManager.default.fileExists(atPath: path.path(percentEncoded: false)) else {
        return nil
    }
    return path
}

func resolveBlueprintPathOrFail(
    raw: String?,
    projectRoot: URL,
    command: BosCommand,
    format: OutputFormat
) -> URL {
    if let path = resolveOptionalBlueprintPath(raw: raw, projectRoot: projectRoot) {
        return path
    }

    let expected = defaultBlueprintPath(projectRoot: projectRoot).path(percentEncoded: false)
    fail(
        message: "blueprint not found. pass `--blueprint` or create \(expected)",
        command: command,
        format: format
    )
}

func defaultProfileTemplate() -> String {
    """
    schemaVersion: 1
    name: default
    defaults:
      deploymentTarget: "18.0"
      appTargets:
        controlsExtension: false
        uiTests: true
    identity:
      companyName:
      appName:
      appIdentifier:
      appleTeamId:
    release:
      primaryLanguage: "en-US"
      sku:
      matchGitURL:
    featurePattern:
      sourcesInterface: true
      designFolder: false
    rules:
      testingStyle: swift-testing
      forbidPatterns:
        - "@unchecked Sendable"
        - "Date()"
        - "UUID()"
    """
}

func resolveToolchainLockPath(projectRoot: URL) -> URL? {
    let fm = FileManager.default
    let preferred = preferredToolchainLockPath(projectRoot: projectRoot)
    return fm.fileExists(atPath: preferred.path(percentEncoded: false)) ? preferred : nil
}

func preferredToolchainLockPath(projectRoot: URL) -> URL {
    projectRoot.appending(path: "config/toolchain.lock.yaml")
}

enum SigningEnvironmentFileError: Error {
    case unreadable(path: String, details: String)
    case invalidLine(line: Int, details: String)
}

func defaultSigningEnvironmentPath(projectRoot: URL) -> URL {
    projectRoot.appending(path: ".bos/config/signing.env")
}

func hardenSigningEnvironmentFilePermissions(at path: URL) {
    try? FileManager.default.setAttributes(
        [.posixPermissions: NSNumber(value: Int(0o600))],
        ofItemAtPath: path.path(percentEncoded: false)
    )
}

func signingEnvironmentLoadErrorMessage(_ error: Error, projectRoot: URL) -> String {
    let path = defaultSigningEnvironmentPath(projectRoot: projectRoot).path(percentEncoded: false)
    if let signingError = error as? SigningEnvironmentFileError {
        switch signingError {
        case .unreadable(let sourcePath, let details):
            return "failed to read signing env at \(sourcePath): \(details)"
        case .invalidLine(let line, let details):
            return "invalid signing env in \(path): line \(line) (\(details))"
        }
    }
    return "failed to load signing env at \(path): \(error.localizedDescription)"
}

func signingEnvironmentTemplate() -> String {
    """
    # bos signing environment (do not commit this file)
    # Fill all values, then run: bos doctor --for release-run
    # MATCH_GIT_URL moved to .bos/config/profile.yaml release.matchGitURL.
    # Legacy fallback from this file is still accepted if present in shell env.
    ASC_ISSUER_ID=
    ASC_KEY_ID=
    ASC_KEY_P8_BASE64=
    MATCH_PASSWORD=
    """
}

func ensureSigningEnvironmentTemplate(projectRoot: URL) throws -> (path: URL, created: Bool) {
    let path = defaultSigningEnvironmentPath(projectRoot: projectRoot)
    let fm = FileManager.default
    let filePath = path.path(percentEncoded: false)
    if fm.fileExists(atPath: filePath) {
        hardenSigningEnvironmentFilePermissions(at: path)
        return (path, false)
    }
    try writeTextFile(signingEnvironmentTemplate(), to: path)
    hardenSigningEnvironmentFilePermissions(at: path)
    return (path, true)
}

func parseEnvironmentFile(at path: URL) throws -> [String: String] {
    let text: String
    do {
        text = try readTextFile(path)
    } catch {
        throw SigningEnvironmentFileError.unreadable(
            path: path.path(percentEncoded: false),
            details: error.localizedDescription
        )
    }
    var environment: [String: String] = [:]

    let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    for (index, rawLine) in lines.enumerated() {
        var line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if line.isEmpty || line.hasPrefix("#") {
            continue
        }

        if line.hasPrefix("export ") {
            line = String(line.dropFirst("export ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let equals = line.firstIndex(of: "=") else {
            throw SigningEnvironmentFileError.invalidLine(
                line: index + 1,
                details: "expected KEY=VALUE"
            )
        }

        let key = line[..<equals].trimmingCharacters(in: .whitespacesAndNewlines)
        var value = String(line[line.index(after: equals)...]).trimmingCharacters(in: .whitespacesAndNewlines)

        if key.isEmpty {
            throw SigningEnvironmentFileError.invalidLine(
                line: index + 1,
                details: "empty key"
            )
        }

        if (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) {
            value = String(value.dropFirst().dropLast())
        }

        environment[key] = value
    }

    return environment
}

func mergeProcessEnvironment(
    processEnvironment: [String: String],
    fileEnvironment: [String: String]
) -> [String: String] {
    var merged = fileEnvironment
    for (key, value) in processEnvironment {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            continue
        }
        merged[key] = value
    }
    return merged
}

func resolveSigningEnvironment(
    projectRoot: URL,
    profile: Profile? = nil,
    processEnvironment: [String: String]
) throws -> (environment: [String: String], note: String?) {
    let template = try ensureSigningEnvironmentTemplate(projectRoot: projectRoot)
    let fileEnvironment = try parseEnvironmentFile(at: template.path)
    let merged = mergeProcessEnvironment(processEnvironment: processEnvironment, fileEnvironment: fileEnvironment)
    let effective = profile.map { ReleaseEnvironment.effectiveEnvironment(profile: $0, environment: merged) } ?? merged

    if template.created {
        return (effective, "Created signing env template at \(template.path.path(percentEncoded: false))")
    }
    return (effective, nil)
}

func resolveBrewExecutable() -> String? {
    if commandExists("brew") {
        return "brew"
    }

    let candidates = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
    let fm = FileManager.default
    return candidates.first { fm.isExecutableFile(atPath: $0) }
}

func runInstallAttempt(
    tool: String,
    commandDescription: String,
    command: [String],
    workingDirectory: URL
) -> DoctorInstallAttempt {
    do {
        let result = try runProcess(command: command, workingDirectory: workingDirectory)
        return DoctorInstallAttempt(
            tool: tool,
            command: commandDescription,
            status: result.status == 0 ? "success" : "failed",
            exitCode: result.status,
            stderr: result.stderr
        )
    } catch {
        return DoctorInstallAttempt(
            tool: tool,
            command: commandDescription,
            status: "failed",
            exitCode: 1,
            stderr: "\(error)"
        )
    }
}

func installToolWithBrew(tool: String, projectRoot: URL) -> [DoctorInstallAttempt] {
    var attempts: [DoctorInstallAttempt] = []

    if let brew = resolveBrewExecutable() {
        attempts.append(
            runInstallAttempt(
                tool: tool,
                commandDescription: "brew install \(tool)",
                command: [brew, "install", tool],
                workingDirectory: projectRoot
            )
        )
        return attempts
    }

    // brew not found — install brew first, then tool
    let brewInstallScript = #"/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)""#
    let bootstrap = runInstallAttempt(
        tool: tool,
        commandDescription: brewInstallScript,
        command: ["/bin/bash", "-lc", brewInstallScript],
        workingDirectory: projectRoot
    )
    attempts.append(bootstrap)

    guard bootstrap.status == "success" else {
        return attempts
    }

    guard let brew = resolveBrewExecutable() else {
        attempts.append(
            DoctorInstallAttempt(
                tool: tool,
                command: "brew install \(tool)",
                status: "skipped-no-runner",
                exitCode: 127,
                stderr: "brew installation finished but brew executable is not on PATH"
            )
        )
        return attempts
    }

    attempts.append(
        runInstallAttempt(
            tool: tool,
            commandDescription: "brew install \(tool)",
            command: [brew, "install", tool],
            workingDirectory: projectRoot
        )
    )

    return attempts
}

func installFastlaneWithBrew(projectRoot: URL) -> [DoctorInstallAttempt] {
    installToolWithBrew(tool: "fastlane", projectRoot: projectRoot)
}

func installTuistWithBrew(projectRoot: URL) -> [DoctorInstallAttempt] {
    installToolWithBrew(tool: "tuist", projectRoot: projectRoot)
}

private struct ToolchainLockSchemaProbe: Decodable {
    let schemaVersion: Int
}

func decodeToolchainLock(at path: URL) throws -> ToolchainLock {
    let text = try readTextFile(path)
    let decoder = YAMLDecoder()

    if let probe = try? decoder.decode(ToolchainLockSchemaProbe.self, from: text),
       probe.schemaVersion == 1 {
        throw NSError(
            domain: "BosCLI.Decode",
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey:
                    "unsupported legacy toolchain lock schemaVersion 1 at \(path.path(percentEncoded: false)); delete it and rerun `bos doctor` to regenerate schemaVersion 2"
            ]
        )
    }

    do {
        return try decoder.decode(ToolchainLock.self, from: text)
    } catch {
        throw NSError(
            domain: "BosCLI.Decode",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "failed to decode toolchain lock at \(path.path(percentEncoded: false)): \(error)"]
        )
    }
}

func readTextFile(_ path: URL) throws -> String {
    try String(contentsOf: path, encoding: .utf8)
}

func writeTextFile(_ text: String, to path: URL) throws {
    let fm = FileManager.default
    try fm.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(text.utf8).write(to: path, options: .atomic)
}

func decodeYAMLOrJSON<T: Decodable>(_ type: T.Type, at path: URL) throws -> T {
    let text = try readTextFile(path)
    do {
        return try YAMLDecoder().decode(T.self, from: text)
    } catch {
        throw NSError(
            domain: "BosCLI.Decode",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "failed to decode \(path.path(percentEncoded: false)): \(error)"]
        )
    }
}

func encodeYAML<T: Encodable>(_ value: T) throws -> String {
    try YAMLEncoder().encode(value)
}

func extractFirstSemanticVersion(from text: String) -> String? {
    let pattern = #"\d+(?:\.\d+){1,3}"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
    let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
    guard let match = regex.firstMatch(in: text, range: nsRange),
          let range = Range(match.range, in: text) else {
        return nil
    }
    return String(text[range])
}

func runProcess(
    command: [String],
    workingDirectory: URL? = nil,
    environment: [String: String]? = nil
) throws -> (status: Int32, stdout: String, stderr: String) {
    struct ThreadSafeDataBuffer: Sendable {
        private let lock = OSAllocatedUnfairLock(initialState: Data())

        func append(_ data: Data) {
            lock.withLock { storage in
                storage.append(data)
            }
        }

        func snapshot() -> Data {
            lock.withLock { storage in
                storage
            }
        }
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = command
    process.currentDirectoryURL = workingDirectory
    if let environment {
        process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
    }

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    let stdoutBuffer = ThreadSafeDataBuffer()
    let stderrBuffer = ThreadSafeDataBuffer()
    stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
        let chunk = handle.availableData
        guard !chunk.isEmpty else { return }
        stdoutBuffer.append(chunk)
    }
    stderrPipe.fileHandleForReading.readabilityHandler = { handle in
        let chunk = handle.availableData
        guard !chunk.isEmpty else { return }
        stderrBuffer.append(chunk)
    }

    try process.run()
    process.waitUntilExit()

    stdoutPipe.fileHandleForReading.readabilityHandler = nil
    stderrPipe.fileHandleForReading.readabilityHandler = nil

    let remainingStdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
    let remainingStderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
    stdoutBuffer.append(remainingStdout)
    stderrBuffer.append(remainingStderr)

    let stdout = String(decoding: stdoutBuffer.snapshot(), as: UTF8.self)
    let stderr = String(decoding: stderrBuffer.snapshot(), as: UTF8.self)
    return (process.terminationStatus, stdout, stderr)
}

func detectVersion(command: [String]) -> String {
    do {
        let result = try runProcess(command: command)
        if result.status != 0 {
            return "not-found"
        }
        let merged = result.stdout + "\n" + result.stderr
        return extractFirstSemanticVersion(from: merged) ?? "unknown"
    } catch {
        return "not-found"
    }
}

func commandExists(_ command: String) -> Bool {
    do {
        let result = try runProcess(command: ["which", command])
        return result.status == 0
    } catch {
        return false
    }
}

func tokenizeCommandLine(_ raw: String) -> [String] {
    raw.split(whereSeparator: \.isWhitespace).map(String.init)
}

func renderHumanSuccess(summary: String, artifacts: [String]) {
    print(summary)
    if !artifacts.isEmpty {
        print("artifacts:")
        for artifact in artifacts {
            print("- \(artifact)")
        }
    }
}

func printJSONPayload(
    command: String,
    status: String,
    exitCode: Int,
    summary: String,
    artifacts: [String] = []
) {
    let payload = CommandOutput(
        command: command,
        status: status,
        exitCode: exitCode,
        summary: summary,
        artifacts: artifacts
    )
    do {
        print(try payload.toJSONString())
    } catch {
        fputs("error: failed to encode JSON output\n", stderr)
    }
}

func printDoctorJSONPayload(
    status: String,
    exitCode: Int,
    summary: String,
    scope: String,
    findings: [DoctorFinding],
    installAttempts: [DoctorInstallAttempt],
    artifacts: [String]
) {
    let payload = DoctorCommandOutput(
        command: BosCommand.doctor.rawValue,
        status: status,
        exitCode: exitCode,
        summary: summary,
        scope: scope,
        findings: findings,
        installAttempts: installAttempts,
        artifacts: artifacts
    )
    do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        print(String(decoding: data, as: UTF8.self))
    } catch {
        fputs("error: failed to encode doctor JSON output\n", stderr)
    }
}

func printReleaseCheckJSONPayload(
    status: String,
    exitCode: Int,
    summary: String,
    mode: ReleaseCheckMode,
    failureCode: ReleaseCheckFailureCode?,
    failedStep: ReleaseCheckStep?,
    artifacts: [String]
) {
    let payload = ReleaseCheckCommandOutput(
        command: BosCommand.releaseCheck.rawValue,
        status: status,
        exitCode: exitCode,
        summary: summary,
        mode: mode.rawValue,
        failureCode: failureCode?.rawValue,
        failedStep: failedStep?.rawValue,
        artifacts: artifacts
    )
    do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        print(String(decoding: data, as: UTF8.self))
    } catch {
        fputs("error: failed to encode release-check JSON output\n", stderr)
    }
}

func printReleaseRunJSONPayload(
    status: String,
    exitCode: Int,
    summary: String,
    stage: ReleaseRunStage,
    failureCode: ReleaseRunFailureCode?,
    failedStep: ReleaseRunStep?,
    ipaPath: String?,
    artifacts: [String]
) {
    let payload = ReleaseRunCommandOutput(
        command: BosCommand.releaseRun.rawValue,
        status: status,
        exitCode: exitCode,
        summary: summary,
        stage: stage.rawValue,
        failureCode: failureCode?.rawValue,
        failedStep: failedStep?.rawValue,
        ipaPath: ipaPath,
        artifacts: artifacts
    )
    do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        print(String(decoding: data, as: UTF8.self))
    } catch {
        fputs("error: failed to encode release-run JSON output\n", stderr)
    }
}

func printAppRegisterJSONPayload(
    status: String,
    exitCode: Int,
    summary: String,
    metadata: AppRegistrationResolvedMetadata?,
    bundleIdStatus: AppRegistrationResourceStatus?,
    appStatus: AppRegistrationResourceStatus?,
    artifacts: [String]
) {
    let payload = AppRegisterCommandOutput(
        command: BosCommand.appRegister.rawValue,
        status: status,
        exitCode: exitCode,
        summary: summary,
        appIdentifier: metadata?.appIdentifier,
        appName: metadata?.appName,
        sku: metadata?.sku,
        primaryLanguage: metadata?.primaryLanguage,
        bundleIdStatus: bundleIdStatus?.rawValue,
        appStatus: appStatus?.rawValue,
        artifacts: artifacts
    )
    do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        print(String(decoding: data, as: UTF8.self))
    } catch {
        fputs("error: failed to encode app-register JSON output\n", stderr)
    }
}

func fail(
    message: String,
    command: BosCommand? = nil,
    format: OutputFormat = .human,
    exitCode: ExitCode = .contractValidationError
) -> Never {
    switch format {
    case .human:
        fputs("error: \(message)\n", stderr)
    case .json:
        printJSONPayload(
            command: command?.rawValue ?? "bos",
            status: "failed",
            exitCode: Int(exitCode.rawValue),
            summary: message
        )
    }
    exit(exitCode.rawValue)
}

struct ProcessVerifyRunner: VerifyCommandRunning {
    func run(command: [String], in workingDirectory: URL) throws -> VerifyCommandResult {
        let result = try runProcess(command: command, workingDirectory: workingDirectory)
        return VerifyCommandResult(
            exitCode: result.status,
            stdout: result.stdout,
            stderr: result.stderr
        )
    }
}

struct ProcessReleaseCheckRunner: ReleaseCheckCommandRunning {
    func run(command: [String], in workingDirectory: URL, environment: [String: String]) throws -> ReleaseCheckCommandResult {
        let result = try runProcess(
            command: command,
            workingDirectory: workingDirectory,
            environment: environment
        )
        return ReleaseCheckCommandResult(
            exitCode: result.status,
            stdout: result.stdout,
            stderr: result.stderr
        )
    }
}

struct ProcessReleaseRunRunner: ReleaseRunCommandRunning {
    func run(command: [String], in workingDirectory: URL, environment: [String: String]) throws -> ReleaseRunCommandResult {
        let result = try runProcess(
            command: command,
            workingDirectory: workingDirectory,
            environment: environment
        )
        return ReleaseRunCommandResult(
            exitCode: result.status,
            stdout: result.stdout,
            stderr: result.stderr
        )
    }
}

func parseDoctorScope(
    raw: String?,
    command: BosCommand,
    format: OutputFormat
) -> DoctorScope {
    guard let raw else { return .core }
    guard let scope = DoctorScope(rawValue: raw) else {
        fail(
            message: "invalid --for '\(raw)'. expected one of: core, all, plan, apply, verify, app-register, release-init, release-check, release-run",
            command: command,
            format: format
        )
    }
    return scope
}

func parseReleaseCheckMode(
    raw: String?,
    command: BosCommand,
    format: OutputFormat
) -> ReleaseCheckMode {
    guard let raw else { return .readonlyCerts }
    guard let mode = ReleaseCheckMode(rawValue: raw) else {
        fail(
            message: "invalid --mode '\(raw)'. expected one of: connectivity, readonly-certs, sync-certs",
            command: command,
            format: format
        )
    }
    return mode
}

func parseReleaseRunStage(
    raw: String?,
    command: BosCommand,
    format: OutputFormat
) -> ReleaseRunStage {
    guard let raw else { return .build }
    guard let stage = ReleaseRunStage(rawValue: raw) else {
        fail(
            message: "invalid --stage '\(raw)'. expected one of: build, beta, release, submit",
            command: command,
            format: format
        )
    }
    return stage
}

func detectXcodeSelectPath() -> String {
    guard let result = try? runProcess(command: ["xcode-select", "-p"]),
          result.status == 0 else { return "" }
    return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
}

func detectToolchain(lock: ToolchainLock) throws -> DetectedToolchain {
    let swift = detectVersion(command: ["swift", "--version"])
    let tuist = detectVersion(command: ["tuist", "version"])
    let fastlane = detectVersion(command: ["fastlane", "--version"])
    let git = detectVersion(command: ["git", "--version"])
    let env = ProcessInfo.processInfo.environment
    let tma = try ToolchainLock.TMAPluginRef(
        type: env["TMA_PLUGIN_REF_TYPE"] ?? lock.tmaPluginRef.type,
        value: env["TMA_PLUGIN_REF_VALUE"] ?? lock.tmaPluginRef.value
    )
    return DetectedToolchain(
        swift: swift,
        tuist: tuist,
        fastlane: fastlane,
        tmaPluginRef: tma,
        xcodeSelectPath: detectXcodeSelectPath(),
        brewPath: resolveBrewExecutable() ?? "",
        gitVersion: git
    )
}

func renderDoctorHuman(
    scope: DoctorScope,
    result: DoctorResult,
    installAttempts: [DoctorInstallAttempt],
    note: String?
) {
    if let note {
        print(note)
    }
    print(result.summary)
    print("scope: \(scope.rawValue)")

    let findings = result.findings
    if findings.isEmpty {
        print("findings: none")
    } else {
        print("findings:")
        for finding in findings {
            print("- \(finding.tool) [\(finding.severity.rawValue)/\(finding.status.rawValue)] expected=\(finding.expectedRule) actual=\(finding.actualVersion)")
            print("  action: \(finding.action)")
            if !finding.installCommands.isEmpty {
                print("  install:")
                for install in finding.installCommands {
                    print("  - \(install)")
                }
            }
        }
    }

    if !installAttempts.isEmpty {
        print("install-attempts:")
        for attempt in installAttempts {
            let detail = attempt.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if detail.isEmpty {
                print("- \(attempt.tool): \(attempt.status) (\(attempt.command))")
            } else {
                print("- \(attempt.tool): \(attempt.status) (\(attempt.command)) stderr=\(detail)")
            }
        }
    }

    if !result.artifacts.isEmpty {
        print("artifacts:")
        for artifact in result.artifacts {
            print("- \(artifact)")
        }
    }
}

func performDoctorAutoInstall(
    findings: [DoctorFinding],
    projectRoot: URL
) -> [DoctorInstallAttempt] {
    var attempts: [DoctorInstallAttempt] = []

    let missingTools = findings
        .filter { $0.severity == .required && $0.status != .installed && $0.tool != "swift" }
        .sorted { $0.tool < $1.tool }

    for finding in missingTools {
        if finding.tool == "fastlane" {
            attempts.append(contentsOf: installFastlaneWithBrew(projectRoot: projectRoot))
            continue
        }
        if finding.tool == "tuist" {
            attempts.append(contentsOf: installTuistWithBrew(projectRoot: projectRoot))
            continue
        }

        guard !finding.installCommands.isEmpty else {
            continue
        }

        var attempted = false
        for rawCommand in finding.installCommands {
            let tokens = tokenizeCommandLine(rawCommand)
            guard let executable = tokens.first else { continue }
            guard executable != "sudo" else { continue }
            guard commandExists(executable) else { continue }

            attempted = true
            do {
                let result = try runProcess(command: tokens, workingDirectory: projectRoot)
                let status = result.status == 0 ? "success" : "failed"
                attempts.append(
                    DoctorInstallAttempt(
                        tool: finding.tool,
                        command: rawCommand,
                        status: status,
                        exitCode: result.status,
                        stderr: result.stderr
                    )
                )
                if result.status == 0 {
                    break
                }
            } catch {
                attempts.append(
                    DoctorInstallAttempt(
                        tool: finding.tool,
                        command: rawCommand,
                        status: "failed",
                        exitCode: 1,
                        stderr: "\(error)"
                    )
                )
            }
        }

        if !attempted {
            attempts.append(
                DoctorInstallAttempt(
                    tool: finding.tool,
                    command: finding.installCommands.joined(separator: " || "),
                    status: "skipped-no-runner",
                    exitCode: 127,
                    stderr: "no available installer command found in current environment"
                )
            )
        }
    }

    return attempts
}

func runDoctor(args: [String], format: OutputFormat) {
    let parsed = parseOptions(
        args: args,
        valueFlags: ["--project-root", "--for", "--format"],
        booleanFlags: []
    )
    assertOptionContract(parsed: parsed, command: .doctor, format: format)

    let cwd = currentWorkingDirectoryURL()
    let projectRoot = resolvePath(parsed.values["--project-root"] ?? ".", base: cwd)
    let scope = parseDoctorScope(raw: parsed.values["--for"], command: .doctor, format: format)
    var initializationNote: String?
    let processEnvironment = ProcessInfo.processInfo.environment
    let autoInstallEnabled = !["0", "false", "no"].contains(
        processEnvironment["BOS_AUTO_INSTALL"]?.lowercased() ?? ""
    )

    let signingEnvironment: [String: String]
    if scope.commands.contains(ToolchainLock.commandAppRegister)
        || scope.commands.contains(ToolchainLock.commandReleaseInit)
        || scope.commands.contains(ToolchainLock.commandReleaseCheck)
        || scope.commands.contains(ToolchainLock.commandReleaseRun) {
        let profilePath = resolveProfilePathOrFail(
            raw: nil,
            projectRoot: projectRoot,
            command: .doctor,
            format: format
        )
        let profile: Profile
        do {
            profile = try decodeYAMLOrJSON(Profile.self, at: profilePath)
        } catch {
            fail(message: "\(error)", command: .doctor, format: format, exitCode: .doctorFailed)
        }
        do {
            let resolved = try resolveSigningEnvironment(
                projectRoot: projectRoot,
                profile: profile,
                processEnvironment: processEnvironment
            )
            signingEnvironment = resolved.environment
            if let note = resolved.note {
                initializationNote = note
            }
        } catch {
            fail(
                message: signingEnvironmentLoadErrorMessage(error, projectRoot: projectRoot),
                command: .doctor,
                format: format,
                exitCode: .doctorFailed
            )
        }
    } else {
        signingEnvironment = processEnvironment
    }

    let lockPath: URL
    if let existingLockPath = resolveToolchainLockPath(projectRoot: projectRoot) {
        lockPath = existingLockPath
    } else {
        let env = processEnvironment
        let tma = try? ToolchainLock.TMAPluginRef(
            type: env["TMA_PLUGIN_REF_TYPE"] ?? "git-sha",
            value: env["TMA_PLUGIN_REF_VALUE"] ?? "unknown"
        )
        guard let tma else {
            fail(
                message: "failed to initialize tma plugin reference from environment",
                command: .doctor,
                format: format
            )
        }

        let initialLock: ToolchainLock
        do {
            initialLock = try ToolchainLock.defaultPolicy(tmaPluginRef: tma)
            let encoded = try encodeYAML(initialLock)
            let destination = preferredToolchainLockPath(projectRoot: projectRoot)
            try writeTextFile(encoded, to: destination)
            lockPath = destination
            let initMessage = "Initialized toolchain lock at \(destination.path(percentEncoded: false))"
            if let existingNote = initializationNote {
                initializationNote = "\(existingNote). \(initMessage)"
            } else {
                initializationNote = initMessage
            }
        } catch {
            fail(message: "failed to initialize toolchain lock: \(error)", command: .doctor, format: format)
        }
    }

    let lock: ToolchainLock
    do {
        lock = try decodeToolchainLock(at: lockPath)
    } catch {
        fail(message: "\(error)", command: .doctor, format: format)
    }

    let initialDetected: DetectedToolchain
    do {
        initialDetected = try detectToolchain(lock: lock)
    } catch {
        fail(message: "\(error)", command: .doctor, format: format)
    }

    var result: DoctorResult
    do {
        result = try DoctorEngine().check(
            request: DoctorRequest(
                projectRoot: projectRoot,
                lock: lock,
                detected: initialDetected,
                checkCommands: scope.commands,
                environment: signingEnvironment
            )
        )
    } catch {
        fail(message: "\(error)", command: .doctor, format: format)
    }

    let installAttempts = autoInstallEnabled
        ? performDoctorAutoInstall(findings: result.findings, projectRoot: projectRoot)
        : []
    if !installAttempts.isEmpty {
        do {
            let detectedAfterInstall = try detectToolchain(lock: lock)
            result = try DoctorEngine().check(
                request: DoctorRequest(
                    projectRoot: projectRoot,
                    lock: lock,
                    detected: detectedAfterInstall,
                    checkCommands: scope.commands,
                    environment: signingEnvironment
                )
            )
        } catch {
            fail(message: "\(error)", command: .doctor, format: format)
        }
    }

    let summary: String
    if let initializationNote {
        summary = "\(initializationNote). \(result.summary)"
    } else {
        summary = result.summary
    }

    switch format {
    case .human:
        renderDoctorHuman(scope: scope, result: result, installAttempts: installAttempts, note: initializationNote)
    case .json:
        printDoctorJSONPayload(
            status: result.status,
            exitCode: result.exitCode,
            summary: summary,
            scope: scope.rawValue,
            findings: result.findings,
            installAttempts: installAttempts,
            artifacts: result.artifacts
        )
    }

    if result.exitCode == 0 {
        exit(ExitCode.success.rawValue)
    } else {
        exit(ExitCode.doctorFailed.rawValue)
    }
}

func readPlanMarkdownCorpus(from planDirectory: URL) throws -> String {
    var isDirectory: ObjCBool = false
    let fm = FileManager.default
    guard fm.fileExists(atPath: planDirectory.path(percentEncoded: false), isDirectory: &isDirectory), isDirectory.boolValue else {
        throw NSError(
            domain: "BosCLI.Plan",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "plan directory not found: \(planDirectory.path(percentEncoded: false))"]
        )
    }

    guard let enumerator = fm.enumerator(
        at: planDirectory,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
    ) else {
        throw NSError(
            domain: "BosCLI.Plan",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "failed to enumerate plan directory: \(planDirectory.path(percentEncoded: false))"]
        )
    }

    var markdownFiles: [URL] = []
    for case let file as URL in enumerator {
        let ext = file.pathExtension.lowercased()
        if ext == "md" || ext == "markdown" {
            markdownFiles.append(file)
        }
    }
    markdownFiles.sort { $0.path(percentEncoded: false) < $1.path(percentEncoded: false) }

    guard !markdownFiles.isEmpty else {
        throw NSError(
            domain: "BosCLI.Plan",
            code: 3,
            userInfo: [NSLocalizedDescriptionKey: "no markdown files found under plan directory: \(planDirectory.path(percentEncoded: false))"]
        )
    }

    let chunks = try markdownFiles.map { url in
        try String(contentsOf: url, encoding: .utf8)
    }
    return chunks.joined(separator: "\n\n")
}

func planErrorMessage(_ error: PlanEngineError) -> String {
    switch error {
    case .missingReqIDs:
        return "requirements not found. add `REQ-001` markers or `FR-001` markers in PRD/PLAN documents."
    case .missingScreens:
        return "screens not found. add `SCR_HOME` markers or include screen keywords (Today/Shelf/Capture/Focus/Reflection/Weekly Review/Settings)."
    case .missingEntities:
        return "entities not found. add `Entity: User` lines or numbered domain headings such as `11.1 Item`."
    case .missingAppIdentifier:
        return "missing App Identifier. add it to `.bos/config/profile.yaml` identity.appIdentifier, documents, or pass `--app-identifier com.example.app`."
    case .missingAppleTeamID:
        return "missing Apple Team ID. add it to `.bos/config/profile.yaml` identity.appleTeamId, documents, or pass `--apple-team-id ABCD123456`."
    case .missingBundleIdPrefix:
        return "failed to derive bundle prefix. check `App Identifier` format (example: com.example.app)."
    }
}

func runPlan(args: [String], format: OutputFormat) {
    let parsed = parseOptions(
        args: args,
        valueFlags: [
            "--project-root",
            "--prd",
            "--plan-dir",
            "--profile",
            "--out",
            "--company-name",
            "--app-name",
            "--app-identifier",
            "--apple-team-id",
            "--primary-language",
            "--sku",
            "--format"
        ],
        booleanFlags: []
    )
    assertOptionContract(parsed: parsed, command: .plan, format: format)

    let outRaw = parsed.values["--out"] ?? ".bos/plan/blueprint.yaml"

    let prdRaw = parsed.values["--prd"]
    let planDirRaw = parsed.values["--plan-dir"]
    if (prdRaw == nil) == (planDirRaw == nil) {
        fail(
            message: "choose exactly one input source: --prd <path> or --plan-dir <path>",
            command: .plan,
            format: format
        )
    }

    let cwd = currentWorkingDirectoryURL()
    let projectRoot = resolvePath(parsed.values["--project-root"] ?? ".", base: cwd)
    let profilePath = resolveProfilePathOrFail(
        raw: parsed.values["--profile"],
        projectRoot: projectRoot,
        command: .plan,
        format: format
    )
    let outPath = resolvePath(outRaw, base: projectRoot)

    do {
        let profile = try decodeYAMLOrJSON(Profile.self, at: profilePath)
        let deriveOptions = PlanDeriveOptions(
            appName: parsed.values["--app-name"] ?? profile.configuredAppName,
            appIdentifier: parsed.values["--app-identifier"] ?? profile.configuredAppIdentifier,
            appleTeamID: parsed.values["--apple-team-id"] ?? profile.configuredAppleTeamId,
            companyName: parsed.values["--company-name"] ?? profile.configuredCompanyName,
            primaryLanguage: parsed.values["--primary-language"] ?? profile.configuredPrimaryLanguage,
            sku: parsed.values["--sku"] ?? profile.configuredSKU
        )
        let prd: String
        if let prdRaw {
            let prdPath = resolvePath(prdRaw, base: projectRoot)
            prd = try readTextFile(prdPath)
        } else if let planDirRaw {
            let planDirPath = resolvePath(planDirRaw, base: projectRoot)
            let corpus = try readPlanMarkdownCorpus(from: planDirPath)
            prd = PlanEngine().derivePRD(fromPlanText: corpus, options: deriveOptions)
        } else {
            fail(
                message: "choose exactly one input source: --prd <path> or --plan-dir <path>",
                command: .plan,
                format: format
            )
        }

        let blueprint = try PlanEngine().generateBlueprint(prd: prd, profile: profile, options: deriveOptions)
        let encoded = try encodeYAML(blueprint)
        try writeTextFile(encoded, to: outPath)

        let summary = "Blueprint generated at \(outPath.path(percentEncoded: false))"
        let artifacts = [outPath.path(percentEncoded: false)]
        switch format {
        case .human:
            renderHumanSuccess(summary: summary, artifacts: artifacts)
        case .json:
            printJSONPayload(
                command: BosCommand.plan.rawValue,
                status: "success",
                exitCode: Int(ExitCode.success.rawValue),
                summary: summary,
                artifacts: artifacts
            )
        }
        exit(ExitCode.success.rawValue)
    } catch let error as PlanEngineError {
        fail(message: planErrorMessage(error), command: .plan, format: format)
    } catch {
        fail(message: "\(error)", command: .plan, format: format)
    }
}

func copyIfExists(from source: URL, to destination: URL) throws {
    let fm = FileManager.default
    guard fm.fileExists(atPath: source.path(percentEncoded: false)) else { return }
    try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
    if fm.fileExists(atPath: destination.path(percentEncoded: false)) {
        try fm.removeItem(at: destination)
    }
    try fm.copyItem(at: source, to: destination)
}

func runApply(args: [String], format: OutputFormat) {
    let parsed = parseOptions(
        args: args,
        valueFlags: ["--project-root", "--blueprint", "--profile", "--mode", "--format", "--app-identifier", "--apple-team-id"],
        booleanFlags: ["--fix", "--dry-run"]
    )
    assertOptionContract(parsed: parsed, command: .apply, format: format)

    let cwd = currentWorkingDirectoryURL()
    let projectRoot = resolvePath(parsed.values["--project-root"] ?? ".", base: cwd)
    let blueprintPath = resolveBlueprintPathOrFail(
        raw: parsed.values["--blueprint"],
        projectRoot: projectRoot,
        command: .apply,
        format: format
    )
    let profilePath = resolveProfilePathOrFail(
        raw: parsed.values["--profile"],
        projectRoot: projectRoot,
        command: .apply,
        format: format
    )

    let modeRaw = parsed.values["--mode"] ?? ApplyMode.initMode.rawValue
    guard let mode = ApplyMode(rawValue: modeRaw) else {
        fail(message: "invalid --mode '\(modeRaw)'", command: .apply, format: format)
    }
    let fix = parsed.flags.contains("--fix")
    let dryRun = parsed.flags.contains("--dry-run")

    let bundleIdPrefixOverride: String? = parsed.values["--app-identifier"].flatMap { id in
        let chunks = id.split(separator: ".").map(String.init)
        return chunks.count >= 2 ? chunks.dropLast().joined(separator: ".") : nil
    }
    let appleTeamIdOverride = parsed.values["--apple-team-id"]

    do {
        let blueprint = try decodeYAMLOrJSON(Blueprint.self, at: blueprintPath)
        let profile = try decodeYAMLOrJSON(Profile.self, at: profilePath)
        let engine = ApplyEngine()

        if dryRun {
            let sandboxRoot = FileManager.default.temporaryDirectory
                .appendingPathComponent("bos-dry-run-\(ProcessInfo.processInfo.globallyUniqueString)", isDirectory: true)
            try FileManager.default.createDirectory(at: sandboxRoot, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: sandboxRoot) }

            if mode == .incremental {
                let source = projectRoot.appending(path: "Projects/App/Sources/Dependencies/AppComposition.swift")
                let target = sandboxRoot.appending(path: "Projects/App/Sources/Dependencies/AppComposition.swift")
                try copyIfExists(from: source, to: target)
            }

            _ = try engine.apply(
                request: ApplyRequest(
                    projectRoot: sandboxRoot,
                    blueprint: blueprint,
                    profile: profile,
                    mode: mode,
                    fix: fix,
                    bundleIdPrefixOverride: bundleIdPrefixOverride,
                    appleTeamIdOverride: appleTeamIdOverride
                )
            )

            let summary = "Dry-run passed: no files were written to \(projectRoot.path(percentEncoded: false))"
            switch format {
            case .human:
                renderHumanSuccess(summary: summary, artifacts: [])
            case .json:
                printJSONPayload(
                    command: BosCommand.apply.rawValue,
                    status: "success",
                    exitCode: Int(ExitCode.success.rawValue),
                    summary: summary,
                    artifacts: []
                )
            }
            exit(ExitCode.success.rawValue)
        }

        let result = try engine.apply(
            request: ApplyRequest(
                projectRoot: projectRoot,
                blueprint: blueprint,
                profile: profile,
                mode: mode,
                fix: fix,
                bundleIdPrefixOverride: bundleIdPrefixOverride,
                appleTeamIdOverride: appleTeamIdOverride
            )
        )

        let summary = "Apply completed (\(mode.rawValue))"
        let artifacts = result.artifacts + [result.lockFile]
        switch format {
        case .human:
            renderHumanSuccess(summary: summary, artifacts: artifacts)
        case .json:
            printJSONPayload(
                command: BosCommand.apply.rawValue,
                status: "success",
                exitCode: Int(ExitCode.success.rawValue),
                summary: summary,
                artifacts: artifacts
            )
        }
        exit(ExitCode.success.rawValue)
    } catch let error as ApplyEngineError {
        switch error {
        case .driftDetected, .managedBlockMissing, .anchorMismatch, .outsideManagedAreaChanged:
            let summary = "\(error)"
            switch format {
            case .human:
                fputs("error: \(summary)\n", stderr)
            case .json:
                printJSONPayload(
                    command: BosCommand.apply.rawValue,
                    status: "failed",
                    exitCode: Int(ExitCode.driftDetected.rawValue),
                    summary: summary
                )
            }
            exit(ExitCode.driftDetected.rawValue)
        case .unsupportedMode, .scaffoldFailed, .tmaPluginResourceMissing:
            fail(message: "\(error)", command: .apply, format: format)
        }
    } catch {
        fail(message: "\(error)", command: .apply, format: format)
    }
}

func runVerify(args: [String], format: OutputFormat) {
    let parsed = parseOptions(
        args: args,
        valueFlags: ["--project-root", "--profile", "--format"],
        booleanFlags: []
    )
    assertOptionContract(parsed: parsed, command: .verify, format: format)

    let cwd = currentWorkingDirectoryURL()
    let projectRoot = resolvePath(parsed.values["--project-root"] ?? ".", base: cwd)
    let profilePath = resolveProfilePathOrFail(
        raw: parsed.values["--profile"],
        projectRoot: projectRoot,
        command: .verify,
        format: format
    )

    do {
        let profile = try decodeYAMLOrJSON(Profile.self, at: profilePath)
        let engine = VerifyEngine(runner: ProcessVerifyRunner())
        let result = try engine.verify(request: VerifyRequest(projectRoot: projectRoot, profile: profile))
        switch format {
        case .human:
            renderHumanSuccess(summary: result.summary, artifacts: result.artifacts)
        case .json:
            printJSONPayload(
                command: BosCommand.verify.rawValue,
                status: "success",
                exitCode: Int(ExitCode.success.rawValue),
                summary: result.summary,
                artifacts: result.artifacts
            )
        }
        exit(ExitCode.success.rawValue)
    } catch let error as VerifyEngineError {
        switch error {
        case .commandFailed(let classification, let step, _, _):
            let summary = "verify failed at \(step.rawValue) (\(classification.rawValue))"
            switch format {
            case .human:
                fputs("error: \(summary)\n", stderr)
            case .json:
                printJSONPayload(
                    command: BosCommand.verify.rawValue,
                    status: "failed",
                    exitCode: Int(ExitCode.verifyFailed.rawValue),
                    summary: summary
                )
            }
            exit(ExitCode.verifyFailed.rawValue)
        }
    } catch {
        fail(message: "\(error)", command: .verify, format: format)
    }
}

func runAppRegister(args: [String], format: OutputFormat) {
    let parsed = parseOptions(
        args: args,
        valueFlags: [
            "--project-root",
            "--profile",
            "--blueprint",
            "--company-name",
            "--app-name",
            "--app-identifier",
            "--apple-team-id",
            "--primary-language",
            "--sku",
            "--match-git-url",
            "--format"
        ],
        booleanFlags: []
    )
    assertOptionContract(parsed: parsed, command: .appRegister, format: format)

    let cwd = currentWorkingDirectoryURL()
    let projectRoot = resolvePath(parsed.values["--project-root"] ?? ".", base: cwd)
    let profilePath = resolveProfilePathOrFail(
        raw: parsed.values["--profile"],
        projectRoot: projectRoot,
        command: .appRegister,
        format: format
    )

    let profile: Profile
    do {
        profile = try decodeYAMLOrJSON(Profile.self, at: profilePath)
    } catch {
        fail(message: "\(error)", command: .appRegister, format: format)
    }

    let blueprint: Blueprint?
    do {
        if let blueprintPath = resolveOptionalBlueprintPath(
            raw: parsed.values["--blueprint"],
            projectRoot: projectRoot
        ) {
            blueprint = try decodeYAMLOrJSON(Blueprint.self, at: blueprintPath)
        } else {
            blueprint = nil
        }
    } catch {
        fail(message: "\(error)", command: .appRegister, format: format)
    }

    let signingContext: (environment: [String: String], note: String?)
    do {
        signingContext = try resolveSigningEnvironment(
            projectRoot: projectRoot,
            processEnvironment: ProcessInfo.processInfo.environment
        )
    } catch {
        fail(
            message: signingEnvironmentLoadErrorMessage(error, projectRoot: projectRoot),
            command: .appRegister,
            format: format,
            exitCode: .appRegisterFailed
        )
    }

    do {
        let overrides = AppRegistrationOverrides(
            companyName: parsed.values["--company-name"],
            appName: parsed.values["--app-name"],
            appIdentifier: parsed.values["--app-identifier"],
            appleTeamId: parsed.values["--apple-team-id"],
            primaryLanguage: parsed.values["--primary-language"],
            sku: parsed.values["--sku"],
            matchGitURL: parsed.values["--match-git-url"]
        )
        let result = try AppRegistrationEngine().register(
            request: AppRegistrationRequest(
                projectRoot: projectRoot,
                profile: profile,
                blueprint: blueprint,
                overrides: overrides,
                environment: signingContext.environment
            )
        )

        let encodedProfile = try encodeYAML(result.syncedProfile)
        try writeTextFile(encodedProfile, to: profilePath)

        let summaryBase = "app-register completed (\(result.bundleIdStatus.rawValue), \(result.appStatus.rawValue))"
        let summary = signingContext.note.map { "\($0). \(summaryBase)" } ?? summaryBase
        let artifacts = result.artifacts + [profilePath.path(percentEncoded: false)]
        switch format {
        case .human:
            renderHumanSuccess(summary: summary, artifacts: artifacts)
        case .json:
            printAppRegisterJSONPayload(
                status: "success",
                exitCode: Int(ExitCode.success.rawValue),
                summary: summary,
                metadata: result.metadata,
                bundleIdStatus: result.bundleIdStatus,
                appStatus: result.appStatus,
                artifacts: artifacts
            )
        }
        exit(ExitCode.success.rawValue)
    } catch let error as AppRegistrationEngineError {
        let summary: String
        switch error {
        case .missingRequiredFields(let fields):
            summary = "missing required fields: \(fields.joined(separator: ", ")). add them to `.bos/config/profile.yaml` or pass flags."
        case .invalidValue(let field, let reason):
            summary = "\(field): \(reason)"
        case .invalidEnvironment(let missingKeys, let invalidIssues):
            let path = defaultSigningEnvironmentPath(projectRoot: projectRoot).path(percentEncoded: false)
            let parts = [
                missingKeys.isEmpty ? nil : "missing=\(missingKeys.joined(separator: ","))",
                invalidIssues.isEmpty ? nil : "invalid=\(invalidIssues.joined(separator: ","))"
            ].compactMap { $0 }
            summary = "invalid App Store Connect environment: \(parts.joined(separator: " ")). check \(path)"
        case .providerFailure(let providerSummary, let artifacts):
            switch format {
            case .human:
                fputs("error: \(providerSummary)\n", stderr)
            case .json:
                printAppRegisterJSONPayload(
                    status: "failed",
                    exitCode: Int(ExitCode.appRegisterFailed.rawValue),
                    summary: providerSummary,
                    metadata: nil,
                    bundleIdStatus: nil,
                    appStatus: nil,
                    artifacts: artifacts
                )
            }
            exit(ExitCode.appRegisterFailed.rawValue)
        }

        switch format {
        case .human:
            fputs("error: \(summary)\n", stderr)
        case .json:
            printAppRegisterJSONPayload(
                status: "failed",
                exitCode: Int(ExitCode.appRegisterFailed.rawValue),
                summary: summary,
                metadata: nil,
                bundleIdStatus: nil,
                appStatus: nil,
                artifacts: []
            )
        }
        exit(ExitCode.appRegisterFailed.rawValue)
    } catch {
        fail(
            message: "\(error)",
            command: .appRegister,
            format: format,
            exitCode: .appRegisterFailed
        )
    }
}

func runReleaseInit(args: [String], format: OutputFormat) {
    let parsed = parseOptions(
        args: args,
        valueFlags: ["--project-root", "--blueprint", "--profile", "--format"],
        booleanFlags: []
    )
    assertOptionContract(parsed: parsed, command: .releaseInit, format: format)

    let cwd = currentWorkingDirectoryURL()
    let projectRoot = resolvePath(parsed.values["--project-root"] ?? ".", base: cwd)
    let blueprintPath = resolveBlueprintPathOrFail(
        raw: parsed.values["--blueprint"],
        projectRoot: projectRoot,
        command: .releaseInit,
        format: format
    )
    let profilePath = resolveProfilePathOrFail(
        raw: parsed.values["--profile"],
        projectRoot: projectRoot,
        command: .releaseInit,
        format: format
    )

    let profile: Profile
    do {
        profile = try decodeYAMLOrJSON(Profile.self, at: profilePath)
    } catch {
        fail(message: "\(error)", command: .releaseInit, format: format)
    }

    let signingContext: (environment: [String: String], note: String?)
    do {
        signingContext = try resolveSigningEnvironment(
            projectRoot: projectRoot,
            profile: profile,
            processEnvironment: ProcessInfo.processInfo.environment
        )
    } catch {
        fail(
            message: signingEnvironmentLoadErrorMessage(error, projectRoot: projectRoot),
            command: .releaseInit,
            format: format,
            exitCode: .releaseInitFailed
        )
    }

    do {
        let blueprint = try decodeYAMLOrJSON(Blueprint.self, at: blueprintPath)
        let result = try ReleaseInitEngine().releaseInit(
            request: ReleaseInitRequest(
                projectRoot: projectRoot,
                blueprint: blueprint,
                profile: profile,
                environment: signingContext.environment
            )
        )
        let summaryBase = "release-init completed with \(result.generatedFiles.count) generated files"
        let summary: String
        if let note = signingContext.note {
            summary = "\(note). \(summaryBase)"
        } else {
            summary = summaryBase
        }
        switch format {
        case .human:
            renderHumanSuccess(summary: summary, artifacts: result.artifacts + result.generatedFiles)
        case .json:
            printJSONPayload(
                command: BosCommand.releaseInit.rawValue,
                status: "success",
                exitCode: Int(ExitCode.success.rawValue),
                summary: summary,
                artifacts: result.artifacts + result.generatedFiles
            )
        }
        exit(ExitCode.success.rawValue)
    } catch let error as ReleaseInitEngineError {
        let summary: String
        switch error {
        case .missingRequiredEnvironment(let keys):
            let path = defaultSigningEnvironmentPath(projectRoot: projectRoot).path(percentEncoded: false)
            summary = "missing required environment: \(keys.joined(separator: ", ")). set values in \(path) or shell environment"
        case .invalidEnvironmentFormat(let details):
            let path = defaultSigningEnvironmentPath(projectRoot: projectRoot).path(percentEncoded: false)
            summary = "invalid environment format: \(details.joined(separator: ", ")). check \(path)"
        case .laneParseFailed(let path):
            summary = "failed to parse fastlane lanes from \(path)"
        }
        switch format {
        case .human:
            fputs("error: \(summary)\n", stderr)
        case .json:
            printJSONPayload(
                command: BosCommand.releaseInit.rawValue,
                status: "failed",
                exitCode: Int(ExitCode.releaseInitFailed.rawValue),
                summary: summary
            )
        }
        exit(ExitCode.releaseInitFailed.rawValue)
    } catch {
        fail(message: "\(error)", command: .releaseInit, format: format)
    }
}

func runReleaseCheck(args: [String], format: OutputFormat) {
    let parsed = parseOptions(
        args: args,
        valueFlags: ["--project-root", "--profile", "--mode", "--format"],
        booleanFlags: ["--allow-write"]
    )
    assertOptionContract(parsed: parsed, command: .releaseCheck, format: format)

    let cwd = currentWorkingDirectoryURL()
    let projectRoot = resolvePath(parsed.values["--project-root"] ?? ".", base: cwd)
    let profilePath = resolveProfilePathOrFail(
        raw: parsed.values["--profile"],
        projectRoot: projectRoot,
        command: .releaseCheck,
        format: format
    )
    let mode = parseReleaseCheckMode(
        raw: parsed.values["--mode"],
        command: .releaseCheck,
        format: format
    )
    let allowWrite = parsed.flags.contains("--allow-write")

    if mode == .syncCerts && !allowWrite {
        fail(
            message: "`--mode sync-certs` requires explicit `--allow-write`",
            command: .releaseCheck,
            format: format
        )
    }
    if allowWrite && mode != .syncCerts {
        fail(
            message: "`--allow-write` is only valid with `--mode sync-certs`",
            command: .releaseCheck,
            format: format
        )
    }

    let profile: Profile
    do {
        profile = try decodeYAMLOrJSON(Profile.self, at: profilePath)
    } catch {
        fail(message: "\(error)", command: .releaseCheck, format: format)
    }

    let signingContext: (environment: [String: String], note: String?)
    do {
        signingContext = try resolveSigningEnvironment(
            projectRoot: projectRoot,
            profile: profile,
            processEnvironment: ProcessInfo.processInfo.environment
        )
    } catch {
        fail(
            message: signingEnvironmentLoadErrorMessage(error, projectRoot: projectRoot),
            command: .releaseCheck,
            format: format,
            exitCode: .releaseCheckFailed
        )
    }

    do {
        let result = try ReleaseCheckEngine(
            runner: ProcessReleaseCheckRunner()
        ).releaseCheck(
            request: ReleaseCheckRequest(
                projectRoot: projectRoot,
                profile: profile,
                environment: signingContext.environment,
                mode: mode
            )
        )

        let summary: String
        if let note = signingContext.note {
            summary = "\(note). \(result.summary)"
        } else {
            summary = result.summary
        }

        switch format {
        case .human:
            renderHumanSuccess(summary: summary, artifacts: result.artifacts)
        case .json:
            printReleaseCheckJSONPayload(
                status: "success",
                exitCode: Int(ExitCode.success.rawValue),
                summary: summary,
                mode: result.mode,
                failureCode: nil,
                failedStep: nil,
                artifacts: result.artifacts
            )
        }
        exit(ExitCode.success.rawValue)
    } catch let error as ReleaseCheckEngineError {
        switch error {
        case .failed(let classification, let step, let summary, _, let artifacts):
            switch format {
            case .human:
                fputs("error: \(summary)\n", stderr)
            case .json:
                printReleaseCheckJSONPayload(
                    status: "failed",
                    exitCode: Int(ExitCode.releaseCheckFailed.rawValue),
                    summary: summary,
                    mode: mode,
                    failureCode: classification,
                    failedStep: step,
                    artifacts: artifacts
                )
            }
            exit(ExitCode.releaseCheckFailed.rawValue)
        }
    } catch {
        fail(
            message: "\(error)",
            command: .releaseCheck,
            format: format,
            exitCode: .releaseCheckFailed
        )
    }
}

func runReleaseRun(args: [String], format: OutputFormat) {
    let parsed = parseOptions(
        args: args,
        valueFlags: ["--project-root", "--blueprint", "--profile", "--stage", "--format"],
        booleanFlags: ["--allow-signing-write"]
    )
    assertOptionContract(parsed: parsed, command: .releaseRun, format: format)

    let cwd = currentWorkingDirectoryURL()
    let projectRoot = resolvePath(parsed.values["--project-root"] ?? ".", base: cwd)
    let blueprintPath = resolveBlueprintPathOrFail(
        raw: parsed.values["--blueprint"],
        projectRoot: projectRoot,
        command: .releaseRun,
        format: format
    )
    let profilePath = resolveProfilePathOrFail(
        raw: parsed.values["--profile"],
        projectRoot: projectRoot,
        command: .releaseRun,
        format: format
    )
    let stage = parseReleaseRunStage(
        raw: parsed.values["--stage"],
        command: .releaseRun,
        format: format
    )
    let allowSigningWrite = parsed.flags.contains("--allow-signing-write")

    let profile: Profile
    let blueprint: Blueprint
    do {
        profile = try decodeYAMLOrJSON(Profile.self, at: profilePath)
        blueprint = try decodeYAMLOrJSON(Blueprint.self, at: blueprintPath)
    } catch {
        fail(message: "\(error)", command: .releaseRun, format: format)
    }

    let signingContext: (environment: [String: String], note: String?)
    do {
        signingContext = try resolveSigningEnvironment(
            projectRoot: projectRoot,
            profile: profile,
            processEnvironment: ProcessInfo.processInfo.environment
        )
    } catch {
        fail(
            message: signingEnvironmentLoadErrorMessage(error, projectRoot: projectRoot),
            command: .releaseRun,
            format: format,
            exitCode: .releaseRunFailed
        )
    }

    do {
        let releaseChecker = ReleaseCheckEngine(runner: ProcessReleaseCheckRunner())
        let result = try ReleaseRunEngine(
            runner: ProcessReleaseRunRunner(),
            releaseChecker: releaseChecker
        ).run(
            request: ReleaseRunRequest(
                projectRoot: projectRoot,
                blueprint: blueprint,
                profile: profile,
                environment: signingContext.environment,
                stage: stage,
                allowSigningWrite: allowSigningWrite
            )
        )

        let summary = signingContext.note.map { "\($0). \(result.summary)" } ?? result.summary
        switch format {
        case .human:
            renderHumanSuccess(summary: summary, artifacts: result.artifacts)
        case .json:
            printReleaseRunJSONPayload(
                status: "success",
                exitCode: Int(ExitCode.success.rawValue),
                summary: summary,
                stage: result.stage,
                failureCode: nil,
                failedStep: nil,
                ipaPath: result.ipaPath,
                artifacts: result.artifacts
            )
        }
        exit(ExitCode.success.rawValue)
    } catch let error as ReleaseRunEngineError {
        switch error {
        case .failed(let classification, let step, let summary, _, let artifacts):
            switch format {
            case .human:
                fputs("error: \(summary)\n", stderr)
            case .json:
                printReleaseRunJSONPayload(
                    status: "failed",
                    exitCode: Int(ExitCode.releaseRunFailed.rawValue),
                    summary: summary,
                    stage: stage,
                    failureCode: classification,
                    failedStep: step,
                    ipaPath: artifacts.first(where: { $0.hasSuffix(".ipa") }),
                    artifacts: artifacts
                )
            }
            exit(ExitCode.releaseRunFailed.rawValue)
        }
    } catch {
        fail(
            message: "\(error)",
            command: .releaseRun,
            format: format,
            exitCode: .releaseRunFailed
        )
    }
}

func run() {
    let args = Array(CommandLine.arguments.dropFirst())
    let outputFormat = parseOutputFormat(from: args)

    guard let first = args.first else {
        printRootHelp()
        exit(ExitCode.success.rawValue)
    }

    if first == "-h" || first == "--help" || first == "help" {
        if args.count > 1, let command = BosCommand(rawValue: args[1]) {
            printCommandHelp(command)
        } else {
            printRootHelp()
        }
        exit(ExitCode.success.rawValue)
    }

    guard let command = BosCommand(rawValue: first) else {
        fail(message: "unknown command '\(first)'", format: outputFormat)
    }

    let rest = Array(args.dropFirst())
    if rest.contains("-h") || rest.contains("--help") {
        printCommandHelp(command)
        exit(ExitCode.success.rawValue)
    }

    switch command {
    case .doctor:
        runDoctor(args: rest, format: outputFormat)
    case .plan:
        runPlan(args: rest, format: outputFormat)
    case .apply:
        runApply(args: rest, format: outputFormat)
    case .verify:
        runVerify(args: rest, format: outputFormat)
    case .appRegister:
        runAppRegister(args: rest, format: outputFormat)
    case .releaseInit:
        runReleaseInit(args: rest, format: outputFormat)
    case .releaseCheck:
        runReleaseCheck(args: rest, format: outputFormat)
    case .releaseRun:
        runReleaseRun(args: rest, format: outputFormat)
    }
}

run()
