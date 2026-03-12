import Foundation
import BosCore

func resolveBrewExecutable() -> String? {
    if commandExists("brew") {
        return "brew"
    }

    let candidates = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
    let fm = FileManager.default
    return candidates.first { fm.isExecutableFile(atPath: $0) }
}

func runInstallAttempt(
    tool: String,
    commandDescription: String,
    command: [String],
    workingDirectory: URL
) -> DoctorInstallAttempt {
    do {
        let result = try runProcess(command: command, workingDirectory: workingDirectory)
        return DoctorInstallAttempt(
            tool: tool,
            command: commandDescription,
            status: result.status == 0 ? "success" : "failed",
            exitCode: result.status,
            stderr: result.stderr
        )
    } catch {
        return DoctorInstallAttempt(
            tool: tool,
            command: commandDescription,
            status: "failed",
            exitCode: 1,
            stderr: "\(error)"
        )
    }
}

func installToolWithBrew(tool: String, projectRoot: URL) -> [DoctorInstallAttempt] {
    var attempts: [DoctorInstallAttempt] = []

    if let brew = resolveBrewExecutable() {
        attempts.append(
            runInstallAttempt(
                tool: tool,
                commandDescription: "brew install \(tool)",
                command: [brew, "install", tool],
                workingDirectory: projectRoot
            )
        )
        return attempts
    }

    let brewInstallScript = #"/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)""#
    let bootstrap = runInstallAttempt(
        tool: tool,
        commandDescription: brewInstallScript,
        command: ["/bin/bash", "-lc", brewInstallScript],
        workingDirectory: projectRoot
    )
    attempts.append(bootstrap)

    guard bootstrap.status == "success" else {
        return attempts
    }

    guard let brew = resolveBrewExecutable() else {
        attempts.append(
            DoctorInstallAttempt(
                tool: tool,
                command: "brew install \(tool)",
                status: "skipped-no-runner",
                exitCode: 127,
                stderr: "brew installation finished but brew executable is not on PATH"
            )
        )
        return attempts
    }

    attempts.append(
        runInstallAttempt(
            tool: tool,
            commandDescription: "brew install \(tool)",
            command: [brew, "install", tool],
            workingDirectory: projectRoot
        )
    )

    return attempts
}

func installFastlaneWithBrew(projectRoot: URL) -> [DoctorInstallAttempt] {
    installToolWithBrew(tool: "fastlane", projectRoot: projectRoot)
}

func installTuistWithBrew(projectRoot: URL) -> [DoctorInstallAttempt] {
    installToolWithBrew(tool: "tuist", projectRoot: projectRoot)
}

func detectXcodeSelectPath() -> String {
    guard let result = try? runProcess(command: ["xcode-select", "-p"]),
          result.status == 0 else { return "" }
    return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
}

func detectToolchain(lock: ToolchainLock) throws -> DetectedToolchain {
    let swift = detectVersion(command: ["swift", "--version"])
    let tuist = detectVersion(command: ["tuist", "version"])
    let fastlane = detectVersion(command: ["fastlane", "--version"])
    let git = detectVersion(command: ["git", "--version"])
    let env = ProcessInfo.processInfo.environment
    let tma = try ToolchainLock.TMAPluginRef(
        type: env["TMA_PLUGIN_REF_TYPE"] ?? lock.tmaPluginRef.type,
        value: env["TMA_PLUGIN_REF_VALUE"] ?? lock.tmaPluginRef.value
    )
    return DetectedToolchain(
        swift: swift,
        tuist: tuist,
        fastlane: fastlane,
        tmaPluginRef: tma,
        xcodeSelectPath: detectXcodeSelectPath(),
        brewPath: resolveBrewExecutable() ?? "",
        gitVersion: git
    )
}

func renderDoctorHuman(
    scope: DoctorScope,
    result: DoctorResult,
    installAttempts: [DoctorInstallAttempt],
    note: String?
) {
    if let note {
        print(note)
    }
    print(result.summary)
    print("scope: \(scope.rawValue)")

    let findings = result.findings
    if findings.isEmpty {
        print("findings: none")
    } else {
        print("findings:")
        for finding in findings {
            print("- \(finding.tool) [\(finding.severity.rawValue)/\(finding.status.rawValue)] expected=\(finding.expectedRule) actual=\(finding.actualVersion)")
            print("  action: \(finding.action)")
            if !finding.installCommands.isEmpty {
                print("  install:")
                for install in finding.installCommands {
                    print("  - \(install)")
                }
            }
        }
    }

    if !installAttempts.isEmpty {
        print("install-attempts:")
        for attempt in installAttempts {
            let detail = attempt.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if detail.isEmpty {
                print("- \(attempt.tool): \(attempt.status) (\(attempt.command))")
            } else {
                print("- \(attempt.tool): \(attempt.status) (\(attempt.command)) stderr=\(detail)")
            }
        }
    }

    if !result.artifacts.isEmpty {
        print("artifacts:")
        for artifact in result.artifacts {
            print("- \(artifact)")
        }
    }
}

func performDoctorAutoInstall(
    findings: [DoctorFinding],
    projectRoot: URL
) -> [DoctorInstallAttempt] {
    var attempts: [DoctorInstallAttempt] = []

    let missingTools = findings
        .filter { $0.severity == .required && $0.status != .installed && $0.tool != "swift" }
        .sorted { $0.tool < $1.tool }

    for finding in missingTools {
        if finding.tool == "fastlane" {
            attempts.append(contentsOf: installFastlaneWithBrew(projectRoot: projectRoot))
            continue
        }
        if finding.tool == "tuist" {
            attempts.append(contentsOf: installTuistWithBrew(projectRoot: projectRoot))
            continue
        }

        guard !finding.installCommands.isEmpty else {
            continue
        }

        var attempted = false
        for rawCommand in finding.installCommands {
            let tokens = tokenizeCommandLine(rawCommand)
            guard let executable = tokens.first else { continue }
            guard executable != "sudo" else { continue }
            guard commandExists(executable) else { continue }

            attempted = true
            do {
                let result = try runProcess(command: tokens, workingDirectory: projectRoot)
                let status = result.status == 0 ? "success" : "failed"
                attempts.append(
                    DoctorInstallAttempt(
                        tool: finding.tool,
                        command: rawCommand,
                        status: status,
                        exitCode: result.status,
                        stderr: result.stderr
                    )
                )
                if result.status == 0 {
                    break
                }
            } catch {
                attempts.append(
                    DoctorInstallAttempt(
                        tool: finding.tool,
                        command: rawCommand,
                        status: "failed",
                        exitCode: 1,
                        stderr: "\(error)"
                    )
                )
            }
        }

        if !attempted {
            attempts.append(
                DoctorInstallAttempt(
                    tool: finding.tool,
                    command: finding.installCommands.joined(separator: " || "),
                    status: "skipped-no-runner",
                    exitCode: 127,
                    stderr: "no available installer command found in current environment"
                )
            )
        }
    }

    return attempts
}

func doctorRequiresSigningEnvironment(scope: DoctorScope) -> Bool {
    scope.commands.contains(ToolchainLock.commandAppRegister)
        || scope.commands.contains(ToolchainLock.commandReleaseInit)
        || scope.commands.contains(ToolchainLock.commandReleaseCheck)
        || scope.commands.contains(ToolchainLock.commandReleaseRun)
}

func resolveDoctorSigningEnvironment(
    scope: DoctorScope,
    projectRoot: URL,
    processEnvironment: [String: String],
    format: OutputFormat
) -> ([String: String], String?) {
    guard doctorRequiresSigningEnvironment(scope: scope) else {
        return (processEnvironment, nil)
    }

    let profileContext = loadProfileContext(
        raw: nil,
        projectRoot: projectRoot,
        command: .doctor,
        format: format
    )

    do {
        let resolved = try resolveSigningEnvironment(
            projectRoot: projectRoot,
            profile: profileContext.profile,
            processEnvironment: processEnvironment
        )
        return (resolved.environment, resolved.note)
    } catch {
        fail(
            message: signingEnvironmentLoadErrorMessage(error, projectRoot: projectRoot),
            command: .doctor,
            format: format,
            exitCode: .doctorFailed
        )
    }
}

func resolveDoctorToolchainLock(
    projectRoot: URL,
    processEnvironment: [String: String],
    format: OutputFormat
) -> (ToolchainLock, String?) {
    if let existingLockPath = resolveToolchainLockPath(projectRoot: projectRoot) {
        do {
            return (try decodeToolchainLock(at: existingLockPath), nil)
        } catch {
            fail(message: "\(error)", command: .doctor, format: format)
        }
    }

    let tma = try? ToolchainLock.TMAPluginRef(
        type: processEnvironment["TMA_PLUGIN_REF_TYPE"] ?? "git-sha",
        value: processEnvironment["TMA_PLUGIN_REF_VALUE"] ?? "unknown"
    )
    guard let tma else {
        fail(
            message: "failed to initialize tma plugin reference from environment",
            command: .doctor,
            format: format
        )
    }

    do {
        let initialLock = try ToolchainLock.defaultPolicy(tmaPluginRef: tma)
        let encoded = try encodeYAML(initialLock)
        let destination = preferredToolchainLockPath(projectRoot: projectRoot)
        try writeTextFile(encoded, to: destination)
        let initializedLock = try decodeToolchainLock(at: destination)
        let note = "Initialized toolchain lock at \(destination.path(percentEncoded: false))"
        return (initializedLock, note)
    } catch {
        fail(message: "failed to initialize toolchain lock: \(error)", command: .doctor, format: format)
    }
}
