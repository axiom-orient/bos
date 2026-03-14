import Foundation
import BosCore

func readPlanMarkdownCorpus(from planDirectory: URL) throws -> String {
    var isDirectory: ObjCBool = false
    let fm = FileManager.default
    guard fm.fileExists(atPath: planDirectory.path(percentEncoded: false), isDirectory: &isDirectory), isDirectory.boolValue else {
        throw NSError(
            domain: "BosCLI.Plan",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "plan directory not found: \(planDirectory.path(percentEncoded: false))"]
        )
    }

    guard let enumerator = fm.enumerator(
        at: planDirectory,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
    ) else {
        throw NSError(
            domain: "BosCLI.Plan",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "failed to enumerate plan directory: \(planDirectory.path(percentEncoded: false))"]
        )
    }

    var markdownFiles: [URL] = []
    for case let file as URL in enumerator {
        let ext = file.pathExtension.lowercased()
        if ext == "md" || ext == "markdown" {
            markdownFiles.append(file)
        }
    }
    markdownFiles.sort { $0.path(percentEncoded: false) < $1.path(percentEncoded: false) }

    guard !markdownFiles.isEmpty else {
        throw NSError(
            domain: "BosCLI.Plan",
            code: 3,
            userInfo: [NSLocalizedDescriptionKey: "no markdown files found under plan directory: \(planDirectory.path(percentEncoded: false))"]
        )
    }

    let chunks = try markdownFiles.map { url in
        try String(contentsOf: url, encoding: .utf8)
    }
    return chunks.joined(separator: "\n\n")
}

func planErrorMessage(_ error: PlanEngineError) -> String {
    switch error {
    case .missingReqIDs:
        return "requirements not found. add `REQ-001` markers or `FR-001` markers in PRD/PLAN documents."
    case .missingScreens:
        return "screens not found. add `SCR_HOME` markers or include screen keywords (Today/Shelf/Capture/Focus/Reflection/Weekly Review/Settings)."
    case .missingEntities:
        return "entities not found. add `Entity: User` lines or numbered domain headings such as `11.1 Item`."
    case .missingAppIdentifier:
        return "missing App Identifier. add it to `config/bos.profile.yaml` identity.appIdentifier, documents, or pass `--app-identifier com.example.app`."
    case .missingAppleTeamID:
        return "missing Apple Team ID. add it to `config/bos.profile.yaml` identity.appleTeamId, documents, or pass `--apple-team-id ABCD123456`."
    case .missingBundleIdPrefix:
        return "failed to derive bundle prefix. check `App Identifier` format (example: com.example.app)."
    }
}

func runPlan(args: [String], format: OutputFormat) {
    let parsed = parseOptions(
        args: args,
        valueFlags: [
            "--project-root",
            "--prd",
            "--plan-dir",
            "--profile",
            "--out",
            "--company-name",
            "--app-name",
            "--app-identifier",
            "--apple-team-id",
            "--primary-language",
            "--sku",
            "--format"
        ],
        booleanFlags: []
    )
    assertOptionContract(parsed: parsed, command: .plan, format: format)

    let prdRaw = parsed.values["--prd"]
    let planDirRaw = parsed.values["--plan-dir"]
    if (prdRaw == nil) == (planDirRaw == nil) {
        fail(
            message: "choose exactly one input source: --prd <path> or --plan-dir <path>",
            command: .plan,
            format: format
        )
    }

    let projectRoot = resolveProjectRoot(from: parsed)
    let profileContext = loadProfileContext(
        raw: parsed.values["--profile"],
        projectRoot: projectRoot,
        command: .plan,
        format: format
    )
    let outRaw = parsed.values["--out"] ?? defaultBlueprintPath(projectRoot: projectRoot).path(percentEncoded: false)
    let outPath = resolvePath(outRaw, base: projectRoot)

    do {
        let deriveOptions = PlanDeriveOptions(
            appName: parsed.values["--app-name"] ?? profileContext.profile.configuredAppName,
            appIdentifier: parsed.values["--app-identifier"] ?? profileContext.profile.configuredAppIdentifier,
            appleTeamID: parsed.values["--apple-team-id"] ?? profileContext.profile.configuredAppleTeamId,
            companyName: parsed.values["--company-name"] ?? profileContext.profile.configuredCompanyName,
            primaryLanguage: parsed.values["--primary-language"] ?? profileContext.profile.configuredPrimaryLanguage,
            sku: parsed.values["--sku"] ?? profileContext.profile.configuredSKU
        )
        let prd: String
        if let prdRaw {
            let prdPath = resolvePath(prdRaw, base: projectRoot)
            prd = try readTextFile(prdPath)
        } else if let planDirRaw {
            let planDirPath = resolvePath(planDirRaw, base: projectRoot)
            let corpus = try readPlanMarkdownCorpus(from: planDirPath)
            prd = PlanEngine().derivePRD(fromPlanText: corpus, options: deriveOptions)
        } else {
            fail(
                message: "choose exactly one input source: --prd <path> or --plan-dir <path>",
                command: .plan,
                format: format
            )
        }

        let blueprint = try PlanEngine().generateBlueprint(
            prd: prd,
            profile: profileContext.profile,
            options: deriveOptions
        )
        let encoded = try encodeYAML(blueprint)
        try writeTextFile(encoded, to: outPath)

        let summary = "Blueprint generated at \(outPath.path(percentEncoded: false))"
        let artifacts = [outPath.path(percentEncoded: false)]
        switch format {
        case .human:
            renderHumanSuccess(summary: summary, artifacts: artifacts)
        case .json:
            printJSONPayload(
                command: BosCommand.plan.rawValue,
                status: "success",
                exitCode: Int(ExitCode.success.rawValue),
                summary: summary,
                artifacts: artifacts
            )
        }
        exit(ExitCode.success.rawValue)
    } catch let error as PlanEngineError {
        fail(message: planErrorMessage(error), command: .plan, format: format)
    } catch {
        fail(message: "\(error)", command: .plan, format: format)
    }
}
