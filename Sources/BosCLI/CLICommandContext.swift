import Foundation
import BosCore

struct CLIProfileContext {
    let path: URL
    let profile: Profile
}

struct CLIBlueprintContext {
    let path: URL
    let blueprint: Blueprint
}

struct CLISigningContext {
    let environment: [String: String]
    let note: String?
}

func resolveProjectRoot(from parsed: ParsedOptions) -> URL {
    resolvePath(parsed.values["--project-root"] ?? ".", base: currentWorkingDirectoryURL())
}

func loadProfileContext(
    raw: String?,
    projectRoot: URL,
    command: BosCommand,
    format: OutputFormat
) -> CLIProfileContext {
    let path = resolveProfilePathOrFail(
        raw: raw,
        projectRoot: projectRoot,
        command: command,
        format: format
    )
    do {
        let profile = try decodeYAMLOrJSON(Profile.self, at: path)
        return CLIProfileContext(path: path, profile: profile)
    } catch {
        fail(message: "\(error)", command: command, format: format)
    }
}

func loadBlueprintContext(
    raw: String?,
    projectRoot: URL,
    command: BosCommand,
    format: OutputFormat
) -> CLIBlueprintContext {
    let path = resolveBlueprintPathOrFail(
        raw: raw,
        projectRoot: projectRoot,
        command: command,
        format: format
    )
    do {
        let blueprint = try decodeYAMLOrJSON(Blueprint.self, at: path)
        return CLIBlueprintContext(path: path, blueprint: blueprint)
    } catch {
        fail(message: "\(error)", command: command, format: format)
    }
}

func loadOptionalBlueprint(
    raw: String?,
    projectRoot: URL,
    command: BosCommand,
    format: OutputFormat
) -> Blueprint? {
    do {
        guard let path = resolveOptionalBlueprintPath(raw: raw, projectRoot: projectRoot) else {
            return nil
        }
        return try decodeYAMLOrJSON(Blueprint.self, at: path)
    } catch {
        fail(message: "\(error)", command: command, format: format)
    }
}

func loadSigningContext(
    projectRoot: URL,
    profile: Profile? = nil,
    command: BosCommand,
    format: OutputFormat,
    exitCode: ExitCode
) -> CLISigningContext {
    do {
        let resolved = try resolveSigningEnvironment(
            projectRoot: projectRoot,
            profile: profile,
            processEnvironment: ProcessInfo.processInfo.environment
        )
        return CLISigningContext(environment: resolved.environment, note: resolved.note)
    } catch {
        fail(
            message: signingEnvironmentLoadErrorMessage(error, projectRoot: projectRoot),
            command: command,
            format: format,
            exitCode: exitCode
        )
    }
}
