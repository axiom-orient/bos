import Foundation
import BosCore

func renderHumanSuccess(summary: String, artifacts: [String]) {
    print(summary)
    if !artifacts.isEmpty {
        print("artifacts:")
        for artifact in artifacts {
            print("- \(artifact)")
        }
    }
}

func printJSONPayload(
    command: String,
    status: String,
    exitCode: Int,
    summary: String,
    artifacts: [String] = []
) {
    let payload = CommandOutput(
        command: command,
        status: status,
        exitCode: exitCode,
        summary: summary,
        artifacts: artifacts
    )
    do {
        print(try payload.toJSONString())
    } catch {
        fputs("error: failed to encode JSON output\n", stderr)
    }
}

func printDoctorJSONPayload(
    status: String,
    exitCode: Int,
    summary: String,
    scope: String,
    findings: [DoctorFinding],
    installAttempts: [DoctorInstallAttempt],
    artifacts: [String]
) {
    let payload = DoctorCommandOutput(
        command: BosCommand.doctor.rawValue,
        status: status,
        exitCode: exitCode,
        summary: summary,
        scope: scope,
        findings: findings,
        installAttempts: installAttempts,
        artifacts: artifacts
    )
    do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        print(String(decoding: data, as: UTF8.self))
    } catch {
        fputs("error: failed to encode doctor JSON output\n", stderr)
    }
}

func printReleaseCheckJSONPayload(
    status: String,
    exitCode: Int,
    summary: String,
    mode: ReleaseCheckMode,
    failureCode: ReleaseCheckFailureCode?,
    failedStep: ReleaseCheckStep?,
    artifacts: [String]
) {
    let payload = ReleaseCheckCommandOutput(
        command: BosCommand.releaseCheck.rawValue,
        status: status,
        exitCode: exitCode,
        summary: summary,
        mode: mode.rawValue,
        failureCode: failureCode?.rawValue,
        failedStep: failedStep?.rawValue,
        artifacts: artifacts
    )
    do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        print(String(decoding: data, as: UTF8.self))
    } catch {
        fputs("error: failed to encode release-check JSON output\n", stderr)
    }
}

func printReleaseRunJSONPayload(
    status: String,
    exitCode: Int,
    summary: String,
    stage: ReleaseRunStage,
    failureCode: ReleaseRunFailureCode?,
    failedStep: ReleaseRunStep?,
    ipaPath: String?,
    artifacts: [String]
) {
    let payload = ReleaseRunCommandOutput(
        command: BosCommand.releaseRun.rawValue,
        status: status,
        exitCode: exitCode,
        summary: summary,
        stage: stage.rawValue,
        failureCode: failureCode?.rawValue,
        failedStep: failedStep?.rawValue,
        ipaPath: ipaPath,
        artifacts: artifacts
    )
    do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        print(String(decoding: data, as: UTF8.self))
    } catch {
        fputs("error: failed to encode release-run JSON output\n", stderr)
    }
}

func printAppRegisterJSONPayload(
    status: String,
    exitCode: Int,
    summary: String,
    metadata: AppRegistrationResolvedMetadata?,
    appStoreAppId: String?,
    bundleIdStatus: AppRegistrationResourceStatus?,
    appStatus: AppRegistrationResourceStatus?,
    artifacts: [String]
) {
    let payload = AppRegisterCommandOutput(
        command: BosCommand.appRegister.rawValue,
        status: status,
        exitCode: exitCode,
        summary: summary,
        appIdentifier: metadata?.appIdentifier,
        appName: metadata?.appName,
        sku: metadata?.sku,
        primaryLanguage: metadata?.primaryLanguage,
        appStoreAppId: appStoreAppId,
        bundleIdStatus: bundleIdStatus?.rawValue,
        appStatus: appStatus?.rawValue,
        artifacts: artifacts
    )
    do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        print(String(decoding: data, as: UTF8.self))
    } catch {
        fputs("error: failed to encode app-register JSON output\n", stderr)
    }
}

func fail(
    message: String,
    command: BosCommand? = nil,
    format: OutputFormat = .human,
    exitCode: ExitCode = .contractValidationError
) -> Never {
    switch format {
    case .human:
        fputs("error: \(message)\n", stderr)
    case .json:
        printJSONPayload(
            command: command?.rawValue ?? "bos",
            status: "failed",
            exitCode: Int(exitCode.rawValue),
            summary: message
        )
    }
    exit(exitCode.rawValue)
}
