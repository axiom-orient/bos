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

func printMetadataJSONPayload(
    status: String,
    exitCode: Int,
    summary: String,
    subcommand: MetadataSubcommand,
    directory: String,
    defaultLocale: String,
    locales: [String],
    diff: MetadataDiffReport?,
    validation: MetadataValidationReport?,
    pushedLocales: [String],
    skippedLocales: [String],
    failureCode: MetadataFailureCode?,
    artifacts: [String]
) {
    let payload = MetadataCommandOutput(
        command: BosCommand.metadata.rawValue,
        status: status,
        exitCode: exitCode,
        summary: summary,
        subcommand: subcommand.rawValue,
        directory: directory,
        defaultLocale: defaultLocale,
        locales: locales,
        hasChanges: diff?.hasChanges,
        changedFiles: diff?.changedFiles,
        missingLocales: diff?.missingLocales ?? validation?.missingLocales,
        extraFiles: diff?.extraFiles,
        valid: validation?.valid,
        missingRequiredFiles: validation?.missingRequiredFiles,
        emptyRequiredFiles: validation?.emptyRequiredFiles,
        pushedLocales: pushedLocales.isEmpty ? nil : pushedLocales,
        skippedLocales: skippedLocales.isEmpty ? nil : skippedLocales,
        failureCode: failureCode?.rawValue,
        artifacts: artifacts
    )
    do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        print(String(decoding: data, as: UTF8.self))
    } catch {
        fputs("error: failed to encode metadata JSON output\n", stderr)
    }
}

func printScreenshotsJSONPayload(
    status: String,
    exitCode: Int,
    summary: String,
    subcommand: ScreenshotSubcommand,
    planPath: String,
    defaultLocale: String,
    summaryReport: ScreenshotPlanSummary?,
    capturedShots: [String],
    failedShots: [String],
    outputDirectory: String?,
    composedFiles: [String],
    missingOutputs: [String],
    valid: Bool?,
    unexpectedFiles: [String],
    failureCode: ScreenshotFailureCode?,
    artifacts: [String]
) {
    let payload = ScreenshotsCommandOutput(
        command: BosCommand.screenshots.rawValue,
        status: status,
        exitCode: exitCode,
        summary: summary,
        subcommand: subcommand.rawValue,
        planPath: planPath,
        defaultLocale: defaultLocale,
        localeCount: summaryReport?.localeCount,
        deviceCount: summaryReport?.deviceCount,
        shotCount: summaryReport?.shotCount,
        capturedShots: capturedShots.isEmpty ? nil : capturedShots,
        failedShots: failedShots.isEmpty ? nil : failedShots,
        outputDirectory: outputDirectory,
        composedFiles: composedFiles.isEmpty ? nil : composedFiles,
        missingOutputs: missingOutputs.isEmpty ? nil : missingOutputs,
        valid: valid,
        unexpectedFiles: unexpectedFiles.isEmpty ? nil : unexpectedFiles,
        failureCode: failureCode?.rawValue,
        artifacts: artifacts
    )
    do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        print(String(decoding: data, as: UTF8.self))
    } catch {
        fputs("error: failed to encode screenshots JSON output\n", stderr)
    }
}

func printDeviceJSONPayload(
    status: String,
    exitCode: Int,
    summary: String,
    subcommand: DeviceSubcommand,
    devices: [DeviceRecord],
    targetDevice: String?,
    appPath: String?,
    bundleIdentifier: String?,
    logLines: [String],
    findings: [String],
    failureCode: DeviceFailureCode?,
    artifacts: [String]
) {
    let payload = DeviceCommandOutput(
        command: BosCommand.device.rawValue,
        status: status,
        exitCode: exitCode,
        summary: summary,
        subcommand: subcommand.rawValue,
        devices: devices.isEmpty ? nil : devices,
        targetDevice: targetDevice,
        appPath: appPath,
        bundleIdentifier: bundleIdentifier,
        logLines: logLines.isEmpty ? nil : logLines,
        findings: findings.isEmpty ? nil : findings,
        failureCode: failureCode?.rawValue,
        artifacts: artifacts
    )
    do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        print(String(decoding: data, as: UTF8.self))
    } catch {
        fputs("error: failed to encode device JSON output\n", stderr)
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
