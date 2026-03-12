import Foundation
import BosCore

func runVerify(args: [String], format: OutputFormat) {
    let parsed = parseOptions(
        args: args,
        valueFlags: ["--project-root", "--profile", "--format"],
        booleanFlags: []
    )
    assertOptionContract(parsed: parsed, command: .verify, format: format)

    let projectRoot = resolveProjectRoot(from: parsed)
    let profileContext = loadProfileContext(
        raw: parsed.values["--profile"],
        projectRoot: projectRoot,
        command: .verify,
        format: format
    )

    do {
        let engine = VerifyEngine(runner: ProcessVerifyRunner())
        let result = try engine.verify(
            request: VerifyRequest(
                projectRoot: projectRoot,
                profile: profileContext.profile
            )
        )
        switch format {
        case .human:
            renderHumanSuccess(summary: result.summary, artifacts: result.artifacts)
        case .json:
            printJSONPayload(
                command: BosCommand.verify.rawValue,
                status: "success",
                exitCode: Int(ExitCode.success.rawValue),
                summary: result.summary,
                artifacts: result.artifacts
            )
        }
        exit(ExitCode.success.rawValue)
    } catch let error as VerifyEngineError {
        switch error {
        case .commandFailed(let classification, let step, _, _):
            let summary = "verify failed at \(step.rawValue) (\(classification.rawValue))"
            switch format {
            case .human:
                fputs("error: \(summary)\n", stderr)
            case .json:
                printJSONPayload(
                    command: BosCommand.verify.rawValue,
                    status: "failed",
                    exitCode: Int(ExitCode.verifyFailed.rawValue),
                    summary: summary
                )
            }
            exit(ExitCode.verifyFailed.rawValue)
        }
    } catch {
        fail(message: "\(error)", command: .verify, format: format)
    }
}
