import Foundation
import BosCore

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

    let projectRoot = resolveProjectRoot(from: parsed)
    let blueprintContext = loadBlueprintContext(
        raw: parsed.values["--blueprint"],
        projectRoot: projectRoot,
        command: .apply,
        format: format
    )
    let profileContext = loadProfileContext(
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
                    blueprint: blueprintContext.blueprint,
                    profile: profileContext.profile,
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
                blueprint: blueprintContext.blueprint,
                profile: profileContext.profile,
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
