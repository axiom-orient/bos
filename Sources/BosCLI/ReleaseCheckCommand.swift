import Foundation
import BosCore

func runReleaseCheck(args: [String], format: OutputFormat) {
    let parsed = parseOptions(
        args: args,
        valueFlags: ["--project-root", "--profile", "--mode", "--format"],
        booleanFlags: ["--allow-write"]
    )
    assertOptionContract(parsed: parsed, command: .releaseCheck, format: format)

    let projectRoot = resolveProjectRoot(from: parsed)
    let profileContext = loadProfileContext(
        raw: parsed.values["--profile"],
        projectRoot: projectRoot,
        command: .releaseCheck,
        format: format
    )
    let mode = parseReleaseCheckMode(
        raw: parsed.values["--mode"],
        command: .releaseCheck,
        format: format
    )
    let allowWrite = parsed.flags.contains("--allow-write")

    if mode == .syncCerts && !allowWrite {
        fail(
            message: "`--mode sync-certs` requires explicit `--allow-write`",
            command: .releaseCheck,
            format: format
        )
    }
    if allowWrite && mode != .syncCerts {
        fail(
            message: "`--allow-write` is only valid with `--mode sync-certs`",
            command: .releaseCheck,
            format: format
        )
    }

    let signingContext = loadSigningContext(
        projectRoot: projectRoot,
        profile: profileContext.profile,
        command: .releaseCheck,
        format: format,
        exitCode: .releaseCheckFailed
    )

    do {
        let result = try ReleaseCheckEngine(
            runner: ProcessReleaseCheckRunner()
        ).releaseCheck(
            request: ReleaseCheckRequest(
                projectRoot: projectRoot,
                profile: profileContext.profile,
                environment: signingContext.environment,
                mode: mode
            )
        )

        let summary: String
        if let note = signingContext.note {
            summary = "\(note). \(result.summary)"
        } else {
            summary = result.summary
        }

        switch format {
        case .human:
            renderHumanSuccess(summary: summary, artifacts: result.artifacts)
        case .json:
            printReleaseCheckJSONPayload(
                status: "success",
                exitCode: Int(ExitCode.success.rawValue),
                summary: summary,
                mode: result.mode,
                failureCode: nil,
                failedStep: nil,
                artifacts: result.artifacts
            )
        }
        exit(ExitCode.success.rawValue)
    } catch let error as ReleaseCheckEngineError {
        switch error {
        case .failed(let classification, let step, let summary, _, let artifacts):
            switch format {
            case .human:
                fputs("error: \(summary)\n", stderr)
            case .json:
                printReleaseCheckJSONPayload(
                    status: "failed",
                    exitCode: Int(ExitCode.releaseCheckFailed.rawValue),
                    summary: summary,
                    mode: mode,
                    failureCode: classification,
                    failedStep: step,
                    artifacts: artifacts
                )
            }
            exit(ExitCode.releaseCheckFailed.rawValue)
        }
    } catch {
        fail(
            message: "\(error)",
            command: .releaseCheck,
            format: format,
            exitCode: .releaseCheckFailed
        )
    }
}
