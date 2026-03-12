import Foundation
import BosCore

func runDoctor(args: [String], format: OutputFormat) {
    let parsed = parseOptions(
        args: args,
        valueFlags: ["--project-root", "--for", "--format"],
        booleanFlags: []
    )
    assertOptionContract(parsed: parsed, command: .doctor, format: format)

    let projectRoot = resolveProjectRoot(from: parsed)
    let scope = parseDoctorScope(raw: parsed.values["--for"], command: .doctor, format: format)
    let processEnvironment = ProcessInfo.processInfo.environment
    let autoInstallEnabled = !["0", "false", "no"].contains(
        processEnvironment["BOS_AUTO_INSTALL"]?.lowercased() ?? ""
    )
    let (signingEnvironment, signingNote) = resolveDoctorSigningEnvironment(
        scope: scope,
        projectRoot: projectRoot,
        processEnvironment: processEnvironment,
        format: format
    )
    let (lock, lockNote) = resolveDoctorToolchainLock(
        projectRoot: projectRoot,
        processEnvironment: processEnvironment,
        format: format
    )

    let initialDetected: DetectedToolchain
    do {
        initialDetected = try detectToolchain(lock: lock)
    } catch {
        fail(message: "\(error)", command: .doctor, format: format)
    }

    var result: DoctorResult
    do {
        result = try DoctorEngine().check(
            request: DoctorRequest(
                projectRoot: projectRoot,
                lock: lock,
                detected: initialDetected,
                checkCommands: scope.commands,
                environment: signingEnvironment
            )
        )
    } catch {
        fail(message: "\(error)", command: .doctor, format: format)
    }

    let installAttempts = autoInstallEnabled
        ? performDoctorAutoInstall(findings: result.findings, projectRoot: projectRoot)
        : []
    if !installAttempts.isEmpty {
        do {
            let detectedAfterInstall = try detectToolchain(lock: lock)
            result = try DoctorEngine().check(
                request: DoctorRequest(
                    projectRoot: projectRoot,
                    lock: lock,
                    detected: detectedAfterInstall,
                    checkCommands: scope.commands,
                    environment: signingEnvironment
                )
            )
        } catch {
            fail(message: "\(error)", command: .doctor, format: format)
        }
    }

    let notes = [signingNote, lockNote].compactMap { $0 }
    let summary = notes.isEmpty ? result.summary : "\(notes.joined(separator: ". ")). \(result.summary)"
    let humanNote = notes.isEmpty ? nil : notes.joined(separator: ". ")

    switch format {
    case .human:
        renderDoctorHuman(scope: scope, result: result, installAttempts: installAttempts, note: humanNote)
    case .json:
        printDoctorJSONPayload(
            status: result.status,
            exitCode: result.exitCode,
            summary: summary,
            scope: scope.rawValue,
            findings: result.findings,
            installAttempts: installAttempts,
            artifacts: result.artifacts
        )
    }

    if result.exitCode == 0 {
        exit(ExitCode.success.rawValue)
    } else {
        exit(ExitCode.doctorFailed.rawValue)
    }
}
