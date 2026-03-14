import Foundation
import BosCore

func runScreenshots(args: [String], format: OutputFormat) {
    guard let rawSubcommand = args.first, let subcommand = ScreenshotSubcommand(rawValue: rawSubcommand) else {
        fail(
            message: "screenshots requires one of: plan, capture, compose, validate",
            command: .screenshots,
            format: format
        )
    }

    let parsed = parseOptions(
        args: Array(args.dropFirst()),
        valueFlags: ["--project-root", "--plan", "--format"],
        booleanFlags: []
    )
    assertOptionContract(parsed: parsed, command: .screenshots, format: format)

    let projectRoot = resolveProjectRoot(from: parsed)
    let planContext = loadScreenshotPlanContext(
        raw: parsed.values["--plan"],
        projectRoot: projectRoot,
        command: .screenshots,
        format: format
    )

    let engine = ScreenshotsEngine()
    do {
        let result = try engine.run(
            request: ScreenshotRequest(
                projectRoot: projectRoot,
                planPath: planContext.path,
                plan: planContext.plan,
                subcommand: subcommand
            )
        )
        switch format {
        case .human:
            renderHumanSuccess(summary: result.summary, artifacts: result.artifacts)
        case .json:
            printScreenshotsJSONPayload(
                status: "success",
                exitCode: Int(ExitCode.success.rawValue),
                summary: result.summary,
                subcommand: subcommand,
                planPath: result.planPath,
                defaultLocale: result.defaultLocale,
                summaryReport: result.summaryReport,
                capturedShots: result.capturedShots,
                failedShots: result.failedShots,
                outputDirectory: result.outputDirectory,
                composedFiles: result.composedFiles,
                missingOutputs: result.missingOutputs,
                valid: result.valid,
                unexpectedFiles: result.unexpectedFiles,
                failureCode: nil,
                artifacts: result.artifacts
            )
        }
        exit(ExitCode.success.rawValue)
    } catch let error as ScreenshotsEngineError {
        let payload: (
            summary: String,
            failureCode: ScreenshotFailureCode,
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
        switch error {
        case .failed(
            let classification,
            let summary,
            let artifacts,
            let outputDirectory,
            let summaryReport,
            let capturedShots,
            let failedShots,
            let composedFiles,
            let missingOutputs,
            let unexpectedFiles,
            let valid
        ):
            payload = (
                summary,
                classification,
                artifacts,
                outputDirectory,
                summaryReport,
                capturedShots,
                failedShots,
                composedFiles,
                missingOutputs,
                unexpectedFiles,
                valid
            )
        }

        switch format {
        case .human:
            fputs("error: \(payload.summary)\n", stderr)
        case .json:
            printScreenshotsJSONPayload(
                status: "failed",
                exitCode: Int(ExitCode.screenshotsFailed.rawValue),
                summary: payload.summary,
                subcommand: subcommand,
                planPath: planContext.path.path(percentEncoded: false),
                defaultLocale: planContext.plan.defaultLocale,
                summaryReport: payload.summaryReport,
                capturedShots: payload.capturedShots,
                failedShots: payload.failedShots,
                outputDirectory: payload.outputDirectory,
                composedFiles: payload.composedFiles,
                missingOutputs: payload.missingOutputs,
                valid: payload.valid,
                unexpectedFiles: payload.unexpectedFiles,
                failureCode: payload.failureCode,
                artifacts: payload.artifacts
            )
        }
        exit(ExitCode.screenshotsFailed.rawValue)
    } catch {
        fail(
            message: "screenshots \(subcommand.rawValue) failed: \(error)",
            command: .screenshots,
            format: format,
            exitCode: .screenshotsFailed
        )
    }
}
