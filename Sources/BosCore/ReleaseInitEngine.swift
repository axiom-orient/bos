import Foundation

public struct ReleaseInitRequest: Sendable {
    public let projectRoot: URL
    public let blueprint: BlueprintV1
    public let profile: ProfileV1
    public let environment: [String: String]

    public init(
        projectRoot: URL,
        blueprint: BlueprintV1,
        profile: ProfileV1,
        environment: [String: String]
    ) {
        self.projectRoot = projectRoot
        self.blueprint = blueprint
        self.profile = profile
        self.environment = environment
    }
}

public struct ReleaseInitResult: Sendable {
    public let generatedFiles: [String]
    public let lanes: [String]
    public let artifacts: [String]
}

public enum ReleaseInitEngineError: Error, Equatable {
    case missingRequiredEnvironment(keys: [String])
    case invalidEnvironmentFormat(details: [String])
    case laneParseFailed(path: String)
}

public struct ReleaseInitEngine: Sendable {
    public init() {}

    public func releaseInit(request: ReleaseInitRequest) throws -> ReleaseInitResult {
        let root = request.projectRoot.standardizedFileURL
        let envCheck = SigningEnvironmentPolicy.validate(environment: request.environment)
        if !envCheck.missingKeys.isEmpty {
            BosStateStore.updateSummary(
                projectRoot: root,
                kind: .release,
                status: "failed",
                message: "missing required environment: \(envCheck.missingKeys.joined(separator: ", "))"
            )
            throw ReleaseInitEngineError.missingRequiredEnvironment(keys: envCheck.missingKeys)
        }
        if !envCheck.invalidIssues.isEmpty {
            let details = envCheck.invalidIssues.map { "\($0.key)(\($0.rule))" }
            BosStateStore.updateSummary(
                projectRoot: root,
                kind: .release,
                status: "failed",
                message: "invalid environment format: \(details.joined(separator: ", "))"
            )
            throw ReleaseInitEngineError.invalidEnvironmentFormat(details: details)
        }

        let fm = FileManager.default
        try fm.createDirectory(at: root, withIntermediateDirectories: true)

        let fastlaneDir = root.appending(path: "fastlane")
        let metadataDir = fastlaneDir.appending(path: "metadata/en-US")
        try fm.createDirectory(at: metadataDir, withIntermediateDirectories: true)

        let fastfilePath = fastlaneDir.appending(path: "Fastfile")
        let appfilePath = fastlaneDir.appending(path: "Appfile")
        let matchfilePath = fastlaneDir.appending(path: "Matchfile")
        let metadataNotesPath = metadataDir.appending(path: "release_notes.txt")

        try RuntimeSupport.writeFile(to: fastfilePath, content: fastfileTemplate())
        try RuntimeSupport.writeFile(
            to: appfilePath,
            content: appfileTemplate(
                appIdentifier: request.blueprint.release.fastlane.appIdentifier,
                appleTeamId: request.blueprint.release.fastlane.appleTeamId
            )
        )
        try RuntimeSupport.writeFile(to: matchfilePath, content: matchfileTemplate())
        try RuntimeSupport.writeFile(to: metadataNotesPath, content: metadataTemplate(projectName: request.blueprint.project.name))

        let lanes: [String]
        do {
            lanes = try parseLanes(from: fastfilePath)
        } catch {
            BosStateStore.updateSummary(
                projectRoot: root,
                kind: .release,
                status: "failed",
                message: "failed to parse lanes from \(fastfilePath.path(percentEncoded: false))"
            )
            throw error
        }

        let artifactsDir = try RuntimeArtifacts.makeDirectory(for: "release-init")
        let stamp = RuntimeSupport.timestamp()
        let jsonPath = artifactsDir.appending(path: "release-init-\(stamp).json")
        let logPath = artifactsDir.appending(path: "release-init-\(stamp).log")
        let artifacts = [jsonPath.path(percentEncoded: false), logPath.path(percentEncoded: false)]

        let generatedFiles = [
            fastfilePath.path(percentEncoded: false),
            appfilePath.path(percentEncoded: false),
            matchfilePath.path(percentEncoded: false),
            metadataNotesPath.path(percentEncoded: false)
        ]

        try writeArtifact(to: jsonPath, generatedFiles: generatedFiles, lanes: lanes, artifacts: artifacts)
        try writeLog(
            to: logPath,
            profileName: request.profile.name,
            projectRoot: root.path(percentEncoded: false),
            generatedFiles: generatedFiles,
            lanes: lanes
        )
        BosStateStore.updateSummary(
            projectRoot: root,
            kind: .release,
            status: "success",
            message: "release-init completed"
        )

        return ReleaseInitResult(generatedFiles: generatedFiles, lanes: lanes, artifacts: artifacts)
    }
}

extension ReleaseInitEngine {
    private enum Constant {
        static let defaultLanes = ["certs", "build", "beta", "release", "release_metadata"]
    }

    private struct ArtifactPayload: Codable {
        let command: String
        let status: String
        let exitCode: Int
        let summary: String
        let lanes: [String]
        let generatedFiles: [String]
        let artifacts: [String]
    }

    private func parseLanes(from fastfilePath: URL) throws -> [String] {
        let content = try String(contentsOf: fastfilePath, encoding: .utf8)
        let regex = try NSRegularExpression(pattern: #"(?m)^\s*lane\s+:([A-Za-z0-9_]+)\s+do\s*$"#)
        let nsRange = NSRange(content.startIndex..<content.endIndex, in: content)
        let lanes = regex.matches(in: content, range: nsRange).compactMap { match -> String? in
            guard let range = Range(match.range(at: 1), in: content) else { return nil }
            return String(content[range])
        }

        let unique = RuntimeSupport.uniqueOrdered(lanes)
        let missingDefaults = Constant.defaultLanes.filter { !unique.contains($0) }
        if !missingDefaults.isEmpty {
            throw ReleaseInitEngineError.laneParseFailed(path: fastfilePath.path(percentEncoded: false))
        }
        return unique
    }

    private func fastfileTemplate() -> String {
        """
        default_platform(:ios)
        require 'base64'

        platform :ios do
          private_lane :asc_api_key do
            app_store_connect_api_key(
              key_id: ENV["ASC_KEY_ID"],
              issuer_id: ENV["ASC_ISSUER_ID"],
              key_content: Base64.decode64(ENV["ASC_KEY_P8_BASE64"]),
              is_key_content_base64: false
            )
          end

          lane :certs do
            sync_code_signing(type: "appstore", readonly: false, api_key: asc_api_key)
          end

          lane :build do
            build_app
          end

          lane :beta do
            api_key = asc_api_key
            pilot(api_key: api_key, ipa: ENV["IPA_PATH"], skip_waiting_for_build_processing: true)
          end

          lane :release do
            api_key = asc_api_key
            deliver(api_key: api_key, submit_for_review: false)
          end

          lane :release_metadata do
            deliver(skip_binary_upload: true, skip_screenshots: true, submit_for_review: false)
          end
        end
        """
    }

    private func appfileTemplate(appIdentifier: String, appleTeamId: String) -> String {
        """
        app_identifier("\(appIdentifier)")
        team_id("\(appleTeamId)")
        """
    }

    private func matchfileTemplate() -> String {
        """
        git_url(ENV["MATCH_GIT_URL"])
        storage_mode("git")
        type("appstore")
        readonly(false)
        """
    }

    private func metadataTemplate(projectName: String) -> String {
        """
        # \(projectName) Release Notes

        - Initial release notes scaffold
        """
    }

    private func writeArtifact(
        to path: URL,
        generatedFiles: [String],
        lanes: [String],
        artifacts: [String]
    ) throws {
        let payload = ArtifactPayload(
            command: "release-init",
            status: "success",
            exitCode: 0,
            summary: "Fastlane scaffold generated and lanes parsed",
            lanes: lanes,
            generatedFiles: generatedFiles,
            artifacts: artifacts
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        try RuntimeSupport.writeFile(to: path, data: data)
    }

    private func writeLog(
        to path: URL,
        profileName: String,
        projectRoot: String,
        generatedFiles: [String],
        lanes: [String]
    ) throws {
        let lines: [String] = [
            "# bos release-init",
            "profile=\(profileName)",
            "projectRoot=\(projectRoot)",
            "requiredEnvChecked=\(SigningEnvironmentPolicy.requiredKeys.joined(separator: ","))",
            "generatedFiles=",
            generatedFiles.map { "- \($0)" }.joined(separator: "\n"),
            "lanes=\(lanes.joined(separator: ","))",
            ""
        ]
        try RuntimeSupport.writeFile(to: path, content: lines.joined(separator: "\n"))
    }
}
