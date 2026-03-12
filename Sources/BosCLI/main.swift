import Foundation

func run() {
    let args = Array(CommandLine.arguments.dropFirst())
    let outputFormat = parseOutputFormat(from: args)

    guard let first = args.first else {
        printRootHelp()
        exit(ExitCode.success.rawValue)
    }

    if first == "-h" || first == "--help" || first == "help" {
        if args.count > 1, let command = BosCommand(rawValue: args[1]) {
            printCommandHelp(command)
        } else {
            printRootHelp()
        }
        exit(ExitCode.success.rawValue)
    }

    guard let command = BosCommand(rawValue: first) else {
        fail(message: "unknown command '\(first)'", format: outputFormat)
    }

    let rest = Array(args.dropFirst())
    if rest.contains("-h") || rest.contains("--help") {
        printCommandHelp(command)
        exit(ExitCode.success.rawValue)
    }

    switch command {
    case .doctor:
        runDoctor(args: rest, format: outputFormat)
    case .plan:
        runPlan(args: rest, format: outputFormat)
    case .apply:
        runApply(args: rest, format: outputFormat)
    case .verify:
        runVerify(args: rest, format: outputFormat)
    case .appRegister:
        runAppRegister(args: rest, format: outputFormat)
    case .releaseInit:
        runReleaseInit(args: rest, format: outputFormat)
    case .releaseCheck:
        runReleaseCheck(args: rest, format: outputFormat)
    case .releaseRun:
        runReleaseRun(args: rest, format: outputFormat)
    }
}

run()
