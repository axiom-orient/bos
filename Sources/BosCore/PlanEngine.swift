import Foundation

public enum PlanEngineError: Error, Equatable {
    case missingReqIDs
    case missingScreens
    case missingEntities
    case missingAppIdentifier
    case missingAppleTeamID
    case missingBundleIdPrefix
}

public struct PlanDeriveOptions: Sendable {
    public let projectName: String?
    public let appName: String?
    public let appIdentifier: String?
    public let appleTeamID: String?
    public let companyName: String?
    public let primaryLanguage: String?
    public let sku: String?

    public init(
        projectName: String? = nil,
        appName: String? = nil,
        appIdentifier: String? = nil,
        appleTeamID: String? = nil,
        companyName: String? = nil,
        primaryLanguage: String? = nil,
        sku: String? = nil
    ) {
        self.projectName = Self.normalized(projectName)
        self.appName = Self.normalized(appName)
        self.appIdentifier = Self.normalized(appIdentifier)
        self.appleTeamID = Self.normalized(appleTeamID)
        self.companyName = Self.normalized(companyName)
        self.primaryLanguage = Self.normalized(primaryLanguage)
        self.sku = Self.normalized(sku)
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension PlanEngineError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .missingReqIDs:
            return "PRD에 REQ-ID(REQ-...)가 없습니다."
        case .missingScreens:
            return "PRD에 화면 식별자(SCR_...)가 없습니다."
        case .missingEntities:
            return "PRD에 엔티티(Entity: ...)가 없습니다."
        case .missingAppIdentifier:
            return "PRD에 App Identifier가 없습니다."
        case .missingAppleTeamID:
            return "PRD에 Apple Team ID가 없습니다."
        case .missingBundleIdPrefix:
            return "PRD 또는 App Identifier에서 bundleIdPrefix를 계산할 수 없습니다."
        }
    }
}

public struct PlanEngine: Sendable {
    public init() {}

    public func generateBlueprint(
        prd: String,
        profile: Profile,
        options: PlanDeriveOptions = .init()
    ) throws -> Blueprint {
        let reqIDs = RuntimeSupport.uniqueOrdered(extractRequirementIDs(in: prd))
        guard !reqIDs.isEmpty else { throw PlanEngineError.missingReqIDs }

        let screens = RuntimeSupport.uniqueOrdered(extractScreenIDs(in: prd))
        guard !screens.isEmpty else { throw PlanEngineError.missingScreens }

        let entities = extractEntities(from: prd)
        guard !entities.isEmpty else { throw PlanEngineError.missingEntities }

        let appIdentifier = firstNonEmpty(
            options.appIdentifier,
            profile.configuredAppIdentifier,
            firstCapturedGroup(in: prd, regex: Self.appIdentifierRegex)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        )
        guard let appIdentifier, !appIdentifier.isEmpty else { throw PlanEngineError.missingAppIdentifier }

        let appleTeamID = firstNonEmpty(
            options.appleTeamID,
            profile.configuredAppleTeamId,
            firstCapturedGroup(in: prd, regex: Self.appleTeamIDRegex)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        )
        guard let appleTeamID, !appleTeamID.isEmpty else { throw PlanEngineError.missingAppleTeamID }

        let explicitPrefix = firstCapturedGroup(in: prd, regex: Self.bundlePrefixRegex)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let bundlePrefix = explicitPrefix ?? deriveBundlePrefix(from: appIdentifier)
        guard let bundlePrefix, !bundlePrefix.isEmpty else { throw PlanEngineError.missingBundleIdPrefix }

        let projectName = resolvedProjectName(from: prd, appIdentifier: appIdentifier, options: options)
        let appName = firstNonEmpty(
            options.appName,
            profile.configuredAppName,
            firstCapturedGroup(in: prd, regex: Self.appNameRegex)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            projectName
        ) ?? projectName
        let companyName = firstNonEmpty(
            options.companyName,
            profile.configuredCompanyName,
            firstCapturedGroup(in: prd, regex: Self.companyNameRegex)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        )
        let primaryLanguage = firstNonEmpty(
            options.primaryLanguage,
            profile.configuredPrimaryLanguage,
            firstCapturedGroup(in: prd, regex: Self.primaryLanguageRegex)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        ) ?? "en-US"
        let sku = firstNonEmpty(
            options.sku,
            profile.configuredSKU,
            firstCapturedGroup(in: prd, regex: Self.skuRegex)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        ) ?? derivedSKU(companyName: companyName, appName: appName, appIdentifier: appIdentifier)
        let domainNames = RuntimeSupport.uniqueOrdered(entities.map(toPascalCase))
        let featureNames = buildFeatures(from: screens)
        let serviceNames = RuntimeSupport.uniqueOrdered(domainNames.map { "\($0)Service" })

        let project = try Blueprint.Project(
            name: projectName,
            bundleIdPrefix: bundlePrefix,
            deploymentTarget: profile.defaults.deploymentTarget
        )
        let requirements = try Blueprint.Requirements(reqIds: reqIDs, screens: screens)
        let appModule = try Blueprint.AppModule(name: projectName)
        let modules = try Blueprint.Modules(
            app: appModule,
            features: featureNames,
            domains: domainNames,
            services: serviceNames,
            shared: ["Core", "DesignSystem"]
        )
        let wiring = try Blueprint.Wiring(rootFeature: "Root")
        let fastlane = try Blueprint.Fastlane(
            appIdentifier: appIdentifier,
            appleTeamId: appleTeamID,
            appName: appName,
            sku: sku,
            primaryLanguage: primaryLanguage,
            companyName: companyName
        )
        let release = Blueprint.Release(fastlane: fastlane)

        return try Blueprint(
            schemaVersion: 1,
            project: project,
            requirements: requirements,
            modules: modules,
            wiring: wiring,
            release: release
        )
    }

    public func derivePRD(fromPlanText text: String, options: PlanDeriveOptions = .init()) -> String {
        let reqIDs = RuntimeSupport.uniqueOrdered(extractRequirementIDs(in: text))
        let screens = RuntimeSupport.uniqueOrdered(extractScreenIDs(in: text))
        let entities = RuntimeSupport.uniqueOrdered(extractEntitiesForPlan(from: text))

        let projectName = options.projectName
            ?? firstCapturedGroup(in: text, regex: Self.projectNameRegex)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? deriveProjectNameFromHeading(in: text)
            ?? "App"
        let appName = options.appName
            ?? firstCapturedGroup(in: text, regex: Self.appNameRegex)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? projectName
        let appIdentifier = options.appIdentifier
            ?? firstCapturedGroup(in: text, regex: Self.appIdentifierRegex)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        let appleTeamID = options.appleTeamID
            ?? firstCapturedGroup(in: text, regex: Self.appleTeamIDRegex)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        let companyName = options.companyName
            ?? firstCapturedGroup(in: text, regex: Self.companyNameRegex)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        let primaryLanguage = options.primaryLanguage
            ?? firstCapturedGroup(in: text, regex: Self.primaryLanguageRegex)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? "en-US"
        let sku = options.sku
            ?? firstCapturedGroup(in: text, regex: Self.skuRegex)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? {
                guard let appIdentifier else { return nil }
                return derivedSKU(companyName: companyName, appName: appName, appIdentifier: appIdentifier)
            }()

        var lines: [String] = [
            "# Derived PRD",
            "",
            "Project: \(projectName)",
            "App Name: \(appName)"
        ]
        if let appIdentifier {
            lines.append("App Identifier: \(appIdentifier)")
        }
        if let appleTeamID {
            lines.append("Apple Team ID: \(appleTeamID)")
        }
        if let companyName {
            lines.append("Company Name: \(companyName)")
        }
        lines.append("Primary Language: \(primaryLanguage)")
        if let sku {
            lines.append("SKU: \(sku)")
        }
        lines.append("")
        lines.append("## Requirements")
        lines.append(contentsOf: reqIDs.map { "- \($0)" })
        lines.append("")
        lines.append("## Screens")
        lines.append(contentsOf: screens.map { "- \($0)" })
        lines.append("")
        lines.append("## Entities")
        lines.append(contentsOf: entities.map { "- Entity: \($0)" })
        lines.append("")

        return lines.joined(separator: "\n")
    }
}

extension PlanEngine {
    private struct ScreenKeywordRule {
        let id: String
        let keywords: [String]
        let requireAll: Bool
    }

    private static let reqRegex = try! NSRegularExpression(pattern: #"\bREQ-[A-Z0-9_-]+\b"#, options: [.caseInsensitive])
    private static let frRegex = try! NSRegularExpression(pattern: #"\bFR-(\d{1,3})\b"#, options: [.caseInsensitive])
    private static let scrRegex = try! NSRegularExpression(pattern: #"\bSCR_[A-Z0-9_]+\b"#, options: [.caseInsensitive])
    private static let entityLineRegex = try! NSRegularExpression(
        pattern: #"(?mi)^\s*(?:#{1,6}\s+)?(?:[-*•]\s*)?(?:\*{1,2})?(?:Entity|Domain|엔티티)(?:\*{1,2})?\s*[-:]\s*([A-Za-z0-9_][A-Za-z0-9_\- ]+)\s*$"#
    )
    private static let entityHeadingRegex = try! NSRegularExpression(
        pattern: #"(?mi)^#{2,6}\s*\d+(?:\.\d+)+\s+([A-Za-z][A-Za-z0-9_]+)\s*$"#
    )
    private static let appIdentifierRegex = try! NSRegularExpression(
        pattern: #"(?mi)^\s*(?:App Identifier|AppIdentifier)\s*:\s*([A-Za-z0-9.]+)\s*$"#
    )
    private static let appleTeamIDRegex = try! NSRegularExpression(
        pattern: #"(?mi)^\s*(?:Apple Team ID|Team ID|AppleTeamId)\s*:\s*([A-Za-z0-9]+)\s*$"#
    )
    private static let appNameRegex = try! NSRegularExpression(
        pattern: #"(?mi)^\s*(?:App Name|AppName)\s*:\s*(.+?)\s*$"#
    )
    private static let companyNameRegex = try! NSRegularExpression(
        pattern: #"(?mi)^\s*(?:Company Name|CompanyName)\s*:\s*(.+?)\s*$"#
    )
    private static let primaryLanguageRegex = try! NSRegularExpression(
        pattern: #"(?mi)^\s*(?:Primary Language|PrimaryLanguage)\s*:\s*([A-Za-z]{2}-[A-Za-z]{2})\s*$"#
    )
    private static let skuRegex = try! NSRegularExpression(
        pattern: #"(?mi)^\s*(?:SKU|Sku)\s*:\s*([A-Za-z0-9._-]+)\s*$"#
    )
    private static let bundlePrefixRegex = try! NSRegularExpression(
        pattern: #"(?mi)^\s*(?:Bundle(?:Id)?Prefix|Bundle Prefix)\s*:\s*([A-Za-z0-9.]+)\s*$"#
    )
    private static let projectNameRegex = try! NSRegularExpression(
        pattern: #"(?mi)^\s*(?:Project|프로젝트)\s*:\s*([A-Za-z0-9_\- ]+)\s*$"#
    )
    private static let projectHeadingRegex = try! NSRegularExpression(
        pattern: #"(?m)^#\s*([A-Za-z][A-Za-z0-9_-]*)"#
    )
    private static let screenKeywordRules: [ScreenKeywordRule] = [
        ScreenKeywordRule(id: "SCR_TODAY", keywords: ["today", "오늘"], requireAll: false),
        ScreenKeywordRule(id: "SCR_SHELF", keywords: ["shelf", "서랍"], requireAll: false),
        ScreenKeywordRule(id: "SCR_CAPTURE", keywords: ["capture", "입력 화면"], requireAll: false),
        ScreenKeywordRule(id: "SCR_REVIEW", keywords: ["review", "정리 결과", "정리하기"], requireAll: false),
        ScreenKeywordRule(id: "SCR_FOCUS", keywords: ["focus", "집중"], requireAll: false),
        ScreenKeywordRule(id: "SCR_REFLECTION", keywords: ["reflection", "돌아보기"], requireAll: false),
        ScreenKeywordRule(id: "SCR_WEEKLY_REVIEW", keywords: ["weekly review", "주간 돌아보기"], requireAll: false),
        ScreenKeywordRule(id: "SCR_SETTINGS", keywords: ["settings", "설정"], requireAll: false),
        ScreenKeywordRule(id: "SCR_PERMISSION_VOICE", keywords: ["permission", "voice"], requireAll: true),
        ScreenKeywordRule(id: "SCR_PERMISSION_VOICE", keywords: ["권한", "음성"], requireAll: true)
    ]

    private func extractRequirementIDs(in text: String) -> [String] {
        let explicit = extractMatches(in: text, regex: Self.reqRegex).map { $0.uppercased() }
        let fromFR = capturedGroups(in: text, regex: Self.frRegex).compactMap { raw -> String? in
            guard let number = Int(raw) else { return nil }
            return String(format: "REQ-%03d", number)
        }
        return RuntimeSupport.uniqueOrdered(explicit + fromFR)
    }

    private func extractScreenIDs(in text: String) -> [String] {
        let explicit = extractMatches(in: text, regex: Self.scrRegex).map { $0.uppercased() }
        if !explicit.isEmpty {
            return RuntimeSupport.uniqueOrdered(explicit)
        }
        let derived = deriveScreensFromKeywords(in: text)
        return RuntimeSupport.uniqueOrdered(derived)
    }

    private func extractEntities(from prd: String) -> [String] {
        let raw = capturedGroups(in: prd, regex: Self.entityLineRegex)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return RuntimeSupport.uniqueOrdered(raw.map(toPascalCase))
    }

    private func extractEntitiesForPlan(from text: String) -> [String] {
        let explicit = extractEntities(from: text)
        let headingEntities = capturedGroups(in: text, regex: Self.entityHeadingRegex)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { isLikelyEntityHeading($0) }
            .map(toPascalCase)
        return RuntimeSupport.uniqueOrdered(explicit + headingEntities)
    }

    private func resolvedProjectName(
        from prd: String,
        appIdentifier: String,
        options: PlanDeriveOptions
    ) -> String {
        if let explicit = options.projectName {
            return explicit
        }
        return projectName(from: prd, appIdentifier: appIdentifier)
    }

    private func projectName(from prd: String, appIdentifier: String) -> String {
        if let explicit = firstCapturedGroup(in: prd, regex: Self.projectNameRegex)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !explicit.isEmpty {
            return explicit
        }

        let fallback = appIdentifier.split(separator: ".").last.map(String.init) ?? "App"
        return toPascalCase(fallback)
    }

    private func deriveProjectNameFromHeading(in text: String) -> String? {
        guard let heading = firstCapturedGroup(in: text, regex: Self.projectHeadingRegex)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !heading.isEmpty else {
            return nil
        }
        return toPascalCase(heading)
    }

    private func deriveBundlePrefix(from appIdentifier: String) -> String? {
        let chunks = appIdentifier.split(separator: ".").map(String.init)
        guard chunks.count >= 2 else { return nil }
        return chunks.dropLast().joined(separator: ".")
    }

    private func buildFeatures(from screens: [String]) -> [String] {
        let extracted = screens.map { id in
            let stripped = id.replacingOccurrences(of: "SCR_", with: "", options: [.caseInsensitive])
            return toPascalCase(stripped)
        }
        return RuntimeSupport.uniqueOrdered(["Root"] + extracted)
    }

    private func extractMatches(in text: String, regex: NSRegularExpression) -> [String] {
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, options: [], range: nsRange).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return String(text[range])
        }
    }

    private func capturedGroups(in text: String, regex: NSRegularExpression) -> [String] {
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, options: [], range: nsRange).compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            guard let range = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[range])
        }
    }

    private func firstCapturedGroup(in text: String, regex: NSRegularExpression) -> String? {
        capturedGroups(in: text, regex: regex).first
    }

    private func firstNonEmpty(_ values: String?...) -> String? {
        values.first { value in
            guard let value else { return false }
            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } ?? nil
    }

    private func derivedSKU(companyName: String?, appName: String, appIdentifier: String) -> String? {
        AppRegistrationSupport.deterministicSKU(
            companyName: companyName,
            appName: appName,
            appIdentifier: appIdentifier
        )
    }

    private func slug(_ value: String) -> String {
        let lowercase = value.lowercased()
        let pieces = lowercase.split { character in
            !character.isLetter && !character.isNumber
        }
        return pieces.map(String.init).filter { !$0.isEmpty }.joined(separator: "-")
    }

    private func deriveScreensFromKeywords(in text: String) -> [String] {
        let lower = text.lowercased()
        var screens: [String] = []
        for rule in Self.screenKeywordRules {
            let matched: Bool
            if rule.requireAll {
                matched = rule.keywords.allSatisfy { lower.contains($0.lowercased()) }
            } else {
                matched = rule.keywords.contains { lower.contains($0.lowercased()) }
            }
            if matched {
                screens.append(rule.id)
            }
        }
        return RuntimeSupport.uniqueOrdered(screens)
    }

    private func isLikelyEntityHeading(_ heading: String) -> Bool {
        let normalized = heading.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return false }
        let lower = normalized.lowercased()
        if lower == "item" { return true }
        let suffixes = ["item", "session", "record", "decision", "goal", "entity"]
        return suffixes.contains { lower.hasSuffix($0) }
    }

    private func toPascalCase(_ raw: String) -> String {
        NameNormalizer.pascalCase(raw, fallback: "Module")
    }
}
