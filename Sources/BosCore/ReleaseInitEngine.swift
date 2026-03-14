import Foundation

public struct ReleaseInitRequest: Sendable {
    public let projectRoot: URL
    public let blueprint: Blueprint
    public let profile: Profile
    public let environment: [String: String]

    public init(
        projectRoot: URL,
        blueprint: Blueprint,
        profile: Profile,
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
        let effectiveEnvironment = ReleaseEnvironment.effectiveEnvironment(
            profile: request.profile,
            environment: request.environment
        )
        let envCheck = SigningEnvironmentPolicy.validate(environment: effectiveEnvironment)
        if !envCheck.missingKeys.isEmpty {
            let summary = "missing required environment: \(envCheck.missingKeys.joined(separator: ", "))"
            BosStateStore.updateSummary(
                projectRoot: root,
                kind: .release,
                status: "failed",
                message: summary
            )
            BosStateStore.updateReleaseInitState(
                projectRoot: root,
                status: "failed",
                summary: summary,
                artifactDirectory: nil,
                generatedFiles: [],
                lanes: []
            )
            throw ReleaseInitEngineError.missingRequiredEnvironment(keys: envCheck.missingKeys)
        }
        if !envCheck.invalidIssues.isEmpty {
            let details = envCheck.invalidIssues.map { "\($0.key)(\($0.rule))" }
            let summary = "invalid environment format: \(details.joined(separator: ", "))"
            BosStateStore.updateSummary(
                projectRoot: root,
                kind: .release,
                status: "failed",
                message: summary
            )
            BosStateStore.updateReleaseInitState(
                projectRoot: root,
                status: "failed",
                summary: summary,
                artifactDirectory: nil,
                generatedFiles: [],
                lanes: []
            )
            throw ReleaseInitEngineError.invalidEnvironmentFormat(details: details)
        }

        let fm = FileManager.default
        try fm.createDirectory(at: root, withIntermediateDirectories: true)

        let fastlaneDir = root.appending(path: "fastlane")
        let primaryLanguage = request.blueprint.release.fastlane.primaryLanguage ?? request.profile.configuredPrimaryLanguage
        let metadataDir = fastlaneDir.appending(path: "metadata/\(primaryLanguage)")
        let matchGitURL = request.profile.configuredMatchGitURL
            ?? effectiveEnvironment["MATCH_GIT_URL"]
            ?? ""
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
        try RuntimeSupport.writeFile(to: matchfilePath, content: matchfileTemplate(gitURL: matchGitURL))
        try RuntimeSupport.writeFile(to: metadataNotesPath, content: metadataTemplate(projectName: request.blueprint.project.name))

        let lanes: [String]
        do {
            lanes = try parseLanes(from: fastfilePath)
        } catch {
            let summary = "failed to parse lanes from \(fastfilePath.path(percentEncoded: false))"
            BosStateStore.updateSummary(
                projectRoot: root,
                kind: .release,
                status: "failed",
                message: summary
            )
            BosStateStore.updateReleaseInitState(
                projectRoot: root,
                status: "failed",
                summary: summary,
                artifactDirectory: nil,
                generatedFiles: [
                    fastfilePath.path(percentEncoded: false),
                    appfilePath.path(percentEncoded: false),
                    matchfilePath.path(percentEncoded: false),
                    metadataNotesPath.path(percentEncoded: false)
                ],
                lanes: []
            )
            throw error
        }

        let stamp = RuntimeSupport.timestamp()
        let bundle = try AdapterArtifacts.makeBundle(command: "release-init", projectRoot: root, stamp: stamp)
        let artifacts = bundle.artifacts

        let generatedFiles = [
            fastfilePath.path(percentEncoded: false),
            appfilePath.path(percentEncoded: false),
            matchfilePath.path(percentEncoded: false),
            metadataNotesPath.path(percentEncoded: false)
        ]

        try writeArtifact(
            bundle: bundle,
            profileName: request.profile.name,
            projectRoot: root.path(percentEncoded: false),
            generatedFiles: generatedFiles,
            lanes: lanes,
            artifacts: artifacts
        )
        BosStateStore.updateSummary(
            projectRoot: root,
            kind: .release,
            status: "success",
            message: "release-init completed"
        )
        BosStateStore.updateReleaseInitState(
            projectRoot: root,
            status: "success",
            summary: "release-init completed",
            artifactDirectory: bundle.directory.path(percentEncoded: false),
            generatedFiles: generatedFiles,
            lanes: lanes
        )

        return ReleaseInitResult(generatedFiles: generatedFiles, lanes: lanes, artifacts: artifacts)
    }
}

extension ReleaseInitEngine {
    private enum Constant {
        static let defaultLanes = ["auth_ping", "certs_readonly", "certs", "build", "beta", "release", "submit", "release_metadata"]
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
        require 'fileutils'

        platform :ios do
          private_lane :asc_api_key do
            app_store_connect_api_key(
              key_id: ENV["ASC_KEY_ID"],
              issuer_id: ENV["ASC_ISSUER_ID"],
              key_content: Base64.decode64(ENV["ASC_KEY_P8_BASE64"]),
              is_key_content_base64: false
            )
          end

          lane :auth_ping do
            api_key = asc_api_key
            token = Spaceship::ConnectAPI::Token.create(api_key)
            Spaceship::ConnectAPI.token = token
            apps = Spaceship::ConnectAPI::App.all(limit: 1)
            UI.message("App Store Connect auth ping succeeded (apps=#{apps.count})")
          end

          private_lane :build_output_directory do
            value = ENV["BOS_IPA_OUTPUT_DIR"].to_s.strip
            value.empty? ? "./.bos/build" : value
          end

          private_lane :build_output_name do
            value = ENV["BOS_IPA_OUTPUT_NAME"].to_s.strip
            value.empty? ? "app.ipa" : value
          end

          private_lane :release_automation_mode do
            value = ENV["BOS_RELEASE_AUTOMATION"].to_s.strip
            value.empty? ? "manual" : value
          end

          private_lane :submit_delivery_options do
            options = {
              api_key: asc_api_key,
              ipa: ENV["IPA_PATH"],
              submit_for_review: true
            }

            case release_automation_mode
            when "auto"
              options[:automatic_release] = true
              options[:phased_release] = false
            when "phased"
              options[:automatic_release] = false
              options[:phased_release] = true
            else
              options[:automatic_release] = false
              options[:phased_release] = false
            end

            options
          end

          private_lane :release_bundle_identifier do
            CredentialsManager::AppfileConfig.try_fetch_value(:app_identifier).to_s.strip
          end

          private_lane :release_team_id do
            CredentialsManager::AppfileConfig.try_fetch_value(:team_id).to_s.strip
          end

          private_lane :release_export_options do
            bundle_id = release_bundle_identifier
            team_id = release_team_id
            options = {
              method: "app-store",
              provisioningProfiles: {
                bundle_id => "match AppStore #{bundle_id}"
              }
            }
            options[:teamID] = team_id unless team_id.empty?
            options
          end

          lane :certs_readonly do
            sync_code_signing(type: "appstore", readonly: true, api_key: asc_api_key)
          end

          lane :certs do
            sync_code_signing(type: "appstore", readonly: false, api_key: asc_api_key)
          end

          lane :build do
            output_directory = build_output_directory
            output_name = build_output_name
            FileUtils.mkdir_p(output_directory)
            build_app(
              workspace: ENV["BOS_WORKSPACE_PATH"],
              scheme: ENV["BOS_SCHEME"],
              export_method: "app-store",
              export_options: release_export_options,
              output_directory: output_directory,
              output_name: output_name
            )
            UI.message("BOS_IPA_PATH=#{File.expand_path(File.join(output_directory, output_name))}")
          end

          lane :beta do
            api_key = asc_api_key
            pilot(api_key: api_key, ipa: ENV["IPA_PATH"], skip_waiting_for_build_processing: true)
          end

          lane :release do
            api_key = asc_api_key
            deliver(api_key: api_key, ipa: ENV["IPA_PATH"], submit_for_review: false)
          end

          lane :submit do
            deliver(submit_delivery_options)
          end

          lane :release_metadata do
            api_key = asc_api_key
            deliver(api_key: api_key, skip_binary_upload: true, skip_screenshots: true, submit_for_review: false)
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

    private func matchfileTemplate(gitURL: String) -> String {
        """
        git_url("\(gitURL)")
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
        bundle: AdapterArtifactBundle,
        profileName: String,
        projectRoot: String,
        generatedFiles: [String],
        lanes: [String],
        artifacts: [String]
    ) throws {
        let stdout: String = [
            "# bos release-init",
            "profile=\(profileName)",
            "projectRoot=\(projectRoot)",
            "requiredEnvChecked=\(SigningEnvironmentPolicy.requiredKeys.joined(separator: ","))",
            "generatedFiles=",
            generatedFiles.map { "- \($0)" }.joined(separator: "\n"),
            "lanes=\(lanes.joined(separator: ","))",
            ""
        ].joined(separator: "\n")

        _ = try AdapterArtifacts.write(
            bundle: bundle,
            envelope: AdapterRunEnvelope(
                command: "release-init",
                status: "success",
                exitCode: 0,
                summary: "Fastlane scaffold generated and lanes parsed",
                payload: ArtifactPayload(
                    command: "release-init",
                    status: "success",
                    exitCode: 0,
                    summary: "Fastlane scaffold generated and lanes parsed",
                    lanes: lanes,
                    generatedFiles: generatedFiles,
                    artifacts: artifacts
                )
            ),
            stdout: stdout,
            stderr: ""
        )
    }
}
