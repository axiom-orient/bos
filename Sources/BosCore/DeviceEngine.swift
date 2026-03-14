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
    func listDevices() throws -> [DeviceRecord]
    func register(deviceID: String, name: String?) throws
    func install(deviceID: String, appPath: String) throws
    func launch(deviceID: String, bundleIdentifier: String) throws
    func logs(deviceID: String) throws -> [String]
    func doctor() throws -> DeviceDoctorReport
}

public struct ProcessDeviceRunner: DeviceRunning {
    public init() {}

    public func listDevices() throws -> [DeviceRecord] { [] }
    public func register(deviceID: String, name: String?) throws {}
    public func install(deviceID: String, appPath: String) throws {}
    public func launch(deviceID: String, bundleIdentifier: String) throws {}
    public func logs(deviceID: String) throws -> [String] { [] }
    public func doctor() throws -> DeviceDoctorReport {
        DeviceDoctorReport(healthy: true, findings: [])
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
        let devices = try runner.listDevices().sorted { $0.id < $1.id }
        let summary = "device list returned \(devices.count) device(s)"
        try writeArtifact(context: context, status: "success", exitCode: 0, summary: summary, devices: devices)
        return DeviceResult(artifacts: context.artifacts, summary: summary, devices: devices)
    }

    func register(request: DeviceRequest) throws -> DeviceResult {
        let context = try prepareContext(request: request)
        guard let deviceID = request.deviceID, !deviceID.isEmpty else {
            throw try fail(context: context, summary: "device register requires --device-id", targetDevice: request.deviceID)
        }
        try runner.register(deviceID: deviceID, name: request.name)
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
        try runner.install(deviceID: deviceID, appPath: appPath)
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
        try runner.launch(deviceID: deviceID, bundleIdentifier: bundleIdentifier)
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
        let logLines = try runner.logs(deviceID: deviceID)
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
        let report = try runner.doctor()
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

    func fail(
        context: Context,
        summary: String,
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
            failureCode: .validation
        )
        return DeviceEngineError.failed(
            classification: .validation,
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
