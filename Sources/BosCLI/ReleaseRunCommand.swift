import Foundation
import BosCore

func runReleaseRun(args: [String], format: OutputFormat) {
    let parsed = parseOptions(
        args: args,
        valueFlags: ["--project-root", "--blueprint", "--profile", "--stage", "--format"],
        booleanFlags: ["--allow-signing-write"]
    )
    assertOptionContract(parsed: parsed, command: .releaseRun, format: format)

    let projectRoot = resolveProjectRoot(from: parsed)
    let blueprintContext = loadBlueprintContext(
        raw: parsed.values["--blueprint"],
        projectRoot: projectRoot,
        command: .releaseRun,
        format: format
    )
    let profileContext = loadProfileContext(
        raw: parsed.values["--profile"],
        projectRoot: projectRoot,
        command: .releaseRun,
        format: format
    )
    let stage = parseReleaseRunStage(
        raw: parsed.values["--stage"],
        command: .releaseRun,
        format: format
    )
    let allowSigningWrite = parsed.flags.contains("--allow-signing-write")

    let signingContext = loadSigningContext(
        projectRoot: projectRoot,
        profile: profileContext.profile,
        command: .releaseRun,
        format: format,
        exitCode: .releaseRunFailed
    )

    do {
        let releaseChecker = ReleaseCheckEngine(runner: ProcessReleaseCheckRunner())
        let result = try ReleaseRunEngine(
            runner: ProcessReleaseRunRunner(),
            releaseChecker: releaseChecker
        ).run(
            request: ReleaseRunRequest(
                projectRoot: projectRoot,
                blueprint: blueprintContext.blueprint,
                profile: profileContext.profile,
                environment: signingContext.environment,
                stage: stage,
                allowSigningWrite: allowSigningWrite
            )
        )

        let summary = signingContext.note.map { "\($0). \(result.summary)" } ?? result.summary
        switch format {
        case .human:
            renderHumanSuccess(summary: summary, artifacts: result.artifacts)
        case .json:
            printReleaseRunJSONPayload(
                status: "success",
                exitCode: Int(ExitCode.success.rawValue),
                summary: summary,
                stage: result.stage,
                failureCode: nil,
                failedStep: nil,
                ipaPath: result.ipaPath,
                artifacts: result.artifacts
            )
        }
        exit(ExitCode.success.rawValue)
    } catch let error as ReleaseRunEngineError {
        switch error {
        case .failed(let classification, let step, let summary, _, let artifacts):
            switch format {
            case .human:
                fputs("error: \(summary)\n", stderr)
            case .json:
                printReleaseRunJSONPayload(
                    status: "failed",
                    exitCode: Int(ExitCode.releaseRunFailed.rawValue),
                    summary: summary,
                    stage: stage,
                    failureCode: classification,
                    failedStep: step,
                    ipaPath: artifacts.first(where: { $0.hasSuffix(".ipa") }),
                    artifacts: artifacts
                )
            }
            exit(ExitCode.releaseRunFailed.rawValue)
        }
    } catch {
        fail(
            message: "\(error)",
            command: .releaseRun,
            format: format,
            exitCode: .releaseRunFailed
        )
    }
}
