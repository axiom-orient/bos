import CryptoKit
import Foundation

public enum ApplyMode: String, Sendable {
    case initMode = "init"
    case incremental
}

public struct ApplyRequest: Sendable {
    public let projectRoot: URL
    public let blueprint: BlueprintV1
    public let profile: ProfileV1
    public let mode: ApplyMode
    public let fix: Bool

    public init(
        projectRoot: URL,
        blueprint: BlueprintV1,
        profile: ProfileV1,
        mode: ApplyMode = .initMode,
        fix: Bool = false
    ) {
        self.projectRoot = projectRoot
        self.blueprint = blueprint
        self.profile = profile
        self.mode = mode
        self.fix = fix
    }
}

public struct ApplyResult: Sendable {
    public let managedFiles: [String]
    public let artifacts: [String]
    public let lockFile: String
}

public struct ScaffoldCommandResult: Sendable, Equatable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

    public init(exitCode: Int32, stdout: String = "", stderr: String = "") {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }
}

public protocol ScaffoldCommandRunning: Sendable {
    func run(command: [String], in workingDirectory: URL) throws -> ScaffoldCommandResult
}

public struct ProcessScaffoldRunner: ScaffoldCommandRunning {
    public init() {}

    public func run(command: [String], in workingDirectory: URL) throws -> ScaffoldCommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = command
        process.currentDirectoryURL = workingDirectory

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        return ScaffoldCommandResult(
            exitCode: process.terminationStatus,
            stdout: String(decoding: stdoutData, as: UTF8.self),
            stderr: String(decoding: stderrData, as: UTF8.self)
        )
    }
}

public enum ApplyEngineError: Error, Equatable {
    case unsupportedMode(ApplyMode)
    case managedBlockMissing(path: String)
    case anchorMismatch(path: String)
    case driftDetected(path: String)
    case outsideManagedAreaChanged(path: String)
    case tmaPluginResourceMissing(resourcePath: String)
    case scaffoldFailed(command: String, exitCode: Int32, stderr: String)
}

public struct ApplyEngine: Sendable {
    private let scaffoldRunner: any ScaffoldCommandRunning

    public init(scaffoldRunner: any ScaffoldCommandRunning = ProcessScaffoldRunner()) {
        self.scaffoldRunner = scaffoldRunner
    }

    public func apply(request: ApplyRequest) throws -> ApplyResult {
        switch request.mode {
        case .initMode:
            return try applyInit(request: request)
        case .incremental:
            return try applyIncremental(request: request)
        }
    }
}

extension ApplyEngine {
    private enum Constant {
        static let beginMarker = "// bootstrap:begin app.dependencies"
        static let endMarker = "// bootstrap:end app.dependencies"
        static let appCompositionRelativePath = "Projects/App/Sources/Dependencies/AppComposition.swift"
        static let appCompositionAnchor = "public static func configureAll(_ values: inout DependencyValues) {"
        static let stateDirectory = ".bos/state"
        static let bootstrapStateFileName = "bos.state.yaml"
        static let tmaPluginResourcePath = "tma_plugin"
        static let projectBootstrapResourcePath = "project_bootstrap"
        static let tuistPluginPath = "Tuist/Plugins/tma"
        static let defaultOrganization = "axient"
    }

    private struct ManagedSections {
        let prefix: String
        let managed: String
        let suffix: String
        let fullBlock: String
    }

    private struct ArtifactPayload: Codable {
        let command: String
        let status: String
        let exitCode: Int
        let summary: String
        let artifacts: [String]
    }

    private func applyInit(request: ApplyRequest) throws -> ApplyResult {
        let root = request.projectRoot.standardizedFileURL
        let fm = FileManager.default
        try fm.createDirectory(at: root, withIntermediateDirectories: true)

        try scaffoldModules(root: root, blueprint: request.blueprint)

        let target = root.appending(path: Constant.appCompositionRelativePath)
        let expected = appCompositionTemplate(from: request.blueprint)
        try RuntimeSupport.writeFile(to: target, content: expected)

        return try persistApplyResult(
            root: root,
            blueprint: request.blueprint,
            profile: request.profile,
            managedPath: target.path(percentEncoded: false),
            summary: "Apply init completed with managed block update"
        )
    }

    private func applyIncremental(request: ApplyRequest) throws -> ApplyResult {
        let root = request.projectRoot.standardizedFileURL
        let target = root.appending(path: Constant.appCompositionRelativePath)
        let targetPath = target.path(percentEncoded: false)
        let fm = FileManager.default

        guard fm.fileExists(atPath: targetPath) else {
            throw ApplyEngineError.managedBlockMissing(path: targetPath)
        }

        let current = try String(contentsOf: target, encoding: .utf8)
        let expected = appCompositionTemplate(from: request.blueprint)
        let expectedSections = try parseManagedSections(in: expected, path: targetPath)

        let updatedContent: String
        let summary: String

        do {
            let currentSections = try parseManagedSections(in: current, path: targetPath)

            // Outside managed block drift is always a hard fail.
            if currentSections.prefix != expectedSections.prefix || currentSections.suffix != expectedSections.suffix {
                throw ApplyEngineError.outsideManagedAreaChanged(path: targetPath)
            }

            if normalizeManagedContent(currentSections.managed) == normalizeManagedContent(expectedSections.managed) {
                updatedContent = current
                summary = "No drift detected in managed block"
            } else if request.fix {
                updatedContent = currentSections.prefix + expectedSections.fullBlock + currentSections.suffix
                summary = "Drift detected and fixed in managed block"
            } else {
                throw ApplyEngineError.driftDetected(path: targetPath)
            }
        } catch let error as ApplyEngineError {
            switch error {
            case .managedBlockMissing where request.fix:
                updatedContent = try insertManagedBlock(
                    into: current,
                    managedBlock: expectedSections.fullBlock,
                    path: targetPath
                )
                summary = "Managed block was missing and inserted by --fix"
            default:
                throw error
            }
        }

        if updatedContent != current {
            try RuntimeSupport.writeFile(to: target, content: updatedContent)
        }

        return try persistApplyResult(
            root: root,
            blueprint: request.blueprint,
            profile: request.profile,
            managedPath: targetPath,
            summary: summary
        )
    }

    private func scaffoldModules(root: URL, blueprint: BlueprintV1) throws {
        try installTMAPluginIfMissing(root: root)
        try installProjectBootstrapFilesIfMissing(root: root)
        try writeRootTuistFilesIfMissing(root: root, workspaceName: blueprint.project.name)

        let appName = "\(sanitizeModuleName(blueprint.project.name))App"
        try scaffoldAppIfNeeded(
            root: root,
            blueprint: blueprint,
            appName: appName,
            rootFeatureName: sanitizeModuleName(blueprint.wiring.rootFeature)
        )

        try scaffoldLayerModulesIfNeeded(
            root: root,
            blueprint: blueprint,
            template: "domain",
            layerFolder: "Domains",
            moduleNames: blueprint.modules.domains.map(sanitizeModuleName)
        )
        try scaffoldLayerModulesIfNeeded(
            root: root,
            blueprint: blueprint,
            template: "feature",
            layerFolder: "Features",
            moduleNames: blueprint.modules.features.map(sanitizeModuleName)
        )
        try scaffoldLayerModulesIfNeeded(
            root: root,
            blueprint: blueprint,
            template: "service",
            layerFolder: "Services",
            moduleNames: blueprint.modules.services.map { sanitizeModuleName(normalizeServiceName($0)) }
        )
        try scaffoldLayerModulesIfNeeded(
            root: root,
            blueprint: blueprint,
            template: "shared",
            layerFolder: "Shared",
            moduleNames: blueprint.modules.shared.map(sanitizeModuleName)
        )
    }

    private func installTMAPluginIfMissing(root: URL) throws {
        let fm = FileManager.default
        let targetPath = root.appending(path: Constant.tuistPluginPath)
        let targetPathString = targetPath.path(percentEncoded: false)
        guard !fm.fileExists(atPath: targetPathString) else {
            return
        }

        guard let resourceRoot = Bundle.module.resourceURL else {
            throw ApplyEngineError.tmaPluginResourceMissing(resourcePath: Constant.tmaPluginResourcePath)
        }
        let sourcePath = resourceRoot.appending(path: Constant.tmaPluginResourcePath)
        let sourcePathString = sourcePath.path(percentEncoded: false)
        guard fm.fileExists(atPath: sourcePathString) else {
            throw ApplyEngineError.tmaPluginResourceMissing(resourcePath: sourcePathString)
        }

        try fm.createDirectory(at: targetPath.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.copyItem(at: sourcePath, to: targetPath)
    }

    private func writeRootTuistFilesIfMissing(root: URL, workspaceName: String) throws {
        let tuistPath = root.appending(path: "Tuist.swift")
        _ = try writeFileIfMissing(
            to: tuistPath,
            content: """
            import ProjectDescription

            let tuist = Tuist(
                project: .tuist(
                    plugins: [
                        .local(path: .relativeToRoot("\(Constant.tuistPluginPath)"))
                    ],
                    generationOptions: .options(
                        resolveDependenciesWithSystemScm: true,
                        disableSandbox: true
                    )
                )
            )
            """
        )

        let workspacePath = root.appending(path: "Workspace.swift")
        _ = try writeFileIfMissing(
            to: workspacePath,
            content: """
            import ProjectDescription

            let workspace = Workspace(
                name: "\(workspaceName)",
                projects: [
                    "Projects/**"
                ]
            )
            """
        )

        let packagePath = root.appending(path: "Tuist/Package.swift")
        let packageName = "\(sanitizeModuleName(workspaceName))Dependencies"
        _ = try writeFileIfMissing(
            to: packagePath,
            content: """
            // swift-tools-version: 6.0
            import PackageDescription

            #if TUIST
            import ProjectDescription

            let packageSettings = PackageSettings(
                productTypes: [
                    "ComposableArchitecture": .framework,
                    "Dependencies": .framework
                ]
            )
            #endif

            let package = Package(
                name: "\(packageName)",
                dependencies: [
                    // Core Frameworks
                    .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.24.1"),
                    .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.11.0"),
                    // Navigation & UI State
                    .package(url: "https://github.com/pointfreeco/swift-navigation", from: "2.4.0"),
                    // Data & Persistence
                    .package(url: "https://github.com/pointfreeco/sqlite-data", from: "1.6.0"),
                    .package(url: "https://github.com/pointfreeco/swift-identified-collections", from: "1.1.0")
                ]
            )
            """
        )
    }

    private func installProjectBootstrapFilesIfMissing(root: URL) throws {
        guard let resourceRoot = Bundle.module.resourceURL else {
            throw ApplyEngineError.tmaPluginResourceMissing(resourcePath: Constant.projectBootstrapResourcePath)
        }

        let sourceRoot = resourceRoot.appending(path: Constant.projectBootstrapResourcePath)
        let sourceRootPath = sourceRoot.path(percentEncoded: false)
        guard FileManager.default.fileExists(atPath: sourceRootPath) else {
            throw ApplyEngineError.tmaPluginResourceMissing(resourcePath: sourceRootPath)
        }

        try copyTreeIfMissing(
            from: sourceRoot.appending(path: "AGENTS.md"),
            to: root.appending(path: "AGENTS.md")
        )
        try copyTreeIfMissing(
            from: sourceRoot.appending(path: "CLAUDE.md"),
            to: root.appending(path: "CLAUDE.md")
        )
        try copyTreeIfMissing(
            from: sourceRoot.appending(path: "Rules"),
            to: root.appending(path: "Rules")
        )
    }

    private func copyTreeIfMissing(from source: URL, to destination: URL) throws {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        let sourcePath = source.path(percentEncoded: false)
        guard fm.fileExists(atPath: sourcePath, isDirectory: &isDirectory) else {
            throw ApplyEngineError.tmaPluginResourceMissing(resourcePath: sourcePath)
        }

        let destinationPath = destination.path(percentEncoded: false)
        if isDirectory.boolValue {
            if !fm.fileExists(atPath: destinationPath) {
                try fm.createDirectory(at: destination, withIntermediateDirectories: true)
            }
            let children = try fm.contentsOfDirectory(
                at: source,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            for child in children {
                try copyTreeIfMissing(from: child, to: destination.appending(path: child.lastPathComponent))
            }
            return
        }

        if fm.fileExists(atPath: destinationPath) {
            return
        }
        try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.copyItem(at: source, to: destination)
    }

    private func scaffoldAppIfNeeded(
        root: URL,
        blueprint: BlueprintV1,
        appName: String,
        rootFeatureName: String
    ) throws {
        let appProjectPath = root.appending(path: "Projects/App/Project.swift")
        guard !FileManager.default.fileExists(atPath: appProjectPath.path(percentEncoded: false)) else {
            return
        }

        let command = baseScaffoldCommand(
            template: "app",
            name: appName,
            blueprint: blueprint
        ) + ["--root-feature-name", rootFeatureName]
        try runScaffold(command: command, in: root)
    }

    private func scaffoldLayerModulesIfNeeded(
        root: URL,
        blueprint: BlueprintV1,
        template: String,
        layerFolder: String,
        moduleNames: [String]
    ) throws {
        let unique = RuntimeSupport.uniqueOrdered(moduleNames)
        for moduleName in unique {
            let projectPath = root.appending(path: "Projects/\(layerFolder)/\(moduleName)/Project.swift")
            guard !FileManager.default.fileExists(atPath: projectPath.path(percentEncoded: false)) else {
                continue
            }
            let command = baseScaffoldCommand(
                template: template,
                name: moduleName,
                blueprint: blueprint
            )
            try runScaffold(command: command, in: root)
        }
    }

    private func baseScaffoldCommand(template: String, name: String, blueprint: BlueprintV1) -> [String] {
        [
            "tuist", "scaffold", template,
            "--name", name,
            "--organization-name", Constant.defaultOrganization,
            "--bundle-id-prefix", blueprint.project.bundleIdPrefix,
            "--deployment-target", blueprint.project.deploymentTarget
        ]
    }

    private func runScaffold(command: [String], in root: URL) throws {
        let result = try scaffoldRunner.run(command: command, in: root)
        if result.exitCode != 0 {
            throw ApplyEngineError.scaffoldFailed(
                command: command.joined(separator: " "),
                exitCode: result.exitCode,
                stderr: result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }

    private func appCompositionTemplate(from blueprint: BlueprintV1) -> String {
        let block = managedBlockString(from: blueprint)
        return [
            "import Dependencies",
            "",
            "public enum AppComposition {",
            "    public static func configureAll(_ values: inout DependencyValues) {",
            "        values.appAnalyticsService = .live",
            "        values.updateChecker = .live",
            block,
            "    }",
            "}",
            ""
        ].joined(separator: "\n")
    }

    private func managedBlockString(from blueprint: BlueprintV1) -> String {
        var lines: [String] = []
        lines.append("        \(Constant.beginMarker)")
        lines.append(contentsOf: managedDependencyEntries(from: blueprint).map { "        // \($0)" })
        lines.append("        \(Constant.endMarker)")
        return lines.joined(separator: "\n")
    }

    private func managedDependencyEntries(from blueprint: BlueprintV1) -> [String] {
        var result: [String] = []
        result.reserveCapacity(
            blueprint.modules.features.count +
            blueprint.modules.domains.count +
            blueprint.modules.services.count +
            blueprint.modules.shared.count
        )
        result.append(contentsOf: blueprint.modules.features.map { "Feature\(sanitizeModuleName($0))" })
        result.append(contentsOf: blueprint.modules.domains.map { "Domain\(sanitizeModuleName($0))" })
        result.append(contentsOf: blueprint.modules.services.map { "Service\(sanitizeModuleName(normalizeServiceName($0)))" })
        result.append(contentsOf: blueprint.modules.shared.map { "Shared\(sanitizeModuleName($0))" })
        return result
    }

    private func parseManagedSections(in text: String, path: String) throws -> ManagedSections {
        let begin = text.range(of: Constant.beginMarker)
        let end = text.range(of: Constant.endMarker)

        switch (begin, end) {
        case (nil, nil):
            throw ApplyEngineError.managedBlockMissing(path: path)
        case (.some, nil), (nil, .some):
            throw ApplyEngineError.anchorMismatch(path: path)
        case let (beginRange?, endRange?):
            guard beginRange.upperBound <= endRange.lowerBound else {
                throw ApplyEngineError.anchorMismatch(path: path)
            }
            let prefix = String(text[..<beginRange.lowerBound])
            let managed = String(text[beginRange.upperBound..<endRange.lowerBound])
            let suffix = String(text[endRange.upperBound...])
            let fullBlock = String(text[beginRange.lowerBound..<endRange.upperBound])
            return ManagedSections(prefix: prefix, managed: managed, suffix: suffix, fullBlock: fullBlock)
        }
    }

    private func normalizeManagedContent(_ raw: String) -> String {
        raw
            .split(whereSeparator: \Character.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    private func insertManagedBlock(into source: String, managedBlock: String, path: String) throws -> String {
        guard let anchorRange = source.range(of: Constant.appCompositionAnchor) else {
            throw ApplyEngineError.anchorMismatch(path: path)
        }

        let prefix = String(source[..<anchorRange.upperBound])
        let suffix = String(source[anchorRange.upperBound...])

        var insertion = managedBlock
        if !prefix.hasSuffix("\n") {
            insertion = "\n" + insertion
        }
        if !insertion.hasSuffix("\n") {
            insertion += "\n"
        }
        return prefix + insertion + suffix
    }

    private func persistApplyResult(
        root: URL,
        blueprint: BlueprintV1,
        profile: ProfileV1,
        managedPath: String,
        summary: String
    ) throws -> ApplyResult {
        let lockPath = root
            .appending(path: Constant.stateDirectory)
            .appending(path: Constant.bootstrapStateFileName)
        try writeBootstrapLock(
            to: lockPath,
            blueprint: blueprint,
            profile: profile,
            managedFiles: [managedPath]
        )

        let artifactsDir = try RuntimeArtifacts.makeDirectory(for: "apply")

        let artifactPath = artifactsDir.appending(path: "apply-\(RuntimeSupport.timestamp()).json")
        try writeArtifact(
            to: artifactPath,
            summary: summary,
            artifacts: [artifactPath.path(percentEncoded: false)]
        )

        return ApplyResult(
            managedFiles: [managedPath],
            artifacts: [artifactPath.path(percentEncoded: false)],
            lockFile: lockPath.path(percentEncoded: false)
        )
    }

    private func writeBootstrapLock(
        to path: URL,
        blueprint: BlueprintV1,
        profile: ProfileV1,
        managedFiles: [String]
    ) throws {
        let blueprintHash = try sha256Hex(of: blueprint)
        let profileHash = try sha256Hex(of: profile)
        let managed = managedFiles.map { "  - \($0)" }.joined(separator: "\n")

        let content = """
        appliedAt: "\(RuntimeSupport.isoNow())"
        blueprintHash: "\(blueprintHash)"
        profileHash: "\(profileHash)"
        managedFiles:
        \(managed)
        verifySummary:
          status: "not-run"
          message: "verify not executed in apply step"
        releaseSummary:
          status: "not-run"
          message: "release-init not executed in apply step"
        """
        try RuntimeSupport.writeFile(to: path, content: content)
    }

    private func writeArtifact(to path: URL, summary: String, artifacts: [String]) throws {
        let payload = ArtifactPayload(
            command: "apply",
            status: "success",
            exitCode: 0,
            summary: summary,
            artifacts: artifacts
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        try RuntimeSupport.writeFile(to: path, data: data)
    }

    @discardableResult
    private func writeFileIfMissing(to path: URL, content: String) throws -> Bool {
        if FileManager.default.fileExists(atPath: path.path(percentEncoded: false)) {
            return false
        }
        try RuntimeSupport.writeFile(to: path, content: content)
        return true
    }

    private func sanitizeModuleName(_ raw: String) -> String {
        NameNormalizer.pascalCase(raw, fallback: "Module")
    }

    private func normalizeServiceName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.lowercased().hasSuffix("service"), trimmed.count > "service".count else { return trimmed }
        return String(trimmed.dropLast("service".count))
    }

    private func sha256Hex<T: Encodable>(of value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(value)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
