import Foundation
import BosCore

func runMetadata(args: [String], format: OutputFormat) {
    guard let rawSubcommand = args.first, let subcommand = MetadataSubcommand(rawValue: rawSubcommand) else {
        fail(
            message: "metadata requires one of: pull, diff, push, validate",
            command: .metadata,
            format: format
        )
    }

    let parsed = parseOptions(
        args: Array(args.dropFirst()),
        valueFlags: ["--project-root", "--profile"],
        booleanFlags: []
    )
    assertOptionContract(parsed: parsed, command: .metadata, format: format)

    let projectRoot = resolveProjectRoot(from: parsed)
    let profileContext = loadProfileContext(
        raw: parsed.values["--profile"],
        projectRoot: projectRoot,
        command: .metadata,
        format: format
    )
    let signingContext: CLISigningContext?
    switch subcommand {
    case .pull, .diff, .push:
        signingContext = loadSigningContext(
            projectRoot: projectRoot,
            profile: profileContext.profile,
            command: .metadata,
            format: format,
            exitCode: .metadataFailed
        )
    case .validate:
        signingContext = nil
    }

    let engine = MetadataEngine()
    do {
        let result = try engine.run(
            request: MetadataRequest(
                projectRoot: projectRoot,
                profile: profileContext.profile,
                environment: signingContext?.environment ?? [:],
                subcommand: subcommand
            )
        )
        switch format {
        case .human:
            renderHumanSuccess(summary: result.summary, artifacts: result.artifacts)
        case .json:
            printMetadataJSONPayload(
                status: "success",
                exitCode: Int(ExitCode.success.rawValue),
                summary: result.summary,
                subcommand: subcommand,
                directory: result.directory,
                defaultLocale: result.defaultLocale,
                locales: result.locales,
                diff: result.diff,
                validation: result.validation,
                pushedLocales: result.pushedLocales,
                skippedLocales: result.skippedLocales,
                failureCode: nil,
                artifacts: result.artifacts
            )
        }
        exit(ExitCode.success.rawValue)
    } catch let error as MetadataEngineError {
        let payload: (
            summary: String,
            failureCode: MetadataFailureCode,
            artifacts: [String],
            exitCode: Int32,
            diff: MetadataDiffReport?,
            validation: MetadataValidationReport?
        )
        switch error {
        case .failed(let classification, let summary, let exitCode, let artifacts, let diff, let validation):
            payload = (summary, classification, artifacts, exitCode, diff, validation)
        }

        switch format {
        case .human:
            fputs("error: \(payload.summary)\n", stderr)
        case .json:
            printMetadataJSONPayload(
                status: "failed",
                exitCode: Int(ExitCode.metadataFailed.rawValue),
                summary: payload.summary,
                subcommand: subcommand,
                directory: projectRoot.appending(path: "metadata").path(percentEncoded: false),
                defaultLocale: profileContext.profile.configuredPrimaryLanguage,
                locales: [],
                diff: payload.diff,
                validation: payload.validation,
                pushedLocales: [],
                skippedLocales: [],
                failureCode: payload.failureCode,
                artifacts: payload.artifacts
            )
        }
        exit(ExitCode.metadataFailed.rawValue)
    } catch {
        fail(
            message: "metadata \(subcommand.rawValue) failed: \(error)",
            command: .metadata,
            format: format,
            exitCode: .metadataFailed
        )
    }
}
