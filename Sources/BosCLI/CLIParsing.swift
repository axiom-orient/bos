import Foundation
import BosCore

func printRootHelp() {
    let commandList = BosCommand.allCases
        .map { "  \($0.rawValue) - \($0.summary)" }
        .joined(separator: "\n")

    let help = """
    bos v1 (Swift CLI-only)

    Usage:
      bos <command> [options]
      bos <command> --help

    Commands:
    \(commandList)

    Global Flags:
      --project-root <path>
      --format human|json   (default: human)
      -h, --help

    Primary Path:
      bos doctor
      bos plan
      bos apply --mode init
      bos verify
      bos app-register
      bos release-init
      bos release-check
      bos release-run --stage beta
    """

    print(help)
}

func printCommandHelp(_ command: BosCommand) {
    let help = """
    Command: \(command.rawValue)
    Summary: \(command.summary)

    Usage:
      \(command.usage)
    """

    print(help)
}

struct ParsedOptions {
    var values: [String: String] = [:]
    var flags: Set<String> = []
    var missingValueFlags: [String] = []
    var unknownFlags: [String] = []
    var positional: [String] = []
}

func parseOptions(
    args: [String],
    valueFlags: Set<String>,
    booleanFlags: Set<String>
) -> ParsedOptions {
    var parsed = ParsedOptions()
    var index = 0
    while index < args.count {
        let token = args[index]
        if token.hasPrefix("--") {
            if valueFlags.contains(token) {
                let nextIndex = index + 1
                guard nextIndex < args.count, !args[nextIndex].hasPrefix("--") else {
                    parsed.missingValueFlags.append(token)
                    index += 1
                    continue
                }
                parsed.values[token] = args[nextIndex]
                index += 2
                continue
            }
            if booleanFlags.contains(token) {
                parsed.flags.insert(token)
                index += 1
                continue
            }
            parsed.unknownFlags.append(token)
            index += 1
            continue
        }

        parsed.positional.append(token)
        index += 1
    }
    return parsed
}

func assertOptionContract(
    parsed: ParsedOptions,
    command: BosCommand,
    format: OutputFormat
) {
    if !parsed.missingValueFlags.isEmpty {
        fail(
            message: "missing value for flag(s): \(parsed.missingValueFlags.joined(separator: ", "))",
            command: command,
            format: format
        )
    }
    if !parsed.unknownFlags.isEmpty {
        fail(
            message: "unknown flag(s): \(parsed.unknownFlags.joined(separator: ", "))",
            command: command,
            format: format
        )
    }
    if !parsed.positional.isEmpty {
        fail(
            message: "unexpected argument(s): \(parsed.positional.joined(separator: " "))",
            command: command,
            format: format
        )
    }
}

func parseOutputFormat(from args: [String]) -> OutputFormat {
    guard let index = args.firstIndex(of: "--format") else {
        return .human
    }
    let valueIndex = args.index(after: index)
    guard valueIndex < args.endIndex else {
        return .human
    }
    return OutputFormat(rawValue: args[valueIndex].lowercased()) ?? .human
}

func parseDoctorScope(
    raw: String?,
    command: BosCommand,
    format: OutputFormat
) -> DoctorScope {
    guard let raw else { return .core }
    guard let scope = DoctorScope(rawValue: raw) else {
        fail(
            message: "invalid --for '\(raw)'. expected one of: core, all, plan, apply, verify, metadata, screenshots, device, app-register, release-init, release-check, release-run",
            command: command,
            format: format
        )
    }
    return scope
}

func parseReleaseCheckMode(
    raw: String?,
    command: BosCommand,
    format: OutputFormat
) -> ReleaseCheckMode {
    guard let raw else { return .readonlyCerts }
    guard let mode = ReleaseCheckMode(rawValue: raw) else {
        fail(
            message: "invalid --mode '\(raw)'. expected one of: connectivity, readonly-certs, sync-certs",
            command: command,
            format: format
        )
    }
    return mode
}

func parseReleaseRunStage(
    raw: String?,
    command: BosCommand,
    format: OutputFormat
) -> ReleaseRunStage {
    guard let raw else { return .build }
    guard let stage = ReleaseRunStage(rawValue: raw) else {
        fail(
            message: "invalid --stage '\(raw)'. expected one of: build, beta, release, submit",
            command: command,
            format: format
        )
    }
    return stage
}
