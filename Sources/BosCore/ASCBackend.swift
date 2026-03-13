import Foundation

public struct ASCCommandResult: Sendable, Equatable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

    public init(exitCode: Int32, stdout: String = "", stderr: String = "") {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }
}

public protocol ASCCommandRunning: Sendable {
    func run(command: [String], in workingDirectory: URL, environment: [String: String]) throws -> ASCCommandResult
}

public enum ASCBackendError: Error, Equatable {
    case invalidEnvironment(missingKeys: [String], invalidIssues: [String])
}

public struct ASCBackend: Sendable {
    public let executable: String
    private let runner: any ASCCommandRunning

    public init(
        executable: String = "asc",
        runner: any ASCCommandRunning = ProcessASCCommandRunner()
    ) {
        self.executable = executable
        self.runner = runner
    }

    public func curatedEnvironment(
        projectRoot: URL,
        environment: [String: String],
        appStoreAppId: String? = nil
    ) throws -> [String: String] {
        let check = SigningEnvironmentPolicy.validateAppStoreConnect(environment: environment)
        if !check.missingKeys.isEmpty || !check.invalidIssues.isEmpty {
            throw ASCBackendError.invalidEnvironment(
                missingKeys: check.missingKeys,
                invalidIssues: check.invalidIssues.map { "\($0.key)(\($0.rule))" }.sorted()
            )
        }

        var curated = environment
        curated["ASC_BYPASS_KEYCHAIN"] = "1"
        curated["ASC_STRICT_AUTH"] = "1"
        curated["ASC_PRIVATE_KEY_B64"] = environment["ASC_KEY_P8_BASE64"]
        curated["ASC_CONFIG_PATH"] = blockedConfigPath(projectRoot: projectRoot)
        if let appStoreAppId {
            curated["ASC_APP_ID"] = appStoreAppId
        } else {
            curated.removeValue(forKey: "ASC_APP_ID")
        }
        return curated
    }

    public func run(
        arguments: [String],
        projectRoot: URL,
        environment: [String: String],
        appStoreAppId: String? = nil
    ) throws -> ASCCommandResult {
        let curated = try curatedEnvironment(
            projectRoot: projectRoot,
            environment: environment,
            appStoreAppId: appStoreAppId
        )
        return try runner.run(
            command: [executable] + arguments,
            in: projectRoot,
            environment: curated
        )
    }

    public static func sanitizeSecrets(_ text: String, environment: [String: String]) -> String {
        SecretRedactionSupport.redact(
            text,
            environment: environment,
            keys: ["ASC_KEY_P8_BASE64", "ASC_PRIVATE_KEY_B64", "MATCH_PASSWORD"]
        )
    }

    private func blockedConfigPath(projectRoot: URL) -> String {
        projectRoot
            .standardizedFileURL
            .appending(path: ".bos/runtime/asc/no-config-\(RuntimeSupport.timestamp()).json")
            .path(percentEncoded: false)
    }
}

public struct ProcessASCCommandRunner: ASCCommandRunning {
    public init() {}

    public func run(command: [String], in workingDirectory: URL, environment: [String: String]) throws -> ASCCommandResult {
        final class DataBuffer: @unchecked Sendable {
            private let lock = NSLock()
            private var storage = Data()

            func append(_ data: Data) {
                lock.lock()
                storage.append(data)
                lock.unlock()
            }

            func snapshot() -> Data {
                lock.lock()
                defer { lock.unlock() }
                return storage
            }
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = command
        process.currentDirectoryURL = workingDirectory
        process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let stdoutBuffer = DataBuffer()
        let stderrBuffer = DataBuffer()
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

        stdoutBuffer.append(stdoutPipe.fileHandleForReading.readDataToEndOfFile())
        stderrBuffer.append(stderrPipe.fileHandleForReading.readDataToEndOfFile())

        return ASCCommandResult(
            exitCode: process.terminationStatus,
            stdout: String(decoding: stdoutBuffer.snapshot(), as: UTF8.self),
            stderr: String(decoding: stderrBuffer.snapshot(), as: UTF8.self)
        )
    }
}
