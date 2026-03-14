import Foundation
import BosCore
import os

private func drainPipeToBuffer(
    _ pipe: Pipe,
    buffer: ThreadSafeDataBuffer
) -> DispatchGroup {
    let group = DispatchGroup()
    group.enter()
    DispatchQueue.global(qos: .userInitiated).async {
        buffer.append(pipe.fileHandleForReading.readDataToEndOfFile())
        group.leave()
    }
    return group
}

private struct ThreadSafeDataBuffer: Sendable {
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
    let stdoutGroup = drainPipeToBuffer(stdoutPipe, buffer: stdoutBuffer)
    let stderrGroup = drainPipeToBuffer(stderrPipe, buffer: stderrBuffer)

    try process.run()
    process.waitUntilExit()
    stdoutGroup.wait()
    stderrGroup.wait()

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
