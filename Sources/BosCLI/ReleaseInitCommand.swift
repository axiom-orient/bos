import Foundation
import BosCore

func runReleaseInit(args: [String], format: OutputFormat) {
    let parsed = parseOptions(
        args: args,
        valueFlags: ["--project-root", "--blueprint", "--profile", "--format"],
        booleanFlags: []
    )
    assertOptionContract(parsed: parsed, command: .releaseInit, format: format)

    let projectRoot = resolveProjectRoot(from: parsed)
    let blueprintContext = loadBlueprintContext(
        raw: parsed.values["--blueprint"],
        projectRoot: projectRoot,
        command: .releaseInit,
        format: format
    )
    let profileContext = loadProfileContext(
        raw: parsed.values["--profile"],
        projectRoot: projectRoot,
        command: .releaseInit,
        format: format
    )
    let signingContext = loadSigningContext(
        projectRoot: projectRoot,
        profile: profileContext.profile,
        command: .releaseInit,
        format: format,
        exitCode: .releaseInitFailed
    )

    do {
        let result = try ReleaseInitEngine().releaseInit(
            request: ReleaseInitRequest(
                projectRoot: projectRoot,
                blueprint: blueprintContext.blueprint,
                profile: profileContext.profile,
                environment: signingContext.environment
            )
        )
        let summaryBase = "release-init completed with \(result.generatedFiles.count) generated files"
        let summary: String
        if let note = signingContext.note {
            summary = "\(note). \(summaryBase)"
        } else {
            summary = summaryBase
        }
        switch format {
        case .human:
            renderHumanSuccess(summary: summary, artifacts: result.artifacts + result.generatedFiles)
        case .json:
            printJSONPayload(
                command: BosCommand.releaseInit.rawValue,
                status: "success",
                exitCode: Int(ExitCode.success.rawValue),
                summary: summary,
                artifacts: result.artifacts + result.generatedFiles
            )
        }
        exit(ExitCode.success.rawValue)
    } catch let error as ReleaseInitEngineError {
        let summary: String
        switch error {
        case .missingRequiredEnvironment(let keys):
            let path = defaultSigningEnvironmentPath(projectRoot: projectRoot).path(percentEncoded: false)
            summary = "missing required environment: \(keys.joined(separator: ", ")). set values in \(path) or shell environment"
        case .invalidEnvironmentFormat(let details):
            let path = defaultSigningEnvironmentPath(projectRoot: projectRoot).path(percentEncoded: false)
            summary = "invalid environment format: \(details.joined(separator: ", ")). check \(path)"
        case .laneParseFailed(let path):
            summary = "failed to parse fastlane lanes from \(path)"
        }
        switch format {
        case .human:
            fputs("error: \(summary)\n", stderr)
        case .json:
            printJSONPayload(
                command: BosCommand.releaseInit.rawValue,
                status: "failed",
                exitCode: Int(ExitCode.releaseInitFailed.rawValue),
                summary: summary
            )
        }
        exit(ExitCode.releaseInitFailed.rawValue)
    } catch {
        fail(message: "\(error)", command: .releaseInit, format: format)
    }
}
