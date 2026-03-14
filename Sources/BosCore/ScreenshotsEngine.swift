import Foundation

public enum ScreenshotSubcommand: String, Codable, Sendable, CaseIterable {
    case plan
    case capture
    case compose
    case validate
}

public enum ScreenshotFailureCode: String, Codable, Sendable, Equatable {
    case validation = "E-SCREENSHOTS-VALIDATION"
    case capture = "E-SCREENSHOTS-CAPTURE"
    case compose = "E-SCREENSHOTS-COMPOSE"
    case simulator = "E-SCREENSHOTS-SIMULATOR"
    case unsupported = "E-SCREENSHOTS-UNSUPPORTED"
}

public struct ScreenshotRequest: Sendable {
    public let projectRoot: URL
    public let planPath: URL
    public let plan: ScreenshotPlan
    public let subcommand: ScreenshotSubcommand

    public init(
        projectRoot: URL,
        planPath: URL,
        plan: ScreenshotPlan,
        subcommand: ScreenshotSubcommand
    ) {
        self.projectRoot = projectRoot
        self.planPath = planPath
        self.plan = plan
        self.subcommand = subcommand
    }
}

public struct ScreenshotPlanSummary: Codable, Sendable, Equatable {
    public let localeCount: Int
    public let deviceCount: Int
    public let shotCount: Int

    public init(localeCount: Int, deviceCount: Int, shotCount: Int) {
        self.localeCount = localeCount
        self.deviceCount = deviceCount
        self.shotCount = shotCount
    }
}

public struct ScreenshotsResult: Sendable {
    public let artifacts: [String]
    public let summary: String
    public let planPath: String
    public let defaultLocale: String
    public let summaryReport: ScreenshotPlanSummary?
    public let capturedShots: [String]
    public let failedShots: [String]
    public let outputDirectory: String?
    public let composedFiles: [String]
    public let missingOutputs: [String]
    public let unexpectedFiles: [String]
    public let valid: Bool?

    public init(
        artifacts: [String],
        summary: String,
        planPath: String,
        defaultLocale: String,
        summaryReport: ScreenshotPlanSummary? = nil,
        capturedShots: [String] = [],
        failedShots: [String] = [],
        outputDirectory: String? = nil,
        composedFiles: [String] = [],
        missingOutputs: [String] = [],
        unexpectedFiles: [String] = [],
        valid: Bool? = nil
    ) {
        self.artifacts = artifacts
        self.summary = summary
        self.planPath = planPath
        self.defaultLocale = defaultLocale
        self.summaryReport = summaryReport
        self.capturedShots = capturedShots
        self.failedShots = failedShots
        self.outputDirectory = outputDirectory
        self.composedFiles = composedFiles
        self.missingOutputs = missingOutputs
        self.unexpectedFiles = unexpectedFiles
        self.valid = valid
    }
}

public enum ScreenshotsEngineError: Error {
    case failed(
        classification: ScreenshotFailureCode,
        summary: String,
        artifacts: [String],
        outputDirectory: String?,
        summaryReport: ScreenshotPlanSummary?,
        capturedShots: [String],
        failedShots: [String],
        composedFiles: [String],
        missingOutputs: [String],
        unexpectedFiles: [String],
        valid: Bool?
    )
}

public struct ScreenshotsEngine: Sendable {
    private let captureAdapter: any ScreenshotCaptureAdapting

    public init() {
        self.captureAdapter = SimulatorScreenshotAdapter()
    }

    init(captureAdapter: any ScreenshotCaptureAdapting) {
        self.captureAdapter = captureAdapter
    }

    public func run(request: ScreenshotRequest) throws -> ScreenshotsResult {
        switch request.subcommand {
        case .plan:
            return try plan(request: request)
        case .capture:
            return try capture(request: request)
        case .compose:
            return try compose(request: request)
        case .validate:
            return try validate(request: request)
        }
    }
}

public struct ScreenshotCaptureAsset: Sendable {
    public let shotID: String
    public let screenID: String
    public let locale: String
    public let outputName: String
    public let device: ScreenshotPlan.DevicePlan

    public init(
        shotID: String,
        screenID: String,
        locale: String,
        outputName: String,
        device: ScreenshotPlan.DevicePlan
    ) {
        self.shotID = shotID
        self.screenID = screenID
        self.locale = locale
        self.outputName = outputName
        self.device = device
    }
}

public struct ScreenshotCaptureEvidence: Codable, Sendable, Equatable {
    public let adapter: String
    public let runtimeDeviceID: String?
    public let command: [String]

    public init(adapter: String, runtimeDeviceID: String?, command: [String]) {
        self.adapter = adapter
        self.runtimeDeviceID = runtimeDeviceID
        self.command = command
    }
}

public protocol ScreenshotCaptureAdapting: Sendable {
    func capture(
        asset: ScreenshotCaptureAsset,
        outputURL: URL,
        projectRoot: URL
    ) throws -> ScreenshotCaptureEvidence
}

protocol ScreenshotCaptureRunning: Sendable {
    func run(command: [String], in workingDirectory: URL) throws -> ScreenshotCaptureCommandResult
}

struct ScreenshotCaptureCommandResult: Sendable, Equatable {
    let exitCode: Int32
    let stdout: String
    let stderr: String

    init(exitCode: Int32, stdout: String = "", stderr: String = "") {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }
}

struct ProcessScreenshotCaptureRunner: ScreenshotCaptureRunning {
    func run(command: [String], in workingDirectory: URL) throws -> ScreenshotCaptureCommandResult {
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

        return ScreenshotCaptureCommandResult(
            exitCode: process.terminationStatus,
            stdout: String(decoding: stdout.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self),
            stderr: String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        )
    }
}

enum ScreenshotCaptureAdapterError: Error {
    case unsupportedPlatform(String)
    case simulatorListFailed(String)
    case simulatorNotFound(String)
    case simulatorBootFailed(String)
    case screenshotFailed(String)
    case missingOutput(String)

    var failureCode: ScreenshotFailureCode {
        switch self {
        case .unsupportedPlatform:
            return .unsupported
        case .simulatorListFailed, .simulatorNotFound, .simulatorBootFailed:
            return .simulator
        case .screenshotFailed, .missingOutput:
            return .capture
        }
    }

    var summary: String {
        switch self {
        case .unsupportedPlatform(let detail),
             .simulatorListFailed(let detail),
             .simulatorNotFound(let detail),
             .simulatorBootFailed(let detail),
             .screenshotFailed(let detail),
             .missingOutput(let detail):
            return detail
        }
    }
}

public struct SimulatorScreenshotAdapter: ScreenshotCaptureAdapting, Sendable {
    private let runner: any ScreenshotCaptureRunning

    init(runner: any ScreenshotCaptureRunning = ProcessScreenshotCaptureRunner()) {
        self.runner = runner
    }

    public func capture(
        asset: ScreenshotCaptureAsset,
        outputURL: URL,
        projectRoot: URL
    ) throws -> ScreenshotCaptureEvidence {
        guard asset.device.platform == "simulator" else {
            throw ScreenshotCaptureAdapterError.unsupportedPlatform(
                "screenshots capture does not support platform `\(asset.device.platform)` for device `\(asset.device.id)`"
            )
        }

        let device = try resolveSimulator(named: asset.device.name, projectRoot: projectRoot)
        if device.state != "Booted" {
            try runChecked(
                command: ["xcrun", "simctl", "boot", device.udid],
                projectRoot: projectRoot,
                error: .simulatorBootFailed("simulator boot failed for `\(asset.device.name)`")
            )
        }
        try runChecked(
            command: ["xcrun", "simctl", "bootstatus", device.udid, "-b"],
            projectRoot: projectRoot,
            error: .simulatorBootFailed("simulator bootstatus failed for `\(asset.device.name)`")
        )

        let screenshotCommand = [
            "xcrun", "simctl", "io", device.udid, "screenshot",
            outputURL.path(percentEncoded: false)
        ]
        try runChecked(
            command: screenshotCommand,
            projectRoot: projectRoot,
            error: .screenshotFailed("simulator screenshot command failed for `\(asset.device.name)`")
        )

        guard FileManager.default.fileExists(atPath: outputURL.path(percentEncoded: false)) else {
            throw ScreenshotCaptureAdapterError.missingOutput(
                "simulator screenshot command did not produce \(outputURL.path(percentEncoded: false))"
            )
        }

        return ScreenshotCaptureEvidence(
            adapter: "simctl",
            runtimeDeviceID: device.udid,
            command: screenshotCommand
        )
    }
}

private extension ScreenshotsEngine {
    struct ArtifactPayload: Codable {
        let command: String
        let subcommand: String
        let status: String
        let exitCode: Int
        let summary: String
        let planPath: String
        let defaultLocale: String
        let summaryReport: ScreenshotPlanSummary?
        let capturedShots: [String]
        let failedShots: [String]
        let outputDirectory: String?
        let composedFiles: [String]
        let missingOutputs: [String]
        let unexpectedFiles: [String]
        let valid: Bool?
        let failureCode: String?
        let artifacts: [String]
    }

    struct Context {
        let root: URL
        let planPath: URL
        let plan: ScreenshotPlan
        let summary: ScreenshotPlanSummary
        let rawRoot: URL
        let exportRoot: URL
        let bundle: AdapterArtifactBundle
        let artifacts: [String]
        let subcommand: ScreenshotSubcommand
    }

    struct ExpectedAsset: Sendable {
        let shotID: String
        let screenID: String
        let locale: String
        let device: ScreenshotPlan.DevicePlan
        let outputName: String

        var fileName: String { "\(outputName).png" }
        var identifier: String { "\(shotID):\(locale):\(deviceID)" }
        var deviceID: String { device.id }
    }

    struct AssetManifest: Codable, Sendable {
        struct Entry: Codable, Sendable, Equatable {
            let shotID: String
            let screenID: String
            let locale: String
            let deviceID: String
            let deviceName: String
            let platform: String
            let path: String
            let captureBackend: String
            let runtimeDeviceID: String?
            let command: [String]
        }

        let schemaVersion: Int
        let generatedAt: String
        let entries: [Entry]
    }

    func plan(request: ScreenshotRequest) throws -> ScreenshotsResult {
        let context = try prepareContext(request: request)
        let summary = "screenshots plan ready (\(context.summary.shotCount) shots, \(context.summary.localeCount) locales, \(context.summary.deviceCount) devices)"
        try writeArtifact(
            context: context,
            status: "success",
            exitCode: 0,
            summary: summary,
            outputDirectory: nil,
            capturedShots: [],
            failedShots: [],
            composedFiles: [],
            missingOutputs: [],
            unexpectedFiles: [],
            valid: nil,
            failureCode: nil
        )
        return ScreenshotsResult(
            artifacts: context.artifacts,
            summary: summary,
            planPath: context.planPath.path(percentEncoded: false),
            defaultLocale: context.plan.defaultLocale,
            summaryReport: context.summary
        )
    }

    func capture(request: ScreenshotRequest) throws -> ScreenshotsResult {
        let context = try prepareContext(request: request)
        let assets = expectedAssets(for: context.plan)
        let manifestPath = context.rawRoot.appending(path: "manifest.json")
        var entries: [AssetManifest.Entry] = []
        var failedShots: [String] = []
        var failureSummaries: [String] = []
        var failureCodes: [ScreenshotFailureCode] = []

        for asset in assets {
            let path = context.rawRoot
                .appending(path: asset.locale)
                .appending(path: asset.deviceID)
                .appending(path: asset.fileName)
            do {
                let evidence = try captureAdapter.capture(
                    asset: ScreenshotCaptureAsset(
                        shotID: asset.shotID,
                        screenID: asset.screenID,
                        locale: asset.locale,
                        outputName: asset.outputName,
                        device: asset.device
                    ),
                    outputURL: path,
                    projectRoot: context.root
                )
                entries.append(
                    AssetManifest.Entry(
                        shotID: asset.shotID,
                        screenID: asset.screenID,
                        locale: asset.locale,
                        deviceID: asset.deviceID,
                        deviceName: asset.device.name,
                        platform: asset.device.platform,
                        path: path.path(percentEncoded: false),
                        captureBackend: evidence.adapter,
                        runtimeDeviceID: evidence.runtimeDeviceID,
                        command: evidence.command
                    )
                )
            } catch let error as ScreenshotCaptureAdapterError {
                failedShots.append(asset.identifier)
                failureSummaries.append(error.summary)
                failureCodes.append(error.failureCode)
            }
        }
        try writeJSON(
            AssetManifest(
                schemaVersion: 1,
                generatedAt: RuntimeSupport.isoNow(),
                entries: entries.sorted { $0.path < $1.path }
            ),
            to: manifestPath
        )

        let capturedShots = entries.map(\.path).sorted()
        if !failedShots.isEmpty {
            throw try fail(
                context: context,
                summary: failureSummaries.first ?? "screenshots capture failed",
                failureCode: failureCode(for: failureCodes),
                outputDirectory: context.rawRoot.path(percentEncoded: false),
                capturedShots: capturedShots,
                failedShots: failedShots.sorted(),
                composedFiles: [],
                missingOutputs: [],
                unexpectedFiles: [],
                valid: nil,
                extraArtifacts: [manifestPath]
            )
        }

        let summary = "screenshots capture completed (\(capturedShots.count) files)"
        try writeArtifact(
            context: context,
            status: "success",
            exitCode: 0,
            summary: summary,
            outputDirectory: context.rawRoot.path(percentEncoded: false),
            capturedShots: capturedShots,
            failedShots: [],
            composedFiles: [],
            missingOutputs: [],
            unexpectedFiles: [],
            valid: nil,
            failureCode: nil,
            extraArtifacts: [manifestPath]
        )
        return ScreenshotsResult(
            artifacts: context.artifacts,
            summary: summary,
            planPath: context.planPath.path(percentEncoded: false),
            defaultLocale: context.plan.defaultLocale,
            summaryReport: context.summary,
            capturedShots: capturedShots,
            failedShots: [],
            outputDirectory: context.rawRoot.path(percentEncoded: false)
        )
    }

    func compose(request: ScreenshotRequest) throws -> ScreenshotsResult {
        let context = try prepareContext(request: request)
        let assets = expectedAssets(for: context.plan)
        let manifestPath = context.exportRoot.appending(path: "manifest.json")

        var entries: [AssetManifest.Entry] = []
        var composedFiles: [String] = []
        var missingOutputs: [String] = []

        for asset in assets {
            let rawPath = context.rawRoot
                .appending(path: asset.locale)
                .appending(path: asset.deviceID)
                .appending(path: asset.fileName)
            let exportPath = context.exportRoot
                .appending(path: asset.locale)
                .appending(path: asset.deviceID)
                .appending(path: asset.fileName)
            guard FileManager.default.fileExists(atPath: rawPath.path(percentEncoded: false)) else {
                missingOutputs.append(exportPath.path(percentEncoded: false))
                continue
            }
            let data = try Data(contentsOf: rawPath)
            try RuntimeSupport.writeFile(to: exportPath, data: data)
            let exportPathString = exportPath.path(percentEncoded: false)
            composedFiles.append(exportPathString)
            entries.append(
                AssetManifest.Entry(
                    shotID: asset.shotID,
                    screenID: asset.screenID,
                    locale: asset.locale,
                    deviceID: asset.deviceID,
                    deviceName: asset.device.name,
                    platform: asset.device.platform,
                    path: exportPathString
                    ,
                    captureBackend: "compose-copy",
                    runtimeDeviceID: nil,
                    command: []
                )
            )
        }

        try writeJSON(
            AssetManifest(schemaVersion: 1, generatedAt: RuntimeSupport.isoNow(), entries: entries.sorted { $0.path < $1.path }),
            to: manifestPath
        )

        if !missingOutputs.isEmpty {
            throw try fail(
                context: context,
                summary: "screenshots compose failed: missing raw captures",
                failureCode: .compose,
                outputDirectory: context.exportRoot.path(percentEncoded: false),
                capturedShots: [],
                failedShots: [],
                composedFiles: composedFiles.sorted(),
                missingOutputs: missingOutputs.sorted(),
                unexpectedFiles: [],
                valid: nil,
                extraArtifacts: [manifestPath]
            )
        }

        let summary = "screenshots compose completed (\(composedFiles.count) files)"
        try writeArtifact(
            context: context,
            status: "success",
            exitCode: 0,
            summary: summary,
            outputDirectory: context.exportRoot.path(percentEncoded: false),
            capturedShots: [],
            failedShots: [],
            composedFiles: composedFiles.sorted(),
            missingOutputs: [],
            unexpectedFiles: [],
            valid: nil,
            failureCode: nil,
            extraArtifacts: [manifestPath]
        )
        return ScreenshotsResult(
            artifacts: context.artifacts,
            summary: summary,
            planPath: context.planPath.path(percentEncoded: false),
            defaultLocale: context.plan.defaultLocale,
            summaryReport: context.summary,
            outputDirectory: context.exportRoot.path(percentEncoded: false),
            composedFiles: composedFiles.sorted()
        )
    }

    func validate(request: ScreenshotRequest) throws -> ScreenshotsResult {
        let context = try prepareContext(request: request)
        let assets = expectedAssets(for: context.plan)
        let expectedPaths = Set(
            assets.map { asset in
                context.exportRoot
                    .appending(path: asset.locale)
                    .appending(path: asset.deviceID)
                    .appending(path: asset.fileName)
                    .standardizedFileURL
                    .path(percentEncoded: false)
            }
        )
        let missingOutputs = expectedPaths
            .filter { !FileManager.default.fileExists(atPath: $0) }
            .sorted()
        let unexpectedFiles = try collectUnexpectedFiles(in: context.exportRoot, expectedPaths: expectedPaths)
        let valid = missingOutputs.isEmpty && unexpectedFiles.isEmpty
        let summary = valid
            ? "screenshots validate passed"
            : "screenshots validate failed"
        try writeArtifact(
            context: context,
            status: valid ? "success" : "failed",
            exitCode: valid ? 0 : 1,
            summary: summary,
            outputDirectory: context.exportRoot.path(percentEncoded: false),
            capturedShots: [],
            failedShots: [],
            composedFiles: [],
            missingOutputs: missingOutputs,
            unexpectedFiles: unexpectedFiles,
            valid: valid,
            failureCode: valid ? nil : .validation
        )
        if !valid {
            throw ScreenshotsEngineError.failed(
                classification: .validation,
                summary: summary,
                artifacts: context.artifacts,
                outputDirectory: context.exportRoot.path(percentEncoded: false),
                summaryReport: context.summary,
                capturedShots: [],
                failedShots: [],
                composedFiles: [],
                missingOutputs: missingOutputs,
                unexpectedFiles: unexpectedFiles,
                valid: false
            )
        }

        return ScreenshotsResult(
            artifacts: context.artifacts,
            summary: summary,
            planPath: context.planPath.path(percentEncoded: false),
            defaultLocale: context.plan.defaultLocale,
            summaryReport: context.summary,
            outputDirectory: context.exportRoot.path(percentEncoded: false),
            missingOutputs: [],
            unexpectedFiles: [],
            valid: true
        )
    }

    func prepareContext(request: ScreenshotRequest) throws -> Context {
        let root = request.projectRoot.standardizedFileURL
        let summary = ScreenshotPlanSummary(
            localeCount: request.plan.locales.count,
            deviceCount: request.plan.devices.count,
            shotCount: request.plan.shots.count
        )
        let stamp = RuntimeSupport.timestamp()
        let commandName = "screenshots-\(request.subcommand.rawValue)"
        let bundle = try AdapterArtifacts.makeBundle(command: commandName, projectRoot: root, stamp: stamp)
        return Context(
            root: root,
            planPath: request.planPath.standardizedFileURL,
            plan: request.plan,
            summary: summary,
            rawRoot: root.appending(path: "screenshots/raw"),
            exportRoot: root.appending(path: request.plan.export.rootDirectory),
            bundle: bundle,
            artifacts: bundle.artifacts,
            subcommand: request.subcommand
        )
    }

    func expectedAssets(for plan: ScreenshotPlan) -> [ExpectedAsset] {
        let deviceMap = Dictionary(uniqueKeysWithValues: plan.devices.map { ($0.id, $0) })
        var assets: [ExpectedAsset] = []
        for shot in plan.shots {
            for locale in shot.locales {
                for deviceID in shot.devices {
                    guard let device = deviceMap[deviceID] else { continue }
                    assets.append(
                        ExpectedAsset(
                            shotID: shot.id,
                            screenID: shot.screenID,
                            locale: locale,
                            device: device,
                            outputName: shot.outputName
                        )
                    )
                }
            }
        }
        return assets.sorted { lhs, rhs in
            (lhs.locale, lhs.deviceID, lhs.outputName, lhs.shotID) < (rhs.locale, rhs.deviceID, rhs.outputName, rhs.shotID)
        }
    }

    func failureCode(for failureCodes: [ScreenshotFailureCode]) -> ScreenshotFailureCode {
        if failureCodes.contains(.unsupported) {
            return .unsupported
        }
        if failureCodes.contains(.simulator) {
            return .simulator
        }
        return failureCodes.first ?? .capture
    }

    func collectUnexpectedFiles(in root: URL, expectedPaths: Set<String>) throws -> [String] {
        guard FileManager.default.fileExists(atPath: root.path(percentEncoded: false)) else {
            return []
        }

        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        var files: [String] = []
        while let url = enumerator?.nextObject() as? URL {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else { continue }
            let path = url.standardizedFileURL.path(percentEncoded: false)
            if url.lastPathComponent == "manifest.json" {
                continue
            }
            if !expectedPaths.contains(path) {
                files.append(path)
            }
        }
        return files.sorted()
    }

    func fail(
        context: Context,
        summary: String,
        failureCode: ScreenshotFailureCode,
        outputDirectory: String?,
        capturedShots: [String],
        failedShots: [String],
        composedFiles: [String],
        missingOutputs: [String],
        unexpectedFiles: [String],
        valid: Bool?,
        extraArtifacts: [URL] = []
    ) throws -> ScreenshotsEngineError {
        try writeArtifact(
            context: context,
            status: "failed",
            exitCode: 12,
            summary: summary,
            outputDirectory: outputDirectory,
            capturedShots: capturedShots,
            failedShots: failedShots,
            composedFiles: composedFiles,
            missingOutputs: missingOutputs,
            unexpectedFiles: unexpectedFiles,
            valid: valid,
            failureCode: failureCode,
            extraArtifacts: extraArtifacts
        )
        return ScreenshotsEngineError.failed(
            classification: failureCode,
            summary: summary,
            artifacts: context.artifacts,
            outputDirectory: outputDirectory,
            summaryReport: context.summary,
            capturedShots: capturedShots,
            failedShots: failedShots,
            composedFiles: composedFiles,
            missingOutputs: missingOutputs,
            unexpectedFiles: unexpectedFiles,
            valid: valid
        )
    }

    func writeArtifact(
        context: Context,
        status: String,
        exitCode: Int,
        summary: String,
        outputDirectory: String?,
        capturedShots: [String],
        failedShots: [String],
        composedFiles: [String],
        missingOutputs: [String],
        unexpectedFiles: [String],
        valid: Bool?,
        failureCode: ScreenshotFailureCode?,
        extraArtifacts: [URL] = []
    ) throws {
        _ = try AdapterArtifacts.write(
            bundle: context.bundle,
            envelope: AdapterRunEnvelope(
                command: "screenshots",
                status: status,
                exitCode: exitCode,
                summary: summary,
                payload: ArtifactPayload(
                    command: "screenshots",
                    subcommand: context.subcommand.rawValue,
                    status: status,
                    exitCode: exitCode,
                    summary: summary,
                    planPath: context.planPath.path(percentEncoded: false),
                    defaultLocale: context.plan.defaultLocale,
                    summaryReport: context.summary,
                    capturedShots: capturedShots,
                    failedShots: failedShots,
                    outputDirectory: outputDirectory,
                    composedFiles: composedFiles,
                    missingOutputs: missingOutputs,
                    unexpectedFiles: unexpectedFiles,
                    valid: valid,
                    failureCode: failureCode?.rawValue,
                    artifacts: context.artifacts
                )
            ),
            stdout: renderLog(
                subcommand: context.subcommand,
                summary: summary,
                outputDirectory: outputDirectory,
                capturedShots: capturedShots,
                composedFiles: composedFiles,
                missingOutputs: missingOutputs,
                unexpectedFiles: unexpectedFiles,
                valid: valid
            ),
            stderr: "",
            extraArtifacts: extraArtifacts
        )
    }

    func renderLog(
        subcommand: ScreenshotSubcommand,
        summary: String,
        outputDirectory: String?,
        capturedShots: [String],
        composedFiles: [String],
        missingOutputs: [String],
        unexpectedFiles: [String],
        valid: Bool?
    ) -> String {
        var lines = [
            "# bos screenshots \(subcommand.rawValue)",
            "summary=\(summary)"
        ]
        if let outputDirectory {
            lines.append("outputDirectory=\(outputDirectory)")
        }
        if !capturedShots.isEmpty {
            lines.append("capturedShots=\(capturedShots.joined(separator: ","))")
        }
        if !composedFiles.isEmpty {
            lines.append("composedFiles=\(composedFiles.joined(separator: ","))")
        }
        if !missingOutputs.isEmpty {
            lines.append("missingOutputs=\(missingOutputs.joined(separator: ","))")
        }
        if !unexpectedFiles.isEmpty {
            lines.append("unexpectedFiles=\(unexpectedFiles.joined(separator: ","))")
        }
        if let valid {
            lines.append("valid=\(valid)")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    func writeJSON<T: Encodable>(_ value: T, to path: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        try RuntimeSupport.writeFile(to: path, data: data)
    }

}

private extension SimulatorScreenshotAdapter {
    struct SimctlDevicesResponse: Decodable {
        let devices: [String: [SimctlDevice]]
    }

    struct SimctlDevice: Decodable {
        let udid: String
        let name: String
        let state: String
        let isAvailable: Bool?
    }

    func resolveSimulator(named name: String, projectRoot: URL) throws -> SimctlDevice {
        let command = ["xcrun", "simctl", "list", "devices", "available", "-j"]
        let result = try runner.run(command: command, in: projectRoot)
        guard result.exitCode == 0 else {
            throw ScreenshotCaptureAdapterError.simulatorListFailed(
                "simulator inventory query failed for `\(name)`: \(errorDetail(from: result))"
            )
        }

        let data = Data(result.stdout.utf8)
        let decoded: SimctlDevicesResponse
        do {
            decoded = try JSONDecoder().decode(SimctlDevicesResponse.self, from: data)
        } catch {
            throw ScreenshotCaptureAdapterError.simulatorListFailed(
                "simulator inventory query returned invalid JSON for `\(name)`"
            )
        }

        let matches = decoded.devices.values
            .flatMap { $0 }
            .filter { ($0.isAvailable ?? true) && $0.name == name }
            .sorted { lhs, rhs in
                if lhs.state == rhs.state {
                    return lhs.udid < rhs.udid
                }
                return lhs.state == "Booted"
            }

        guard let match = matches.first else {
            throw ScreenshotCaptureAdapterError.simulatorNotFound(
                "no available simulator named `\(name)`"
            )
        }
        return match
    }

    func runChecked(
        command: [String],
        projectRoot: URL,
        error: ScreenshotCaptureAdapterError
    ) throws {
        let result = try runner.run(command: command, in: projectRoot)
        guard result.exitCode == 0 else {
            let message = "\(error.summary): \(errorDetail(from: result))"
            switch error {
            case .unsupportedPlatform:
                throw ScreenshotCaptureAdapterError.unsupportedPlatform(message)
            case .simulatorListFailed:
                throw ScreenshotCaptureAdapterError.simulatorListFailed(message)
            case .simulatorNotFound:
                throw ScreenshotCaptureAdapterError.simulatorNotFound(message)
            case .simulatorBootFailed:
                throw ScreenshotCaptureAdapterError.simulatorBootFailed(message)
            case .screenshotFailed:
                throw ScreenshotCaptureAdapterError.screenshotFailed(message)
            case .missingOutput:
                throw ScreenshotCaptureAdapterError.missingOutput(message)
            }
        }
    }

    func errorDetail(from result: ScreenshotCaptureCommandResult) -> String {
        let detail = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        if !detail.isEmpty {
            return detail
        }
        let stdout = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return stdout.isEmpty ? "exit \(result.exitCode)" : stdout
    }
}
