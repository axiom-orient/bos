import Foundation

public enum MetadataSubcommand: String, Codable, Sendable, CaseIterable {
    case pull
    case diff
    case push
    case validate
}

public enum MetadataFailureCode: String, Codable, Sendable, Equatable {
    case validation = "E-METADATA-VALIDATION"
    case fastlane = "E-METADATA-FASTLANE"
}

public struct MetadataRequest: Sendable {
    public let projectRoot: URL
    public let profile: Profile
    public let environment: [String: String]
    public let subcommand: MetadataSubcommand

    public init(
        projectRoot: URL,
        profile: Profile,
        environment: [String: String],
        subcommand: MetadataSubcommand
    ) {
        self.projectRoot = projectRoot
        self.profile = profile
        self.environment = environment
        self.subcommand = subcommand
    }
}

public struct MetadataResult: Sendable {
    public let artifacts: [String]
    public let summary: String
    public let directory: String
    public let defaultLocale: String
    public let locales: [String]
    public let diff: MetadataDiffReport?
    public let validation: MetadataValidationReport?
    public let pushedLocales: [String]
    public let skippedLocales: [String]
    public let failureCode: MetadataFailureCode?

    public init(
        artifacts: [String],
        summary: String,
        directory: String,
        defaultLocale: String,
        locales: [String],
        diff: MetadataDiffReport? = nil,
        validation: MetadataValidationReport? = nil,
        pushedLocales: [String] = [],
        skippedLocales: [String] = [],
        failureCode: MetadataFailureCode? = nil
    ) {
        self.artifacts = artifacts
        self.summary = summary
        self.directory = directory
        self.defaultLocale = defaultLocale
        self.locales = locales
        self.diff = diff
        self.validation = validation
        self.pushedLocales = pushedLocales
        self.skippedLocales = skippedLocales
        self.failureCode = failureCode
    }
}

public enum MetadataEngineError: Error {
    case failed(
        classification: MetadataFailureCode,
        summary: String,
        exitCode: Int32,
        artifacts: [String],
        diff: MetadataDiffReport?,
        validation: MetadataValidationReport?
    )
}

public struct MetadataCommandResult: Sendable, Equatable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

    public init(exitCode: Int32, stdout: String = "", stderr: String = "") {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }
}

public protocol MetadataCommandRunning: Sendable {
    func run(command: [String], in workingDirectory: URL, environment: [String: String]) throws -> MetadataCommandResult
}

public struct ProcessMetadataCommandRunner: MetadataCommandRunning {
    public init() {}

    public func run(command: [String], in workingDirectory: URL, environment: [String: String]) throws -> MetadataCommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = command
        process.currentDirectoryURL = workingDirectory
        process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        return MetadataCommandResult(
            exitCode: process.terminationStatus,
            stdout: String(decoding: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self),
            stderr: String(decoding: stderrPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        )
    }
}

public struct MetadataEngine: Sendable {
    private let runner: any MetadataCommandRunning

    public init(runner: any MetadataCommandRunning = ProcessMetadataCommandRunner()) {
        self.runner = runner
    }

    public func run(request: MetadataRequest) throws -> MetadataResult {
        switch request.subcommand {
        case .pull:
            return try pull(request: request)
        case .diff:
            return try diff(request: request)
        case .push:
            return try push(request: request)
        case .validate:
            return try validate(request: request)
        }
    }
}

private extension MetadataEngine {
    struct ArtifactPayload: Codable {
        let command: String
        let subcommand: String
        let status: String
        let exitCode: Int
        let summary: String
        let directory: String
        let defaultLocale: String
        let locales: [String]
        let diff: MetadataDiffReport?
        let validation: MetadataValidationReport?
        let pushedLocales: [String]
        let skippedLocales: [String]
        let failureCode: String?
        let artifacts: [String]
    }

    func pull(request: MetadataRequest) throws -> MetadataResult {
        let context = try prepareContext(request: request)
        let remoteRoot = context.bundle.directory.appending(path: "workspace/remote")
        try FileManager.default.createDirectory(at: remoteRoot, withIntermediateDirectories: true)

        let result = try runFastlane(
            arguments: pullCommandArguments(
                profile: request.profile,
                apiKeyPath: context.apiKeyPath.path(percentEncoded: false),
                metadataPath: remoteRoot.path(percentEncoded: false)
            ),
            workingDirectory: context.root,
            environment: context.commandEnvironment
        )
        if result.exitCode != 0 {
            throw try fail(
                context: context,
                summary: failureSummary(subcommand: .pull, result: result),
                exitCode: result.exitCode,
                failureCode: .fastlane,
                diff: nil,
                validation: nil,
                pushedLocales: [],
                skippedLocales: []
            )
        }

        try syncManagedMetadata(from: remoteRoot, to: context.metadataRoot, contract: context.contract)
        let analysis = try analyzeMetadata(at: context.metadataRoot, contract: context.contract)
        let validation = try validationReport(for: analysis, defaultLocale: context.contract.defaultLocale)
        let summary = "metadata pull completed (\(analysis.locales.joined(separator: ", ")))"
        try writeArtifact(
            context: context,
            status: "success",
            exitCode: 0,
            summary: summary,
            diff: nil,
            validation: validation,
            pushedLocales: [],
            skippedLocales: []
        )

        return MetadataResult(
            artifacts: context.artifacts,
            summary: summary,
            directory: context.metadataRoot.path(percentEncoded: false),
            defaultLocale: context.contract.defaultLocale,
            locales: analysis.locales,
            diff: nil,
            validation: validation,
            pushedLocales: [],
            skippedLocales: [],
            failureCode: nil
        )
    }

    func diff(request: MetadataRequest) throws -> MetadataResult {
        let context = try prepareContext(request: request)
        let remoteRoot = context.bundle.directory.appending(path: "workspace/remote")
        try FileManager.default.createDirectory(at: remoteRoot, withIntermediateDirectories: true)

        let result = try runFastlane(
            arguments: pullCommandArguments(
                profile: request.profile,
                apiKeyPath: context.apiKeyPath.path(percentEncoded: false),
                metadataPath: remoteRoot.path(percentEncoded: false)
            ),
            workingDirectory: context.root,
            environment: context.commandEnvironment
        )
        if result.exitCode != 0 {
            throw try fail(
                context: context,
                summary: failureSummary(subcommand: .diff, result: result),
                exitCode: result.exitCode,
                failureCode: .fastlane,
                diff: nil,
                validation: nil,
                pushedLocales: [],
                skippedLocales: []
            )
        }

        let localAnalysis = try analyzeMetadata(at: context.metadataRoot, contract: context.contract)
        let remoteAnalysis = try analyzeMetadata(at: remoteRoot, contract: context.contract)
        let diff = try diffReport(local: localAnalysis, remote: remoteAnalysis)
        let summary = diff.hasChanges ? "metadata diff detected changes" : "metadata diff clean"
        try writeArtifact(
            context: context,
            status: "success",
            exitCode: 0,
            summary: summary,
            diff: diff,
            validation: nil,
            pushedLocales: [],
            skippedLocales: []
        )

        return MetadataResult(
            artifacts: context.artifacts,
            summary: summary,
            directory: context.metadataRoot.path(percentEncoded: false),
            defaultLocale: context.contract.defaultLocale,
            locales: localAnalysis.locales,
            diff: diff,
            validation: nil,
            pushedLocales: [],
            skippedLocales: [],
            failureCode: nil
        )
    }

    func push(request: MetadataRequest) throws -> MetadataResult {
        let context = try prepareContext(request: request)
        let analysis = try analyzeMetadata(at: context.metadataRoot, contract: context.contract)
        let validation = try validationReport(for: analysis, defaultLocale: context.contract.defaultLocale)
        guard validation.valid else {
            throw try fail(
                context: context,
                summary: "metadata validation failed before push",
                exitCode: 1,
                failureCode: .validation,
                diff: nil,
                validation: validation,
                pushedLocales: [],
                skippedLocales: []
            )
        }

        let result = try runFastlane(
            arguments: pushCommandArguments(
                profile: request.profile,
                apiKeyPath: context.apiKeyPath.path(percentEncoded: false),
                metadataPath: context.metadataRoot.path(percentEncoded: false)
            ),
            workingDirectory: context.root,
            environment: context.commandEnvironment
        )
        if result.exitCode != 0 {
            throw try fail(
                context: context,
                summary: failureSummary(subcommand: .push, result: result),
                exitCode: result.exitCode,
                failureCode: .fastlane,
                diff: nil,
                validation: validation,
                pushedLocales: [],
                skippedLocales: []
            )
        }

        let summary = "metadata push completed (\(analysis.locales.joined(separator: ", ")))"
        try writeArtifact(
            context: context,
            status: "success",
            exitCode: 0,
            summary: summary,
            diff: nil,
            validation: validation,
            pushedLocales: analysis.locales,
            skippedLocales: []
        )

        return MetadataResult(
            artifacts: context.artifacts,
            summary: summary,
            directory: context.metadataRoot.path(percentEncoded: false),
            defaultLocale: context.contract.defaultLocale,
            locales: analysis.locales,
            diff: nil,
            validation: validation,
            pushedLocales: analysis.locales,
            skippedLocales: [],
            failureCode: nil
        )
    }

    func validate(request: MetadataRequest) throws -> MetadataResult {
        let context = try prepareContext(request: request, requiresRemote: false)
        let analysis = try analyzeMetadata(at: context.metadataRoot, contract: context.contract)
        let validation = try validationReport(for: analysis, defaultLocale: context.contract.defaultLocale)
        let summary = validation.valid ? "metadata validation passed" : "metadata validation failed"
        let status = validation.valid ? "success" : "failed"
        let exitCode = validation.valid ? 0 : 1
        try writeArtifact(
            context: context,
            status: status,
            exitCode: exitCode,
            summary: summary,
            diff: nil,
            validation: validation,
            pushedLocales: [],
            skippedLocales: []
        )
        if !validation.valid {
            throw MetadataEngineError.failed(
                classification: .validation,
                summary: summary,
                exitCode: 1,
                artifacts: context.artifacts,
                diff: nil,
                validation: validation
            )
        }

        return MetadataResult(
            artifacts: context.artifacts,
            summary: summary,
            directory: context.metadataRoot.path(percentEncoded: false),
            defaultLocale: context.contract.defaultLocale,
            locales: analysis.locales,
            diff: nil,
            validation: validation,
            pushedLocales: [],
            skippedLocales: [],
            failureCode: nil
        )
    }

    struct Context {
        let root: URL
        let metadataRoot: URL
        let contract: MetadataDirectoryContract
        let apiKeyPath: URL
        let commandEnvironment: [String: String]
        let bundle: AdapterArtifactBundle
        let artifacts: [String]
        let subcommand: MetadataSubcommand
    }

    struct MetadataAnalysis {
        let locales: [String]
        let localeFiles: [String: [String: String]]
        let missingDefaultLocale: Bool
        let missingRequiredFiles: [String]
        let emptyRequiredFiles: [String]
        let extraFiles: [String]
    }

    func prepareContext(request: MetadataRequest, requiresRemote: Bool = true) throws -> Context {
        let root = request.projectRoot.standardizedFileURL
        let metadataRoot = root.appending(path: "metadata")
        try FileManager.default.createDirectory(at: metadataRoot, withIntermediateDirectories: true)

        let contract = try metadataContract(defaultLocale: request.profile.configuredPrimaryLanguage)
        let stamp = RuntimeSupport.timestamp()
        let commandName = "metadata-\(request.subcommand.rawValue)"
        let bundle = try AdapterArtifacts.makeBundle(command: commandName, projectRoot: root, stamp: stamp)
        let artifacts = bundle.artifacts
        let apiKeyPath = bundle.directory.appending(path: "workspace/api-key.json")
        let commandEnvironment: [String: String]

        if requiresRemote {
            let envCheck = SigningEnvironmentPolicy.validateAppStoreConnect(environment: request.environment)
            if !envCheck.missingKeys.isEmpty || !envCheck.invalidIssues.isEmpty {
                let details = envCheck.invalidIssues.map { "\($0.key)(\($0.rule))" }
                let summary = [
                    envCheck.missingKeys.isEmpty ? nil : "missing required environment: \(envCheck.missingKeys.joined(separator: ", "))",
                    details.isEmpty ? nil : "invalid environment format: \(details.joined(separator: ", "))"
                ]
                .compactMap { $0 }
                .joined(separator: "; ")
                throw try fail(
                    context: Context(
                        root: root,
                        metadataRoot: metadataRoot,
                        contract: contract,
                        apiKeyPath: apiKeyPath,
                        commandEnvironment: [:],
                        bundle: bundle,
                        artifacts: artifacts,
                        subcommand: request.subcommand
                    ),
                    summary: summary,
                    exitCode: 1,
                    failureCode: .validation,
                    diff: nil,
                    validation: try? validationReport(
                        for: analyzeMetadata(at: metadataRoot, contract: contract),
                        defaultLocale: contract.defaultLocale
                    ),
                    pushedLocales: [],
                    skippedLocales: []
                )
            }
            try writeAPIKeyFile(environment: request.environment, to: apiKeyPath)
            commandEnvironment = makeCommandEnvironment(from: request.environment)
        } else {
            commandEnvironment = [:]
        }

        return Context(
            root: root,
            metadataRoot: metadataRoot,
            contract: contract,
            apiKeyPath: apiKeyPath,
            commandEnvironment: commandEnvironment,
            bundle: bundle,
            artifacts: artifacts,
            subcommand: request.subcommand
        )
    }

    func metadataContract(defaultLocale: String) throws -> MetadataDirectoryContract {
        try MetadataDirectoryContract(
            rootDirectory: "metadata",
            defaultLocale: defaultLocale,
            localeDirectories: [
                .init(locale: defaultLocale, relativePath: "metadata/\(defaultLocale)")
            ],
            requiredFiles: [
                "name.txt",
                "subtitle.txt",
                "description.txt",
                "keywords.txt",
                "release_notes.txt"
            ],
            optionalFiles: [
                "promotional_text.txt",
                "marketing_url.txt",
                "support_url.txt",
                "privacy_url.txt"
            ]
        )
    }

    func writeAPIKeyFile(environment: [String: String], to path: URL) throws {
        let keyData = Data(base64Encoded: environment["ASC_KEY_P8_BASE64"] ?? "") ?? Data()
        let keyText = String(decoding: keyData, as: UTF8.self)
        let payload = [
            "key_id": environment["ASC_KEY_ID"] ?? "",
            "issuer_id": environment["ASC_ISSUER_ID"] ?? "",
            "key": keyText
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        try RuntimeSupport.writeFile(to: path, data: data)
    }

    func makeCommandEnvironment(from environment: [String: String]) -> [String: String] {
        var merged = environment
        merged["FASTLANE_DISABLE_COLORS"] = "1"
        merged["FASTLANE_SKIP_UPDATE_CHECK"] = "1"
        merged["FASTLANE_HIDE_TIMESTAMP"] = "1"
        merged["CI"] = "1"
        return merged
    }

    func pullCommandArguments(profile: Profile, apiKeyPath: String, metadataPath: String) -> [String] {
        [
            "fastlane", "deliver", "download_metadata",
            "--app_identifier", profile.configuredAppIdentifier ?? "",
            "--api_key_path", apiKeyPath,
            "--metadata_path", metadataPath,
            "--force", "true"
        ]
    }

    func pushCommandArguments(profile: Profile, apiKeyPath: String, metadataPath: String) -> [String] {
        [
            "fastlane", "deliver",
            "--app_identifier", profile.configuredAppIdentifier ?? "",
            "--api_key_path", apiKeyPath,
            "--metadata_path", metadataPath,
            "--skip_binary_upload", "true",
            "--skip_screenshots", "true",
            "--force", "true"
        ]
    }

    func runFastlane(
        arguments: [String],
        workingDirectory: URL,
        environment: [String: String]
    ) throws -> MetadataCommandResult {
        do {
            return try runner.run(command: arguments, in: workingDirectory, environment: environment)
        } catch {
            return MetadataCommandResult(exitCode: 127, stderr: "runner-error: \(error)")
        }
    }

    func analyzeMetadata(at root: URL, contract: MetadataDirectoryContract) throws -> MetadataAnalysis {
        let fm = FileManager.default
        let knownFiles = Set(contract.requiredFiles + contract.optionalFiles)
        var locales: [String] = []
        var localeFiles: [String: [String: String]] = [:]
        var missingRequiredFiles: [String] = []
        var emptyRequiredFiles: [String] = []
        var extraFiles: [String] = []

        if let entries = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
            for entry in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                var isDirectory: ObjCBool = false
                guard fm.fileExists(atPath: entry.path(percentEncoded: false), isDirectory: &isDirectory), isDirectory.boolValue else {
                    continue
                }
                let locale = entry.lastPathComponent
                locales.append(locale)
                var fileMap: [String: String] = [:]
                let fileEntries = try fm.contentsOfDirectory(at: entry, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
                for file in fileEntries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                    var isRegular: ObjCBool = false
                    guard fm.fileExists(atPath: file.path(percentEncoded: false), isDirectory: &isRegular), !isRegular.boolValue else {
                        continue
                    }
                    let name = file.lastPathComponent
                    let relativePath = "metadata/\(locale)/\(name)"
                    let content = try String(contentsOf: file, encoding: .utf8)
                    if knownFiles.contains(name) {
                        fileMap[name] = content
                    } else {
                        extraFiles.append(relativePath)
                    }
                }

                for requiredFile in contract.requiredFiles {
                    let relativePath = "metadata/\(locale)/\(requiredFile)"
                    guard let content = fileMap[requiredFile] else {
                        missingRequiredFiles.append(relativePath)
                        continue
                    }
                    if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        emptyRequiredFiles.append(relativePath)
                    }
                }
                localeFiles[locale] = fileMap
            }
        }

        return MetadataAnalysis(
            locales: locales,
            localeFiles: localeFiles,
            missingDefaultLocale: !locales.contains(contract.defaultLocale),
            missingRequiredFiles: missingRequiredFiles.sorted(),
            emptyRequiredFiles: emptyRequiredFiles.sorted(),
            extraFiles: extraFiles.sorted()
        )
    }

    func validationReport(for analysis: MetadataAnalysis, defaultLocale: String) throws -> MetadataValidationReport {
        try MetadataValidationReport(
            valid: !analysis.missingDefaultLocale && analysis.missingRequiredFiles.isEmpty && analysis.emptyRequiredFiles.isEmpty,
            missingLocales: analysis.missingDefaultLocale ? [defaultLocale] : [],
            missingRequiredFiles: analysis.missingRequiredFiles,
            emptyRequiredFiles: analysis.emptyRequiredFiles
        )
    }

    func diffReport(local: MetadataAnalysis, remote: MetadataAnalysis) throws -> MetadataDiffReport {
        let localeSet = Set(local.locales).union(remote.locales)
        var changedFiles = Set<String>()
        var missingLocales: [String] = []

        for locale in localeSet.sorted() {
            let localFiles = local.localeFiles[locale] ?? [:]
            let remoteFiles = remote.localeFiles[locale] ?? [:]
            if !local.locales.contains(locale) {
                missingLocales.append(locale)
            }

            let fileNames = Set(localFiles.keys).union(remoteFiles.keys)
            for fileName in fileNames {
                let localValue = localFiles[fileName]
                let remoteValue = remoteFiles[fileName]
                if localValue != remoteValue {
                    changedFiles.insert("metadata/\(locale)/\(fileName)")
                }
            }
        }

        return try MetadataDiffReport(
            hasChanges: !changedFiles.isEmpty || !missingLocales.isEmpty || !local.extraFiles.isEmpty,
            changedFiles: changedFiles.sorted(),
            missingLocales: missingLocales.sorted(),
            extraFiles: local.extraFiles
        )
    }

    func syncManagedMetadata(from sourceRoot: URL, to destinationRoot: URL, contract: MetadataDirectoryContract) throws {
        let fm = FileManager.default
        let managedFiles = contract.requiredFiles + contract.optionalFiles
        let sourceLocaleNames = Set(
            (try? fm.contentsOfDirectory(at: sourceRoot, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]))?
                .filter {
                    var isDirectory: ObjCBool = false
                    return fm.fileExists(atPath: $0.path(percentEncoded: false), isDirectory: &isDirectory) && isDirectory.boolValue
                }
                .map(\.lastPathComponent) ?? []
        )

        if let existingLocales = try? fm.contentsOfDirectory(at: destinationRoot, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
            for localeDir in existingLocales {
                var isDirectory: ObjCBool = false
                guard fm.fileExists(atPath: localeDir.path(percentEncoded: false), isDirectory: &isDirectory), isDirectory.boolValue else {
                    continue
                }
                guard !sourceLocaleNames.contains(localeDir.lastPathComponent) else {
                    continue
                }
                for fileName in managedFiles {
                    let targetFile = localeDir.appending(path: fileName)
                    if fm.fileExists(atPath: targetFile.path(percentEncoded: false)) {
                        try fm.removeItem(at: targetFile)
                    }
                }
            }
        }

        if let sourceLocales = try? fm.contentsOfDirectory(at: sourceRoot, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
            for localeDir in sourceLocales {
                var isDirectory: ObjCBool = false
                guard fm.fileExists(atPath: localeDir.path(percentEncoded: false), isDirectory: &isDirectory), isDirectory.boolValue else {
                    continue
                }
                let targetDir = destinationRoot.appending(path: localeDir.lastPathComponent)
                try fm.createDirectory(at: targetDir, withIntermediateDirectories: true)
                for fileName in managedFiles {
                    let sourceFile = localeDir.appending(path: fileName)
                    let targetFile = targetDir.appending(path: fileName)
                    if fm.fileExists(atPath: sourceFile.path(percentEncoded: false)) {
                        let content = try String(contentsOf: sourceFile, encoding: .utf8)
                        try RuntimeSupport.writeFile(to: targetFile, content: content)
                    } else if fm.fileExists(atPath: targetFile.path(percentEncoded: false)) {
                        try fm.removeItem(at: targetFile)
                    }
                }
            }
        }
    }

    func failureSummary(subcommand: MetadataSubcommand, result: MetadataCommandResult) -> String {
        let details = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        if details.isEmpty {
            return "metadata \(subcommand.rawValue) failed"
        }
        return details.count > 300 ? String(details.prefix(300)) + "..." : details
    }

    func fail(
        context: Context,
        summary: String,
        exitCode: Int32,
        failureCode: MetadataFailureCode,
        diff: MetadataDiffReport?,
        validation: MetadataValidationReport?,
        pushedLocales: [String],
        skippedLocales: [String]
    ) throws -> MetadataEngineError {
        try writeArtifact(
            context: context,
            status: "failed",
            exitCode: 11,
            summary: summary,
            diff: diff,
            validation: validation,
            pushedLocales: pushedLocales,
            skippedLocales: skippedLocales,
            failureCode: failureCode
        )
        return MetadataEngineError.failed(
            classification: failureCode,
            summary: summary,
            exitCode: exitCode,
            artifacts: context.artifacts,
            diff: diff,
            validation: validation
        )
    }

    func writeArtifact(
        context: Context,
        status: String,
        exitCode: Int,
        summary: String,
        diff: MetadataDiffReport?,
        validation: MetadataValidationReport?,
        pushedLocales: [String],
        skippedLocales: [String],
        failureCode: MetadataFailureCode? = nil
    ) throws {
        let analysis = try analyzeMetadata(at: context.metadataRoot, contract: context.contract)
        _ = try AdapterArtifacts.write(
            bundle: context.bundle,
            envelope: AdapterRunEnvelope(
                command: "metadata",
                status: status,
                exitCode: exitCode,
                summary: summary,
                payload: ArtifactPayload(
                    command: "metadata",
                    subcommand: context.subcommand.rawValue,
                    status: status,
                    exitCode: exitCode,
                    summary: summary,
                    directory: context.metadataRoot.path(percentEncoded: false),
                    defaultLocale: context.contract.defaultLocale,
                    locales: analysis.locales,
                    diff: diff,
                    validation: validation,
                    pushedLocales: pushedLocales,
                    skippedLocales: skippedLocales,
                    failureCode: failureCode?.rawValue,
                    artifacts: context.artifacts
                )
            ),
            stdout: renderLog(
                subcommand: context.subcommand,
                summary: summary,
                locales: analysis.locales,
                diff: diff,
                validation: validation,
                pushedLocales: pushedLocales,
                skippedLocales: skippedLocales
            ),
            stderr: ""
        )
    }

    func renderLog(
        subcommand: MetadataSubcommand,
        summary: String,
        locales: [String],
        diff: MetadataDiffReport?,
        validation: MetadataValidationReport?,
        pushedLocales: [String],
        skippedLocales: [String]
    ) -> String {
        var lines = [
            "# bos metadata \(subcommand.rawValue)",
            "summary=\(summary)",
            "locales=\(locales.joined(separator: ","))"
        ]
        if let diff {
            lines.append("hasChanges=\(diff.hasChanges)")
            lines.append("changedFiles=\(diff.changedFiles.joined(separator: ","))")
            lines.append("missingLocales=\(diff.missingLocales.joined(separator: ","))")
            lines.append("extraFiles=\(diff.extraFiles.joined(separator: ","))")
        }
        if let validation {
            lines.append("valid=\(validation.valid)")
            lines.append("missingRequiredFiles=\(validation.missingRequiredFiles.joined(separator: ","))")
            lines.append("emptyRequiredFiles=\(validation.emptyRequiredFiles.joined(separator: ","))")
        }
        if !pushedLocales.isEmpty {
            lines.append("pushedLocales=\(pushedLocales.joined(separator: ","))")
        }
        if !skippedLocales.isEmpty {
            lines.append("skippedLocales=\(skippedLocales.joined(separator: ","))")
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
