import Foundation

public struct DetectedToolchainV2: Sendable {
    public let swift: String
    public let tuist: String
    public let fastlane: String
    public let tmaPluginRef: ToolchainLockV2.TMAPluginRef

    public init(
        swift: String,
        tuist: String,
        fastlane: String,
        tmaPluginRef: ToolchainLockV2.TMAPluginRef
    ) {
        self.swift = swift
        self.tuist = tuist
        self.fastlane = fastlane
        self.tmaPluginRef = tmaPluginRef
    }
}

public enum DoctorSeverity: String, Codable, Sendable {
    case required
    case recommended
    case info
}

public enum DoctorFindingStatus: String, Codable, Sendable {
    case installed
    case missing
    case incompatible
}

public struct DoctorFinding: Codable, Equatable, Sendable {
    public let tool: String
    public let severity: DoctorSeverity
    public let status: DoctorFindingStatus
    public let expectedRule: String
    public let actualVersion: String
    public let requiredFor: [String]
    public let action: String
    public let installCommands: [String]

    public init(
        tool: String,
        severity: DoctorSeverity,
        status: DoctorFindingStatus,
        expectedRule: String,
        actualVersion: String,
        requiredFor: [String],
        action: String,
        installCommands: [String]
    ) {
        self.tool = tool
        self.severity = severity
        self.status = status
        self.expectedRule = expectedRule
        self.actualVersion = actualVersion
        self.requiredFor = requiredFor
        self.action = action
        self.installCommands = installCommands
    }
}

public struct DoctorRequest: Sendable {
    public let projectRoot: URL
    public let lock: ToolchainLockV2
    public let detected: DetectedToolchainV2
    public let checkCommands: [String]
    public let environment: [String: String]

    public init(
        projectRoot: URL,
        lock: ToolchainLockV2,
        detected: DetectedToolchainV2,
        checkCommands: [String],
        environment: [String: String] = [:]
    ) {
        self.projectRoot = projectRoot
        self.lock = lock
        self.detected = detected
        self.checkCommands = checkCommands
        self.environment = environment
    }
}

public struct DoctorResult: Sendable {
    public let artifacts: [String]
    public let summary: String
    public let status: String
    public let exitCode: Int
    public let findings: [DoctorFinding]

    public init(
        artifacts: [String],
        summary: String,
        status: String,
        exitCode: Int,
        findings: [DoctorFinding]
    ) {
        self.artifacts = artifacts
        self.summary = summary
        self.status = status
        self.exitCode = exitCode
        self.findings = findings
    }
}

public struct DoctorEngine: Sendable {
    public init() {}

    public func check(request: DoctorRequest) throws -> DoctorResult {
        let findings = buildFindings(
            lock: request.lock,
            detected: request.detected,
            checkCommands: request.checkCommands,
            environment: request.environment
        )
        let blocking = findings.filter { $0.severity == .required && $0.status != .installed }

        let artifactsDir = try RuntimeArtifacts.makeDirectory(for: "doctor", projectRoot: request.projectRoot)

        let stamp = RuntimeSupport.timestamp()
        let jsonPath = artifactsDir.appending(path: "doctor-\(stamp).json")
        let logPath = artifactsDir.appending(path: "doctor-\(stamp).log")
        let artifacts = [jsonPath.path(percentEncoded: false), logPath.path(percentEncoded: false)]

        let status = blocking.isEmpty ? "success" : "failed"
        let exitCode = blocking.isEmpty ? 0 : 6
        let summary: String
        if blocking.isEmpty {
            summary = "Doctor passed for \(normalizedScope(checkCommands: request.checkCommands))"
        } else {
            let blockedTools = blocking.map(\.tool).joined(separator: ", ")
            summary = "Doctor failed: required tools not ready (\(blockedTools))"
        }

        try writeArtifact(
            to: jsonPath,
            status: status,
            exitCode: exitCode,
            summary: summary,
            findings: findings,
            artifacts: artifacts,
            checkCommands: request.checkCommands
        )
        try writeLog(
            to: logPath,
            findings: findings,
            summary: summary,
            checkCommands: request.checkCommands
        )

        return DoctorResult(
            artifacts: artifacts,
            summary: summary,
            status: status,
            exitCode: exitCode,
            findings: findings
        )
    }
}

extension DoctorEngine {
    private struct ArtifactPayload: Codable {
        let command: String
        let status: String
        let exitCode: Int
        let summary: String
        let checkCommands: [String]
        let findings: [DoctorFinding]
        let artifacts: [String]
    }

    private struct SemVer: Comparable {
        let major: Int
        let minor: Int
        let patch: Int

        static func < (lhs: SemVer, rhs: SemVer) -> Bool {
            if lhs.major != rhs.major { return lhs.major < rhs.major }
            if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
            return lhs.patch < rhs.patch
        }

        init?(from raw: String) {
            let pattern = #"\d+(?:\.\d+){0,2}"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                return nil
            }
            let nsRange = NSRange(raw.startIndex..<raw.endIndex, in: raw)
            guard let match = regex.firstMatch(in: raw, range: nsRange),
                  let range = Range(match.range, in: raw) else {
                return nil
            }
            let parts = raw[range].split(separator: ".").compactMap { Int($0) }
            guard let major = parts.first else { return nil }
            let minor = parts.count > 1 ? parts[1] : 0
            let patch = parts.count > 2 ? parts[2] : 0
            self.major = major
            self.minor = minor
            self.patch = patch
        }
    }

    private func buildFindings(
        lock: ToolchainLockV2,
        detected: DetectedToolchainV2,
        checkCommands: [String],
        environment: [String: String]
    ) -> [DoctorFinding] {
        let scope = Set(checkCommands)

        var findings: [DoctorFinding] = []
        findings.append(evaluate(
            tool: "swift",
            actual: detected.swift,
            requirement: lock.tools.swift,
            scope: scope
        ))
        findings.append(evaluate(
            tool: "tuist",
            actual: detected.tuist,
            requirement: lock.tools.tuist,
            scope: scope
        ))
        findings.append(evaluate(
            tool: "fastlane",
            actual: detected.fastlane,
            requirement: lock.tools.fastlane,
            scope: scope
        ))

        let tmaExpected = "exact:\(lock.tmaPluginRef.type):\(lock.tmaPluginRef.value)"
        let tmaActual = "\(detected.tmaPluginRef.type):\(detected.tmaPluginRef.value)"
        let tmaStatus: DoctorFindingStatus
        if lock.tmaPluginRef.value == "unknown" {
            tmaStatus = .installed
        } else if lock.tmaPluginRef.type == detected.tmaPluginRef.type && lock.tmaPluginRef.value == detected.tmaPluginRef.value {
            tmaStatus = .installed
        } else {
            tmaStatus = .incompatible
        }
        findings.append(
            DoctorFinding(
                tool: "tmaPluginRef",
                severity: .info,
                status: tmaStatus,
                expectedRule: tmaExpected,
                actualVersion: tmaActual,
                requiredFor: ToolchainLockV2.allCommands,
                action: tmaStatus == .installed
                    ? "No action required"
                    : "Set TMA_PLUGIN_REF_TYPE/TMA_PLUGIN_REF_VALUE to match lock value",
                installCommands: []
            )
        )
        findings.append(
            signingEnvironmentFinding(
                scope: scope,
                environment: environment
            )
        )

        return findings
    }

    private func signingEnvironmentFinding(
        scope: Set<String>,
        environment: [String: String]
    ) -> DoctorFinding {
        let check = SigningEnvironmentPolicy.validate(environment: environment)
        let isReleaseRequested = scope.contains(ToolchainLockV2.commandReleaseInit)
        let severity: DoctorSeverity = isReleaseRequested ? .required : .recommended

        let status: DoctorFindingStatus
        if !check.missingKeys.isEmpty {
            status = .missing
        } else if !check.invalidIssues.isEmpty {
            status = .incompatible
        } else {
            status = .installed
        }

        let actualVersion: String
        if status == .installed {
            actualVersion = "valid"
        } else {
            var fragments: [String] = []
            if !check.missingKeys.isEmpty {
                fragments.append("missing=\(check.missingKeys.joined(separator: ","))")
            }
            if !check.invalidIssues.isEmpty {
                let invalid = check.invalidIssues.map { "\($0.key)(\($0.rule))" }.joined(separator: ",")
                fragments.append("invalid=\(invalid)")
            }
            actualVersion = fragments.joined(separator: ";")
        }

        let action: String
        switch status {
        case .installed:
            action = "No action required"
        case .missing:
            action = "Set required signing environment keys before release-init"
        case .incompatible:
            action = "Fix signing environment formats before release-init"
        }

        return DoctorFinding(
            tool: "signing-env",
            severity: severity,
            status: status,
            expectedRule: SigningEnvironmentPolicy.expectedRuleSummary,
            actualVersion: actualVersion,
            requiredFor: [ToolchainLockV2.commandReleaseInit],
            action: action,
            installCommands: []
        )
    }

    private func evaluate(
        tool: String,
        actual: String,
        requirement: ToolchainLockV2.ToolRequirement,
        scope: Set<String>
    ) -> DoctorFinding {
        let required = !scope.isDisjoint(with: requirement.requiredFor)
        let severity: DoctorSeverity = required ? .required : .recommended

        let status: DoctorFindingStatus
        if actual == "not-found" {
            status = .missing
        } else if matches(actualVersion: actual, rule: requirement.versionRule) {
            status = .installed
        } else {
            status = .incompatible
        }

        let affected = requirement.requiredFor.filter { scope.contains($0) }
        let action: String
        switch status {
        case .installed:
            action = "No action required"
        case .missing:
            if required {
                action = "Install \(tool) before running: \(affected.joined(separator: ", "))"
            } else {
                action = "Install \(tool) to enable optional commands: \(requirement.requiredFor.joined(separator: ", "))"
            }
        case .incompatible:
            if required {
                action = "Use a compatible \(tool) version for \(affected.joined(separator: ", "))"
            } else {
                action = "Update \(tool) to a compatible version when using \(requirement.requiredFor.joined(separator: ", "))"
            }
        }

        return DoctorFinding(
            tool: tool,
            severity: severity,
            status: status,
            expectedRule: "\(requirement.versionRule.kind):\(requirement.versionRule.value)",
            actualVersion: actual,
            requiredFor: requirement.requiredFor,
            action: action,
            installCommands: requirement.installHints
        )
    }

    private func matches(actualVersion: String, rule: ToolchainLockV2.VersionRule) -> Bool {
        switch rule.kind {
        case "exact":
            return actualVersion.trimmingCharacters(in: .whitespacesAndNewlines) == rule.value.trimmingCharacters(in: .whitespacesAndNewlines)
        case "semver-range":
            guard let actual = SemVer(from: actualVersion) else { return false }
            let normalized = rule.value
                .replacingOccurrences(of: ",", with: " ")
                .split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" })
                .map(String.init)
            guard !normalized.isEmpty else { return false }

            for clause in normalized {
                guard evaluateRangeClause(actual: actual, clause: clause) else {
                    return false
                }
            }
            return true
        default:
            return false
        }
    }

    private func evaluateRangeClause(actual: SemVer, clause: String) -> Bool {
        let trimmed = clause.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return true
        }

        let op: String
        let versionPart: String
        if trimmed.hasPrefix(">=") {
            op = ">="
            versionPart = String(trimmed.dropFirst(2))
        } else if trimmed.hasPrefix("<=") {
            op = "<="
            versionPart = String(trimmed.dropFirst(2))
        } else if trimmed.hasPrefix(">") {
            op = ">"
            versionPart = String(trimmed.dropFirst())
        } else if trimmed.hasPrefix("<") {
            op = "<"
            versionPart = String(trimmed.dropFirst())
        } else if trimmed.hasPrefix("=") {
            op = "="
            versionPart = String(trimmed.dropFirst())
        } else {
            op = "="
            versionPart = trimmed
        }

        guard let expected = SemVer(from: versionPart) else {
            return false
        }

        switch op {
        case ">=": return actual >= expected
        case "<=": return actual <= expected
        case ">": return actual > expected
        case "<": return actual < expected
        case "=": return actual == expected
        default: return false
        }
    }

    private func writeArtifact(
        to path: URL,
        status: String,
        exitCode: Int,
        summary: String,
        findings: [DoctorFinding],
        artifacts: [String],
        checkCommands: [String]
    ) throws {
        let payload = ArtifactPayload(
            command: "doctor",
            status: status,
            exitCode: exitCode,
            summary: summary,
            checkCommands: checkCommands,
            findings: findings,
            artifacts: artifacts
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        try RuntimeSupport.writeFile(to: path, data: data)
    }

    private func writeLog(
        to path: URL,
        findings: [DoctorFinding],
        summary: String,
        checkCommands: [String]
    ) throws {
        var lines: [String] = [
            "# bos doctor",
            "check.commands=\(normalizedScope(checkCommands: checkCommands))",
            "summary=\(summary)",
            "finding.count=\(findings.count)"
        ]

        for finding in findings {
            lines.append(
                "finding.\(finding.tool): severity=\(finding.severity.rawValue), status=\(finding.status.rawValue), expected=\(finding.expectedRule), actual=\(finding.actualVersion), action=\(finding.action)"
            )
            if !finding.installCommands.isEmpty {
                lines.append("finding.\(finding.tool).install=\(finding.installCommands.joined(separator: " | "))")
            }
        }
        lines.append("")

        try RuntimeSupport.writeFile(to: path, content: lines.joined(separator: "\n"))
    }

    private func normalizedScope(checkCommands: [String]) -> String {
        if checkCommands == ToolchainLockV2.coreCommands {
            return "core"
        }
        if checkCommands == ToolchainLockV2.allCommands {
            return "all"
        }
        return checkCommands.joined(separator: ",")
    }

}
