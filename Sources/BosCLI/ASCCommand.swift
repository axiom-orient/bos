import Foundation
import BosCore

func runASC(args: [String]) {
    guard !args.isEmpty else {
        printCommandHelp(.asc)
        exit(ExitCode.contractValidationError.rawValue)
    }

    let projectRoot = currentWorkingDirectoryURL()
    let profileContext = loadProfileContext(
        raw: nil,
        projectRoot: projectRoot,
        command: .asc,
        format: .human
    )
    let signingContext = loadSigningContext(
        projectRoot: projectRoot,
        profile: profileContext.profile,
        command: .asc,
        format: .human,
        exitCode: .ascFailed
    )

    var resolvedAppStoreAppId: String?
    do {
        let resolution = try ASCAppStoreAppResolver().resolve(
            profile: profileContext.profile,
            projectRoot: projectRoot,
            environment: signingContext.environment
        )
        resolvedAppStoreAppId = resolution.appStoreAppId
        if resolution.source == .lookup {
            try writeTextFile(encodeYAML(resolution.updatedProfile), to: profileContext.path)
        }
    } catch {
        // Raw asc forwarding should stay available even when BOS cannot pre-resolve an app ID.
        resolvedAppStoreAppId = profileContext.profile.configuredAppStoreAppId
    }

    let backend = ASCBackend(
        executable: ProcessInfo.processInfo.environment["BOS_ASC_EXECUTABLE"] ?? "asc"
    )

    do {
        let result = try backend.run(
            arguments: args,
            projectRoot: projectRoot,
            environment: signingContext.environment,
            appStoreAppId: resolvedAppStoreAppId
        )
        let curatedEnvironment = try backend.curatedEnvironment(
            projectRoot: projectRoot,
            environment: signingContext.environment,
            appStoreAppId: resolvedAppStoreAppId
        )
        let artifacts = try writeASCArtifacts(
            projectRoot: projectRoot,
            arguments: args,
            result: result,
            environment: curatedEnvironment,
            resolvedAppStoreAppId: resolvedAppStoreAppId
        )

        if !result.stdout.isEmpty {
            FileHandle.standardOutput.write(Data(result.stdout.utf8))
        }
        if !result.stderr.isEmpty {
            FileHandle.standardError.write(Data(result.stderr.utf8))
        }
        _ = artifacts
        exit(result.exitCode)
    } catch let error as ASCBackendError {
        switch error {
        case .invalidEnvironment(let missingKeys, let invalidIssues):
            let parts = [
                missingKeys.isEmpty ? nil : "missing=\(missingKeys.joined(separator: ","))",
                invalidIssues.isEmpty ? nil : "invalid=\(invalidIssues.joined(separator: ","))"
            ].compactMap { $0 }
            fail(
                message: "invalid App Store Connect environment for asc bridge: \(parts.joined(separator: " "))",
                command: .asc,
                format: .human,
                exitCode: .ascFailed
            )
        }
    } catch {
        fail(
            message: "asc bridge failed: \(error)",
            command: .asc,
            format: .human,
            exitCode: .ascFailed
        )
    }
}

private func writeASCArtifacts(
    projectRoot: URL,
    arguments: [String],
    result: ASCCommandResult,
    environment: [String: String],
    resolvedAppStoreAppId: String?
) throws -> [String] {
    struct ArtifactPayload: Codable {
        let command: String
        let forwardedArguments: [String]
        let exitCode: Int32
        let resolvedAppStoreAppId: String?
        let artifacts: [String]
    }

    let stamp = ascTimestamp()
    let bundle = try AdapterArtifacts.makeBundle(command: "asc", projectRoot: projectRoot, stamp: stamp)
    let artifacts = bundle.artifacts

    let sanitizedStdout = ASCBackend.sanitizeSecrets(result.stdout, environment: environment)
    let sanitizedStderr = ASCBackend.sanitizeSecrets(result.stderr, environment: environment)
    let stdout = [
        "# bos asc",
        "args=\(arguments.joined(separator: " "))",
        "exitCode=\(result.exitCode)",
        "resolvedAppStoreAppId=\(resolvedAppStoreAppId ?? "-")",
        ""
    ].joined(separator: "\n")

    _ = try AdapterArtifacts.write(
        bundle: bundle,
        envelope: AdapterRunEnvelope(
            command: "asc",
            status: result.exitCode == 0 ? "success" : "failed",
            exitCode: Int(result.exitCode),
            summary: "asc bridge forwarded \(arguments.joined(separator: " "))",
            payload: ArtifactPayload(
                command: "asc",
                forwardedArguments: arguments,
                exitCode: result.exitCode,
                resolvedAppStoreAppId: resolvedAppStoreAppId,
                artifacts: artifacts
            )
        ),
        stdout: [stdout, sanitizedStdout].filter { !$0.isEmpty }.joined(separator: "\n"),
        stderr: sanitizedStderr
    )

    return artifacts
}

private func ascTimestamp() -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyyMMddHHmmss"
    return formatter.string(from: .now)
}
