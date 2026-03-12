import Foundation
import BosCore

func runAppRegister(args: [String], format: OutputFormat) {
    let parsed = parseOptions(
        args: args,
        valueFlags: [
            "--project-root",
            "--profile",
            "--blueprint",
            "--company-name",
            "--app-name",
            "--app-identifier",
            "--apple-team-id",
            "--primary-language",
            "--sku",
            "--match-git-url",
            "--format"
        ],
        booleanFlags: []
    )
    assertOptionContract(parsed: parsed, command: .appRegister, format: format)

    let projectRoot = resolveProjectRoot(from: parsed)
    let profileContext = loadProfileContext(
        raw: parsed.values["--profile"],
        projectRoot: projectRoot,
        command: .appRegister,
        format: format
    )
    let blueprint = loadOptionalBlueprint(
        raw: parsed.values["--blueprint"],
        projectRoot: projectRoot,
        command: .appRegister,
        format: format
    )
    let signingContext = loadSigningContext(
        projectRoot: projectRoot,
        command: .appRegister,
        format: format,
        exitCode: .appRegisterFailed
    )

    do {
        let overrides = AppRegistrationOverrides(
            companyName: parsed.values["--company-name"],
            appName: parsed.values["--app-name"],
            appIdentifier: parsed.values["--app-identifier"],
            appleTeamId: parsed.values["--apple-team-id"],
            primaryLanguage: parsed.values["--primary-language"],
            sku: parsed.values["--sku"],
            matchGitURL: parsed.values["--match-git-url"]
        )
        let result = try AppRegistrationEngine().register(
            request: AppRegistrationRequest(
                projectRoot: projectRoot,
                profile: profileContext.profile,
                blueprint: blueprint,
                overrides: overrides,
                environment: signingContext.environment
            )
        )

        let encodedProfile = try encodeYAML(result.syncedProfile)
        try writeTextFile(encodedProfile, to: profileContext.path)

        let summaryBase = "app-register completed (\(result.bundleIdStatus.rawValue), \(result.appStatus.rawValue))"
        let summary = signingContext.note.map { "\($0). \(summaryBase)" } ?? summaryBase
        let artifacts = result.artifacts + [profileContext.path.path(percentEncoded: false)]
        switch format {
        case .human:
            renderHumanSuccess(summary: summary, artifacts: artifacts)
        case .json:
            printAppRegisterJSONPayload(
                status: "success",
                exitCode: Int(ExitCode.success.rawValue),
                summary: summary,
                metadata: result.metadata,
                bundleIdStatus: result.bundleIdStatus,
                appStatus: result.appStatus,
                artifacts: artifacts
            )
        }
        exit(ExitCode.success.rawValue)
    } catch let error as AppRegistrationEngineError {
        let summary: String
        switch error {
        case .missingRequiredFields(let fields):
            summary = "missing required fields: \(fields.joined(separator: ", ")). add them to `.bos/config/profile.yaml` or pass flags."
        case .invalidValue(let field, let reason):
            summary = "\(field): \(reason)"
        case .invalidEnvironment(let missingKeys, let invalidIssues):
            let path = defaultSigningEnvironmentPath(projectRoot: projectRoot).path(percentEncoded: false)
            let parts = [
                missingKeys.isEmpty ? nil : "missing=\(missingKeys.joined(separator: ","))",
                invalidIssues.isEmpty ? nil : "invalid=\(invalidIssues.joined(separator: ","))"
            ].compactMap { $0 }
            summary = "invalid App Store Connect environment: \(parts.joined(separator: " ")). check \(path)"
        case .providerFailure(let providerSummary, let artifacts):
            switch format {
            case .human:
                fputs("error: \(providerSummary)\n", stderr)
            case .json:
                printAppRegisterJSONPayload(
                    status: "failed",
                    exitCode: Int(ExitCode.appRegisterFailed.rawValue),
                    summary: providerSummary,
                    metadata: nil,
                    bundleIdStatus: nil,
                    appStatus: nil,
                    artifacts: artifacts
                )
            }
            exit(ExitCode.appRegisterFailed.rawValue)
        }

        switch format {
        case .human:
            fputs("error: \(summary)\n", stderr)
        case .json:
            printAppRegisterJSONPayload(
                status: "failed",
                exitCode: Int(ExitCode.appRegisterFailed.rawValue),
                summary: summary,
                metadata: nil,
                bundleIdStatus: nil,
                appStatus: nil,
                artifacts: []
            )
        }
        exit(ExitCode.appRegisterFailed.rawValue)
    } catch {
        fail(
            message: "\(error)",
            command: .appRegister,
            format: format,
            exitCode: .appRegisterFailed
        )
    }
}
