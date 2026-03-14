import Foundation

public enum DeviceSubcommand: String, Codable, Sendable, CaseIterable {
    case list
    case register
    case install
    case launch
    case logs
    case doctor
}

public enum DeviceFailureCode: String, Codable, Sendable, Equatable {
    case validation = "E-DEVICE-VALIDATION"
    case execution = "E-DEVICE-EXECUTION"
    case unsupported = "E-DEVICE-UNSUPPORTED"
}

public struct DeviceRequest: Sendable {
    public let projectRoot: URL
    public let subcommand: DeviceSubcommand
    public let deviceID: String?
    public let name: String?
    public let appPath: String?
    public let bundleIdentifier: String?

    public init(
        projectRoot: URL,
        subcommand: DeviceSubcommand,
        deviceID: String? = nil,
        name: String? = nil,
        appPath: String? = nil,
        bundleIdentifier: String? = nil
    ) {
        self.projectRoot = projectRoot
        self.subcommand = subcommand
        self.deviceID = deviceID
        self.name = name
        self.appPath = appPath
        self.bundleIdentifier = bundleIdentifier
    }
}

public struct DeviceResult: Sendable {
    public let artifacts: [String]
    public let summary: String
    public let devices: [DeviceRecord]
    public let targetDevice: String?
    public let appPath: String?
    public let bundleIdentifier: String?
    public let logLines: [String]
    public let findings: [String]

    public init(
        artifacts: [String],
        summary: String,
        devices: [DeviceRecord] = [],
        targetDevice: String? = nil,
        appPath: String? = nil,
        bundleIdentifier: String? = nil,
        logLines: [String] = [],
        findings: [String] = []
    ) {
        self.artifacts = artifacts
        self.summary = summary
        self.devices = devices
        self.targetDevice = targetDevice
        self.appPath = appPath
        self.bundleIdentifier = bundleIdentifier
        self.logLines = logLines
        self.findings = findings
    }
}

public enum DeviceEngineError: Error {
    case failed(
        classification: DeviceFailureCode,
        summary: String,
        artifacts: [String],
        devices: [DeviceRecord],
        targetDevice: String?,
        appPath: String?,
        bundleIdentifier: String?,
        logLines: [String],
        findings: [String]
    )
}

public protocol DeviceRunning: Sendable {
    func listDevices(projectRoot: URL) throws -> [DeviceRecord]
    func register(deviceID: String, name: String?, projectRoot: URL) throws
    func install(deviceID: String, appPath: String, projectRoot: URL) throws
    func launch(deviceID: String, bundleIdentifier: String, projectRoot: URL) throws
    func logs(deviceID: String, projectRoot: URL) throws -> [String]
    func doctor(projectRoot: URL) throws -> DeviceDoctorReport
}

protocol DeviceCommandRunning: Sendable {
    func run(command: [String], in workingDirectory: URL) throws -> DeviceCommandResult
}

struct DeviceCommandResult: Sendable, Equatable {
    let exitCode: Int32
    let stdout: String
    let stderr: String

    init(exitCode: Int32, stdout: String = "", stderr: String = "") {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }
}

struct ProcessDeviceCommandRunner: DeviceCommandRunning {
    func run(command: [String], in workingDirectory: URL) throws -> DeviceCommandResult {
        let process = Process()
        process.currentDirectoryURL = workingDirectory
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = command

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        return DeviceCommandResult(
            exitCode: process.terminationStatus,
            stdout: String(decoding: stdout.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self),
            stderr: String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        )
    }
}

enum DeviceRunnerError: Error {
    case unsupported(String)
    case execution(String)

    var failureCode: DeviceFailureCode {
        switch self {
        case .unsupported:
            return .unsupported
        case .execution:
            return .execution
        }
    }

    var summary: String {
        switch self {
        case .unsupported(let summary), .execution(let summary):
            return summary
        }
    }
}

public struct ProcessDeviceRunner: DeviceRunning {
    private let commandRunner: any DeviceCommandRunning

    public init() {
        self.commandRunner = ProcessDeviceCommandRunner()
    }

    init(commandRunner: any DeviceCommandRunning) {
        self.commandRunner = commandRunner
    }

    public func listDevices(projectRoot: URL) throws -> [DeviceRecord] {
        try availableSimulators(projectRoot: projectRoot)
    }

    public func register(deviceID: String, name: String?, projectRoot: URL) throws {
        throw DeviceRunnerError.unsupported(
            "device register is not supported by the current runtime; pair and trust devices outside BOS"
        )
    }

    public func install(deviceID: String, appPath: String, projectRoot: URL) throws {
        let simulator = try requireSimulator(deviceID: deviceID, projectRoot: projectRoot)
        try ensureBooted(simulator: simulator, projectRoot: projectRoot)
        let result = try commandRunner.run(
            command: ["xcrun", "simctl", "install", deviceID, appPath],
            in: projectRoot
        )
        guard result.exitCode == 0 else {
            throw DeviceRunnerError.execution("device install failed: \(detail(from: result))")
        }
    }

    public func launch(deviceID: String, bundleIdentifier: String, projectRoot: URL) throws {
        let simulator = try requireSimulator(deviceID: deviceID, projectRoot: projectRoot)
        try ensureBooted(simulator: simulator, projectRoot: projectRoot)
        let result = try commandRunner.run(
            command: ["xcrun", "simctl", "launch", deviceID, bundleIdentifier],
            in: projectRoot
        )
        guard result.exitCode == 0 else {
            throw DeviceRunnerError.execution("device launch failed: \(detail(from: result))")
        }
    }

    public func logs(deviceID: String, projectRoot: URL) throws -> [String] {
        throw DeviceRunnerError.unsupported(
            "device logs is not supported by the current runtime; use Console.app or simulator tooling directly"
        )
    }

    public func doctor(projectRoot: URL) throws -> DeviceDoctorReport {
        var findings: [String] = []
        let simulators: [DeviceRecord]
        do {
            simulators = try availableSimulators(projectRoot: projectRoot)
        } catch let error as DeviceRunnerError {
            findings.append(error.summary)
            return DeviceDoctorReport(healthy: false, findings: findings)
        }

        if simulators.isEmpty {
            findings.append("no available simulators found via simctl")
        }

        let devicectl = try commandRunner.run(
            command: ["xcrun", "--find", "devicectl"],
            in: projectRoot
        )
        if devicectl.exitCode != 0 {
            findings.append("physical device actions remain unsupported because devicectl is unavailable")
        } else {
            findings.append("physical device register/logs remain unsupported in the current runtime")
        }

        return DeviceDoctorReport(
            healthy: !simulators.isEmpty,
            findings: findings
        )
    }
}

public struct DeviceEngine: Sendable {
    private let runner: any DeviceRunning

    public init(runner: any DeviceRunning = ProcessDeviceRunner()) {
        self.runner = runner
    }

    public func run(request: DeviceRequest) throws -> DeviceResult {
        switch request.subcommand {
        case .list:
            return try list(request: request)
        case .register:
            return try register(request: request)
        case .install:
            return try install(request: request)
        case .launch:
            return try launch(request: request)
        case .logs:
            return try logs(request: request)
        case .doctor:
            return try doctor(request: request)
        }
    }
}

private extension DeviceEngine {
    struct ArtifactPayload: Codable {
        let command: String
        let subcommand: String
        let status: String
        let exitCode: Int
        let summary: String
        let devices: [DeviceRecord]
        let targetDevice: String?
        let appPath: String?
        let bundleIdentifier: String?
        let logLines: [String]
        let findings: [String]
        let failureCode: String?
        let artifacts: [String]
    }

    struct Context {
        let root: URL
        let bundle: AdapterArtifactBundle
        let artifacts: [String]
        let subcommand: DeviceSubcommand
    }

    func list(request: DeviceRequest) throws -> DeviceResult {
        let context = try prepareContext(request: request)
        let devices: [DeviceRecord]
        do {
            devices = try runner.listDevices(projectRoot: context.root).sorted { $0.id < $1.id }
        } catch let error as DeviceRunnerError {
            throw try fail(
                context: context,
                summary: error.summary,
                failureCode: error.failureCode
            )
        }
        let summary = "device list returned \(devices.count) device(s)"
        try writeArtifact(context: context, status: "success", exitCode: 0, summary: summary, devices: devices)
        return DeviceResult(artifacts: context.artifacts, summary: summary, devices: devices)
    }

    func register(request: DeviceRequest) throws -> DeviceResult {
        let context = try prepareContext(request: request)
        guard let deviceID = request.deviceID, !deviceID.isEmpty else {
            throw try fail(context: context, summary: "device register requires --device-id", targetDevice: request.deviceID)
        }
        try performRunnerAction(
            context: context,
            targetDevice: deviceID
        ) {
            try runner.register(deviceID: deviceID, name: request.name, projectRoot: context.root)
        }
        let summary = "device register completed for \(deviceID)"
        try writeArtifact(context: context, status: "success", exitCode: 0, summary: summary, targetDevice: deviceID)
        return DeviceResult(artifacts: context.artifacts, summary: summary, targetDevice: deviceID)
    }

    func install(request: DeviceRequest) throws -> DeviceResult {
        let context = try prepareContext(request: request)
        guard let deviceID = request.deviceID, !deviceID.isEmpty else {
            throw try fail(context: context, summary: "device install requires --device-id", targetDevice: request.deviceID)
        }
        guard let appPath = request.appPath, !appPath.isEmpty else {
            throw try fail(context: context, summary: "device install requires --app", targetDevice: deviceID)
        }
        try performRunnerAction(
            context: context,
            targetDevice: deviceID,
            appPath: appPath
        ) {
            try runner.install(deviceID: deviceID, appPath: appPath, projectRoot: context.root)
        }
        let summary = "device install completed for \(deviceID)"
        try writeArtifact(context: context, status: "success", exitCode: 0, summary: summary, targetDevice: deviceID, appPath: appPath)
        return DeviceResult(artifacts: context.artifacts, summary: summary, targetDevice: deviceID, appPath: appPath)
    }

    func launch(request: DeviceRequest) throws -> DeviceResult {
        let context = try prepareContext(request: request)
        guard let deviceID = request.deviceID, !deviceID.isEmpty else {
            throw try fail(context: context, summary: "device launch requires --device-id", targetDevice: request.deviceID)
        }
        guard let bundleIdentifier = request.bundleIdentifier, !bundleIdentifier.isEmpty else {
            throw try fail(context: context, summary: "device launch requires --bundle-id", targetDevice: deviceID)
        }
        try performRunnerAction(
            context: context,
            targetDevice: deviceID,
            bundleIdentifier: bundleIdentifier
        ) {
            try runner.launch(deviceID: deviceID, bundleIdentifier: bundleIdentifier, projectRoot: context.root)
        }
        let summary = "device launch completed for \(deviceID)"
        try writeArtifact(
            context: context,
            status: "success",
            exitCode: 0,
            summary: summary,
            targetDevice: deviceID,
            bundleIdentifier: bundleIdentifier
        )
        return DeviceResult(
            artifacts: context.artifacts,
            summary: summary,
            targetDevice: deviceID,
            bundleIdentifier: bundleIdentifier
        )
    }

    func logs(request: DeviceRequest) throws -> DeviceResult {
        let context = try prepareContext(request: request)
        guard let deviceID = request.deviceID, !deviceID.isEmpty else {
            throw try fail(context: context, summary: "device logs requires --device-id", targetDevice: request.deviceID)
        }
        let logLines: [String]
        do {
            logLines = try runner.logs(deviceID: deviceID, projectRoot: context.root)
        } catch let error as DeviceRunnerError {
            throw try fail(
                context: context,
                summary: error.summary,
                failureCode: error.failureCode,
                targetDevice: deviceID
            )
        }
        let summary = "device logs collected for \(deviceID)"
        try writeArtifact(
            context: context,
            status: "success",
            exitCode: 0,
            summary: summary,
            targetDevice: deviceID,
            logLines: logLines
        )
        return DeviceResult(artifacts: context.artifacts, summary: summary, targetDevice: deviceID, logLines: logLines)
    }

    func doctor(request: DeviceRequest) throws -> DeviceResult {
        let context = try prepareContext(request: request)
        let report: DeviceDoctorReport
        do {
            report = try runner.doctor(projectRoot: context.root)
        } catch let error as DeviceRunnerError {
            throw try fail(
                context: context,
                summary: error.summary,
                failureCode: error.failureCode
            )
        }
        let summary = report.healthy ? "device doctor passed" : "device doctor found issues"
        try writeArtifact(
            context: context,
            status: report.healthy ? "success" : "failed",
            exitCode: report.healthy ? 0 : 1,
            summary: summary,
            findings: report.findings,
            failureCode: report.healthy ? nil : .execution
        )
        if !report.healthy {
            throw DeviceEngineError.failed(
                classification: .execution,
                summary: summary,
                artifacts: context.artifacts,
                devices: [],
                targetDevice: nil,
                appPath: nil,
                bundleIdentifier: nil,
                logLines: [],
                findings: report.findings
            )
        }
        return DeviceResult(artifacts: context.artifacts, summary: summary, findings: report.findings)
    }

    func prepareContext(request: DeviceRequest) throws -> Context {
        let root = request.projectRoot.standardizedFileURL
        let stamp = RuntimeSupport.timestamp()
        let commandName = "device-\(request.subcommand.rawValue)"
        let bundle = try AdapterArtifacts.makeBundle(command: commandName, projectRoot: root, stamp: stamp)
        return Context(root: root, bundle: bundle, artifacts: bundle.artifacts, subcommand: request.subcommand)
    }

    func performRunnerAction(
        context: Context,
        targetDevice: String? = nil,
        appPath: String? = nil,
        bundleIdentifier: String? = nil,
        _ operation: () throws -> Void
    ) throws {
        do {
            try operation()
        } catch let error as DeviceRunnerError {
            throw try fail(
                context: context,
                summary: error.summary,
                failureCode: error.failureCode,
                targetDevice: targetDevice,
                appPath: appPath,
                bundleIdentifier: bundleIdentifier
            )
        }
    }

    func fail(
        context: Context,
        summary: String,
        failureCode: DeviceFailureCode = .validation,
        devices: [DeviceRecord] = [],
        targetDevice: String? = nil,
        appPath: String? = nil,
        bundleIdentifier: String? = nil,
        logLines: [String] = [],
        findings: [String] = []
    ) throws -> DeviceEngineError {
        try writeArtifact(
            context: context,
            status: "failed",
            exitCode: 13,
            summary: summary,
            devices: devices,
            targetDevice: targetDevice,
            appPath: appPath,
            bundleIdentifier: bundleIdentifier,
            logLines: logLines,
            findings: findings,
            failureCode: failureCode
        )
        return DeviceEngineError.failed(
            classification: failureCode,
            summary: summary,
            artifacts: context.artifacts,
            devices: devices,
            targetDevice: targetDevice,
            appPath: appPath,
            bundleIdentifier: bundleIdentifier,
            logLines: logLines,
            findings: findings
        )
    }

    func writeArtifact(
        context: Context,
        status: String,
        exitCode: Int,
        summary: String,
        devices: [DeviceRecord] = [],
        targetDevice: String? = nil,
        appPath: String? = nil,
        bundleIdentifier: String? = nil,
        logLines: [String] = [],
        findings: [String] = [],
        failureCode: DeviceFailureCode? = nil
    ) throws {
        _ = try AdapterArtifacts.write(
            bundle: context.bundle,
            envelope: AdapterRunEnvelope(
                command: "device",
                status: status,
                exitCode: exitCode,
                summary: summary,
                payload: ArtifactPayload(
                    command: "device",
                    subcommand: context.subcommand.rawValue,
                    status: status,
                    exitCode: exitCode,
                    summary: summary,
                    devices: devices,
                    targetDevice: targetDevice,
                    appPath: appPath,
                    bundleIdentifier: bundleIdentifier,
                    logLines: logLines,
                    findings: findings,
                    failureCode: failureCode?.rawValue,
                    artifacts: context.artifacts
                )
            ),
            stdout: renderLog(
                subcommand: context.subcommand,
                summary: summary,
                targetDevice: targetDevice,
                logLines: logLines,
                findings: findings
            ),
            stderr: ""
        )
    }

    func renderLog(
        subcommand: DeviceSubcommand,
        summary: String,
        targetDevice: String?,
        logLines: [String],
        findings: [String]
    ) -> String {
        var lines = [
            "# bos device \(subcommand.rawValue)",
            "summary=\(summary)"
        ]
        if let targetDevice {
            lines.append("targetDevice=\(targetDevice)")
        }
        if !logLines.isEmpty {
            lines.append("logLines=\(logLines.joined(separator: "|"))")
        }
        if !findings.isEmpty {
            lines.append("findings=\(findings.joined(separator: "|"))")
        }
        return lines.joined(separator: "\n") + "\n"
    }
}

private extension ProcessDeviceRunner {
    struct SimctlDevicesResponse: Decodable {
        let devices: [String: [SimctlDevice]]
    }

    struct SimctlDevice: Decodable {
        let udid: String
        let name: String
        let state: String
        let isAvailable: Bool?
    }

    func availableSimulators(projectRoot: URL) throws -> [DeviceRecord] {
        let result = try commandRunner.run(
            command: ["xcrun", "simctl", "list", "devices", "available", "-j"],
            in: projectRoot
        )
        guard result.exitCode == 0 else {
            throw DeviceRunnerError.execution("simctl device inventory failed: \(detail(from: result))")
        }

        let decoded: SimctlDevicesResponse
        do {
            decoded = try JSONDecoder().decode(SimctlDevicesResponse.self, from: Data(result.stdout.utf8))
        } catch {
            throw DeviceRunnerError.execution("simctl device inventory returned invalid JSON")
        }

        return try decoded.devices
            .flatMap { runtime, devices in
                devices.map { (runtime, $0) }
            }
            .filter { _, device in device.isAvailable ?? true }
            .map { runtime, device in
                try DeviceRecord(
                    id: device.udid,
                    name: device.name,
                    kind: "simulator",
                    platform: "iOS",
                    state: device.state.lowercased(),
                    runtime: runtime,
                    isAvailable: device.isAvailable ?? true
                )
            }
            .sorted { $0.id < $1.id }
    }

    func requireSimulator(deviceID: String, projectRoot: URL) throws -> DeviceRecord {
        let simulators = try availableSimulators(projectRoot: projectRoot)
        guard let device = simulators.first(where: { $0.id == deviceID }) else {
            throw DeviceRunnerError.unsupported(
                "device `\(deviceID)` is not an available simulator in the current runtime"
            )
        }
        return device
    }

    func ensureBooted(simulator: DeviceRecord, projectRoot: URL) throws {
        if simulator.state != "booted" {
            let boot = try commandRunner.run(
                command: ["xcrun", "simctl", "boot", simulator.id],
                in: projectRoot
            )
            guard boot.exitCode == 0 else {
                throw DeviceRunnerError.execution(
                    "simulator boot failed for `\(simulator.name)`: \(detail(from: boot))"
                )
            }
        }

        let bootstatus = try commandRunner.run(
            command: ["xcrun", "simctl", "bootstatus", simulator.id, "-b"],
            in: projectRoot
        )
        guard bootstatus.exitCode == 0 else {
            throw DeviceRunnerError.execution(
                "simulator bootstatus failed for `\(simulator.name)`: \(detail(from: bootstatus))"
            )
        }
    }

    func detail(from result: DeviceCommandResult) -> String {
        let stderr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        if !stderr.isEmpty {
            return stderr
        }
        let stdout = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return stdout.isEmpty ? "exit \(result.exitCode)" : stdout
    }
}
