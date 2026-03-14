import Foundation
import BosCore

func runDevice(args: [String], format: OutputFormat) {
    guard let rawSubcommand = args.first, let subcommand = DeviceSubcommand(rawValue: rawSubcommand) else {
        fail(
            message: "device requires one of: list, register, install, launch, logs, doctor",
            command: .device,
            format: format
        )
    }

    let parsed = parseOptions(
        args: Array(args.dropFirst()),
        valueFlags: ["--project-root", "--device-id", "--name", "--app", "--bundle-id", "--format"],
        booleanFlags: []
    )
    assertOptionContract(parsed: parsed, command: .device, format: format)

    let projectRoot = resolveProjectRoot(from: parsed)
    let engine = DeviceEngine()

    do {
        let result = try engine.run(
            request: DeviceRequest(
                projectRoot: projectRoot,
                subcommand: subcommand,
                deviceID: parsed.values["--device-id"],
                name: parsed.values["--name"],
                appPath: parsed.values["--app"],
                bundleIdentifier: parsed.values["--bundle-id"]
            )
        )
        switch format {
        case .human:
            renderHumanSuccess(summary: result.summary, artifacts: result.artifacts)
        case .json:
            printDeviceJSONPayload(
                status: "success",
                exitCode: Int(ExitCode.success.rawValue),
                summary: result.summary,
                subcommand: subcommand,
                devices: result.devices,
                targetDevice: result.targetDevice,
                appPath: result.appPath,
                bundleIdentifier: result.bundleIdentifier,
                logLines: result.logLines,
                findings: result.findings,
                failureCode: nil,
                artifacts: result.artifacts
            )
        }
        exit(ExitCode.success.rawValue)
    } catch let error as DeviceEngineError {
        let payload: (
            summary: String,
            failureCode: DeviceFailureCode,
            artifacts: [String],
            devices: [DeviceRecord],
            targetDevice: String?,
            appPath: String?,
            bundleIdentifier: String?,
            logLines: [String],
            findings: [String]
        )
        switch error {
        case .failed(
            let classification,
            let summary,
            let artifacts,
            let devices,
            let targetDevice,
            let appPath,
            let bundleIdentifier,
            let logLines,
            let findings
        ):
            payload = (
                summary,
                classification,
                artifacts,
                devices,
                targetDevice,
                appPath,
                bundleIdentifier,
                logLines,
                findings
            )
        }

        switch format {
        case .human:
            fputs("error: \(payload.summary)\n", stderr)
        case .json:
            printDeviceJSONPayload(
                status: "failed",
                exitCode: Int(ExitCode.deviceFailed.rawValue),
                summary: payload.summary,
                subcommand: subcommand,
                devices: payload.devices,
                targetDevice: payload.targetDevice,
                appPath: payload.appPath,
                bundleIdentifier: payload.bundleIdentifier,
                logLines: payload.logLines,
                findings: payload.findings,
                failureCode: payload.failureCode,
                artifacts: payload.artifacts
            )
        }
        exit(ExitCode.deviceFailed.rawValue)
    } catch {
        fail(
            message: "device \(subcommand.rawValue) failed: \(error)",
            command: .device,
            format: format,
            exitCode: .deviceFailed
        )
    }
}
