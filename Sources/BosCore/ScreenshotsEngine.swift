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
    public init() {}

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

    struct ExpectedAsset: Sendable, Equatable {
        let shotID: String
        let screenID: String
        let locale: String
        let deviceID: String
        let outputName: String

        var fileName: String { "\(outputName).png" }
        var identifier: String { "\(shotID):\(locale):\(deviceID)" }
    }

    struct AssetManifest: Codable, Sendable {
        struct Entry: Codable, Sendable, Equatable {
            let shotID: String
            let screenID: String
            let locale: String
            let deviceID: String
            let path: String
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
        let entries = try assets.map { asset -> AssetManifest.Entry in
            let path = context.rawRoot
                .appending(path: asset.locale)
                .appending(path: asset.deviceID)
                .appending(path: asset.fileName)
            try RuntimeSupport.writeFile(to: path, data: placeholderPNGData())
            return AssetManifest.Entry(
                shotID: asset.shotID,
                screenID: asset.screenID,
                locale: asset.locale,
                deviceID: asset.deviceID,
                path: path.path(percentEncoded: false)
            )
        }
        try writeJSON(
            AssetManifest(schemaVersion: 1, generatedAt: RuntimeSupport.isoNow(), entries: entries),
            to: manifestPath
        )

        let capturedShots = entries.map(\.path).sorted()
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
                    path: exportPathString
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
        var assets: [ExpectedAsset] = []
        for shot in plan.shots {
            for locale in shot.locales {
                for deviceID in shot.devices {
                    assets.append(
                        ExpectedAsset(
                            shotID: shot.id,
                            screenID: shot.screenID,
                            locale: locale,
                            deviceID: deviceID,
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

    func placeholderPNGData() throws -> Data {
        guard let data = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+XG4sAAAAASUVORK5CYII=") else {
            throw NSError(domain: "ScreenshotsEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: "failed to decode placeholder PNG"])
        }
        return data
    }
}
