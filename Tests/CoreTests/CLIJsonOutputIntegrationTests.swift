import Foundation
import XCTest
@testable import BosCore

final class CLIJsonOutputIntegrationTests: XCTestCase {
    // Contract intent: malformed CLI options must fail fast with parseable JSON
    // without touching external tools.
    func testCommandsReturnParseableJSONOnContractErrors() throws {
        let cases: [(command: String, args: [String])] = [
            ("doctor", ["doctor", "--project-root", "--format", "json"]),
            ("plan", ["plan", "--prd", "--format", "json"]),
            ("apply", ["apply", "--blueprint", "--format", "json"]),
            ("verify", ["verify", "--project-root", "--format", "json"]),
            ("release-init", ["release-init", "--blueprint", "--format", "json"])
        ]

        for item in cases {
            let result = try runBootstrap(args: item.args, timeoutSeconds: 10)
            XCTAssertEqual(result.status, 2, "unexpected exit for command=\(item.command)")
            let payload = try JSONDecoder().decode(CommandOutputV1.self, from: Data(result.stdout.utf8))
            XCTAssertEqual(payload.command, item.command)
            XCTAssertEqual(payload.status, "failed")
            XCTAssertEqual(payload.exitCode, 2)
        }
    }

    func testDoctorRejectsLegacyInstallFlag() throws {
        let result = try runBootstrap(args: ["doctor", "--install", "--format", "json"], timeoutSeconds: 10)
        XCTAssertEqual(result.status, 2)
        let payload = try JSONDecoder().decode(CommandOutputV1.self, from: Data(result.stdout.utf8))
        XCTAssertEqual(payload.command, "doctor")
        XCTAssertEqual(payload.status, "failed")
        XCTAssertEqual(payload.exitCode, 2)
        XCTAssertTrue(payload.summary.contains("unknown flag(s): --install"))
    }

    // Behavior intent: verify execution failure must still return parseable JSON
    // with verify-specific failure code and summary.
    func testVerifyReturnsParseableJSONOnExecutionFailure() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let result = try runBootstrap(
            args: [
                "verify",
                "--project-root", root.path(percentEncoded: false),
                "--format", "json"
            ],
            cwd: root,
            environment: ["PATH": "/nonexistent"],
            timeoutSeconds: 20
        )
        XCTAssertEqual(result.status, 4)

        let payload = try JSONDecoder().decode(CommandOutputV1.self, from: Data(result.stdout.utf8))
        XCTAssertEqual(payload.command, "verify")
        XCTAssertEqual(payload.status, "failed")
        XCTAssertEqual(payload.exitCode, 4)
        XCTAssertTrue(payload.summary.contains("verify failed at"))
    }

    func testReleaseInitReturnsParseableJSONOnInvalidEnvironmentFormat() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let prd = root.appending(path: "PRD.md")
        try Data(
            """
            Project: Daycraft
            App Identifier: com.axiomorient.daycraft
            Apple Team ID: A1B2C3D4E5

            Requirements
            - REQ-001 홈 화면 진입

            Screens
            - SCR_TODAY_HOME

            Entities
            - Entity: User
            """.utf8
        ).write(to: prd, options: .atomic)

        let planResult = try runBootstrap(
            args: [
                "plan",
                "--project-root", root.path(percentEncoded: false),
                "--prd", "PRD.md",
                "--format", "json"
            ],
            cwd: root
        )
        XCTAssertEqual(planResult.status, 0)

        let releaseInitResult = try runBootstrap(
            args: [
                "release-init",
                "--project-root", root.path(percentEncoded: false),
                "--blueprint", ".bos/plan/blueprint.yaml",
                "--format", "json"
            ],
            cwd: root,
            environment: [
                "ASC_ISSUER_ID": "issuer-id",
                "ASC_KEY_ID": "bad",
                "ASC_KEY_P8_BASE64": "not-base64",
                "MATCH_GIT_URL": "ftp://example.com/repo",
                "MATCH_PASSWORD": "secret"
            ]
        )
        XCTAssertEqual(releaseInitResult.status, 5)

        let payload = try JSONDecoder().decode(CommandOutputV1.self, from: Data(releaseInitResult.stdout.utf8))
        XCTAssertEqual(payload.command, "release-init")
        XCTAssertEqual(payload.status, "failed")
        XCTAssertEqual(payload.exitCode, 5)
        XCTAssertTrue(payload.summary.contains("invalid environment format"))
    }

    func testReleaseInitReadsSigningEnvironmentFromDefaultFile() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let prd = root.appending(path: "PRD.md")
        let signingEnv = root.appending(path: ".bos/config/signing.env")
        try Data(
            """
            Project: Daycraft
            App Identifier: com.axiomorient.daycraft
            Apple Team ID: A1B2C3D4E5

            Requirements
            - REQ-001 홈 화면 진입

            Screens
            - SCR_TODAY_HOME

            Entities
            - Entity: User
            """.utf8
        ).write(to: prd, options: .atomic)

        try FileManager.default.createDirectory(at: signingEnv.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(
            """
            ASC_ISSUER_ID=123E4567-E89B-12D3-A456-426614174000
            ASC_KEY_ID=AB12CD34EF
            ASC_KEY_P8_BASE64=c3VwZXItc2VjcmV0
            MATCH_GIT_URL=git@github.com:org/certs.git
            MATCH_PASSWORD=match-secret
            """.utf8
        ).write(to: signingEnv, options: .atomic)

        let planResult = try runBootstrap(
            args: [
                "plan",
                "--project-root", root.path(percentEncoded: false),
                "--prd", "PRD.md",
                "--format", "json"
            ],
            cwd: root
        )
        XCTAssertEqual(planResult.status, 0)

        let releaseInitResult = try runBootstrap(
            args: [
                "release-init",
                "--project-root", root.path(percentEncoded: false),
                "--blueprint", ".bos/plan/blueprint.yaml",
                "--format", "json"
            ],
            cwd: root,
            environment: [
                "BOS_AUTO_INSTALL": "0",
                "ASC_ISSUER_ID": "",
                "ASC_KEY_ID": "",
                "ASC_KEY_P8_BASE64": "",
                "MATCH_GIT_URL": "",
                "MATCH_PASSWORD": ""
            ]
        )
        XCTAssertEqual(releaseInitResult.status, 0)
    }

    func testPlanSupportsPlanDirectoryInputWithMetadataOverrides() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let planDir = root.appending(path: "PLAN")
        let profile = root.appending(path: ".bos/config/profile.yaml")
        let blueprint = root.appending(path: ".bos/plan/blueprint.yaml")

        try FileManager.default.createDirectory(at: planDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: profile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(
            """
            # Aether v4 Master Spec

            ## 8. 화면 명세
            - Today
            - Shelf
            - Capture
            - Review
            - Focus
            - Reflection
            - Weekly Review
            - Settings

            ## 11. 도메인 모델
            ### 11.1 Item
            ### 11.2 DraftItem
            ### 11.3 FocusSession
            ### 11.4 ReflectionRecord
            ### 11.5 SpeechCaptureSession

            ## 12. 기능 요구사항
            FR-001 입력
            FR-002 정리
            FR-010 음성 fallback
            """.utf8
        ).write(to: planDir.appending(path: "03_Master_Spec.md"), options: .atomic)

        try Data(
            """
            schemaVersion: 1
            name: aether
            defaults:
              deploymentTarget: "18.0"
              appTargets:
                controlsExtension: true
                uiTests: true
            featurePattern:
              sourcesInterface: true
              designFolder: true
            rules:
              testingStyle: swift-testing
              forbidPatterns:
                - "@unchecked Sendable"
                - "Date()"
                - "UUID()"
            """.utf8
        ).write(to: profile, options: .atomic)

        let planResult = try runBootstrap(
            args: [
                "plan",
                "--project-root", root.path(percentEncoded: false),
                "--plan-dir", "PLAN",
                "--out", ".bos/plan/blueprint.yaml",
                "--app-identifier", "com.axient.aether",
                "--apple-team-id", "A1B2C3D4E5",
                "--format", "json"
            ],
            cwd: root
        )
        XCTAssertEqual(planResult.status, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: blueprint.path(percentEncoded: false)))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appending(path: "profile.yaml").path(percentEncoded: false)))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appending(path: "prd.md").path(percentEncoded: false)))

        let blueprintText = try String(contentsOf: blueprint, encoding: .utf8)
        XCTAssertTrue(blueprintText.contains("REQ-001"))
        XCTAssertTrue(blueprintText.contains("SCR_WEEKLY_REVIEW"))
        XCTAssertTrue(blueprintText.contains("- DraftItem"))
        XCTAssertTrue(blueprintText.contains("- FocusSession"))
        XCTAssertTrue(blueprintText.contains("- SpeechCaptureSession"))

        let applyResult = try runBootstrap(
            args: [
                "apply",
                "--project-root", root.path(percentEncoded: false),
                "--blueprint", ".bos/plan/blueprint.yaml",
                "--mode", "init",
                "--format", "json"
            ],
            cwd: root
        )
        XCTAssertEqual(applyResult.status, 0)

        let releaseInitResult = try runBootstrap(
            args: [
                "release-init",
                "--project-root", root.path(percentEncoded: false),
                "--blueprint", ".bos/plan/blueprint.yaml",
                "--format", "json"
            ],
            cwd: root,
            environment: [
                "ASC_ISSUER_ID": "123E4567-E89B-12D3-A456-426614174000",
                "ASC_KEY_ID": "AB12CD34EF",
                "ASC_KEY_P8_BASE64": "c3VwZXItc2VjcmV0",
                "MATCH_GIT_URL": "git@github.com:org/certs.git",
                "MATCH_PASSWORD": "secret"
            ]
        )
        XCTAssertEqual(releaseInitResult.status, 0)
    }

    func testPlanApplyAndReleaseInitRunInTemporaryWorkspace() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let prd = root.appending(path: "PRD.md")
        let profile = root.appending(path: "profile.yaml")
        let blueprint = root.appending(path: ".bos/plan/blueprint.yaml")

        try Data(
            """
            Project: Daycraft
            App Identifier: com.axiomorient.daycraft
            Apple Team ID: A1B2C3D4E5

            Requirements
            - REQ-001 홈 화면 진입
            - REQ-002 채팅 화면 진입

            Screens
            - SCR_TODAY_HOME
            - SCR_CHAT_THREAD

            Entities
            - Entity: User
            - Entity: Routine
            - Entity: Session
            """.utf8
        ).write(to: prd, options: .atomic)

        try Data(
            """
            schemaVersion: 1
            name: daycraft
            defaults:
              deploymentTarget: "18.0"
              appTargets:
                controlsExtension: true
                uiTests: true
            featurePattern:
              sourcesInterface: true
              designFolder: true
            rules:
              testingStyle: swift-testing
              forbidPatterns:
                - "@unchecked Sendable"
                - "Date()"
                - "UUID()"
            """.utf8
        ).write(to: profile, options: .atomic)

        let planResult = try runBootstrap(
            args: [
                "plan",
                "--project-root", root.path(percentEncoded: false),
                "--prd", "PRD.md",
                "--profile", "profile.yaml",
                "--out", ".bos/plan/blueprint.yaml",
                "--format", "json"
            ],
            cwd: root
        )
        XCTAssertEqual(planResult.status, 0)
        let planPayload = try JSONDecoder().decode(CommandOutputV1.self, from: Data(planResult.stdout.utf8))
        XCTAssertEqual(planPayload.command, "plan")
        XCTAssertEqual(planPayload.status, "success")
        XCTAssertTrue(FileManager.default.fileExists(atPath: blueprint.path(percentEncoded: false)))

        let applyResult = try runBootstrap(
            args: [
                "apply",
                "--project-root", root.path(percentEncoded: false),
                "--blueprint", ".bos/plan/blueprint.yaml",
                "--profile", "profile.yaml",
                "--mode", "init",
                "--format", "json"
            ],
            cwd: root
        )
        XCTAssertEqual(applyResult.status, 0)
        let applyPayload = try JSONDecoder().decode(CommandOutputV1.self, from: Data(applyResult.stdout.utf8))
        XCTAssertEqual(applyPayload.command, "apply")
        XCTAssertEqual(applyPayload.status, "success")
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: root.appending(path: "Projects/App/Sources/Dependencies/AppComposition.swift").path(percentEncoded: false)
            )
        )

        let dryRunResult = try runBootstrap(
            args: [
                "apply",
                "--project-root", root.path(percentEncoded: false),
                "--blueprint", ".bos/plan/blueprint.yaml",
                "--profile", "profile.yaml",
                "--mode", "incremental",
                "--dry-run",
                "--format", "json"
            ],
            cwd: root
        )
        XCTAssertEqual(dryRunResult.status, 0)
        let dryRunPayload = try JSONDecoder().decode(CommandOutputV1.self, from: Data(dryRunResult.stdout.utf8))
        XCTAssertEqual(dryRunPayload.command, "apply")
        XCTAssertEqual(dryRunPayload.status, "success")

        let releaseInitResult = try runBootstrap(
            args: [
                "release-init",
                "--project-root", root.path(percentEncoded: false),
                "--blueprint", ".bos/plan/blueprint.yaml",
                "--profile", "profile.yaml",
                "--format", "json"
            ],
            cwd: root,
            environment: [
                "ASC_ISSUER_ID": "123E4567-E89B-12D3-A456-426614174000",
                "ASC_KEY_ID": "AB12CD34EF",
                "ASC_KEY_P8_BASE64": "c3VwZXItc2VjcmV0",
                "MATCH_GIT_URL": "git@github.com:org/certs.git",
                "MATCH_PASSWORD": "secret"
            ]
        )
        XCTAssertEqual(releaseInitResult.status, 0)
        let releasePayload = try JSONDecoder().decode(CommandOutputV1.self, from: Data(releaseInitResult.stdout.utf8))
        XCTAssertEqual(releasePayload.command, "release-init")
        XCTAssertEqual(releasePayload.status, "success")
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: root.appending(path: "fastlane/Fastfile").path(percentEncoded: false)
            )
        )
    }

    func testDoctorJSONIncludesFindingsAndScope() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let lockPath = root.appending(path: "config/toolchain.lock.yaml")
        try FileManager.default.createDirectory(at: lockPath.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(
            """
            schemaVersion: 2
            tools:
              swift:
                versionRule:
                  kind: semver-range
                  value: ">=6.0 <7.0"
                requiredFor: [plan, apply, verify, release-init]
                installHints:
                  - xcode-select --install
                  - brew install swift
              tuist:
                versionRule:
                  kind: semver-range
                  value: ">=4.0 <5.0"
                requiredFor: [apply, verify]
                installHints:
                  - brew install tuist
              fastlane:
                versionRule:
                  kind: semver-range
                  value: ">=2.0 <3.0"
                requiredFor: [release-init]
                installHints:
                  - brew install fastlane
                  - gem install fastlane -NV
            tmaPluginRef:
              type: git-sha
              value: unknown
            """.utf8
        ).write(to: lockPath, options: .atomic)

        let result = try runBootstrap(
            args: [
                "doctor",
                "--project-root", root.path(percentEncoded: false),
                "--for", "core",
                "--format", "json"
            ],
            cwd: root
        )
        XCTAssertEqual(result.status, 0)

        let payload = try JSONDecoder().decode(DoctorCommandPayload.self, from: Data(result.stdout.utf8))
        XCTAssertEqual(payload.command, "doctor")
        XCTAssertEqual(payload.status, "success")
        XCTAssertEqual(payload.scope, "core")
        XCTAssertFalse(payload.findings.isEmpty)

        let fastlane = try XCTUnwrap(payload.findings.first(where: { $0.tool == "fastlane" }))
        XCTAssertEqual(fastlane.severity, "recommended")
        XCTAssertFalse(fastlane.action.isEmpty)
        XCTAssertFalse(fastlane.installCommands.isEmpty)
    }

    func testDoctorInitLockCreatesDefaultPolicy() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let result = try runBootstrap(
            args: [
                "doctor",
                "--project-root", root.path(percentEncoded: false),
                "--for", "core",
                "--format", "json"
            ],
            cwd: root
        )
        XCTAssertEqual(result.status, 0)

        let generated = root.appending(path: "config/toolchain.lock.yaml")
        XCTAssertTrue(FileManager.default.fileExists(atPath: generated.path(percentEncoded: false)))

        let content = try String(contentsOf: generated, encoding: .utf8)
        XCTAssertTrue(content.contains("schemaVersion: 2"))
        XCTAssertTrue(content.contains("requiredFor"))
    }

    func testDoctorIgnoresDeprecatedLockPathAndInitializesConfigLock() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let deprecatedPath = root.appending(path: ".bos/config/toolchain.lock.yaml")
        let preferredPath = root.appending(path: "config/toolchain.lock.yaml")
        try FileManager.default.createDirectory(at: deprecatedPath.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(
            """
            schemaVersion: 2
            tools:
              swift:
                versionRule:
                  kind: exact
                  value: "0.0.0"
                requiredFor: [plan, apply, verify, release-init]
                installHints:
                  - xcode-select --install
              tuist:
                versionRule:
                  kind: semver-range
                  value: ">=4.0 <5.0"
                requiredFor: [apply, verify]
                installHints:
                  - brew install tuist
              fastlane:
                versionRule:
                  kind: semver-range
                  value: ">=2.0 <3.0"
                requiredFor: [release-init]
                installHints:
                  - brew install fastlane
            tmaPluginRef:
              type: git-sha
              value: unknown
            """.utf8
        ).write(to: deprecatedPath, options: .atomic)

        let result = try runBootstrap(
            args: [
                "doctor",
                "--project-root", root.path(percentEncoded: false),
                "--for", "core",
                "--format", "json"
            ],
            cwd: root
        )
        XCTAssertNotEqual(result.status, 2)
        XCTAssertTrue(FileManager.default.fileExists(atPath: preferredPath.path(percentEncoded: false)))
        XCTAssertTrue(FileManager.default.fileExists(atPath: deprecatedPath.path(percentEncoded: false)))

        let preferredContent = try String(contentsOf: preferredPath, encoding: .utf8)
        XCTAssertTrue(preferredContent.contains("schemaVersion: 2"))
        XCTAssertFalse(preferredContent.contains("value: \"0.0.0\""))
    }

    func testDoctorAutoInstallReportsSkippedWhenInstallerIsUnavailable() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let lockPath = root.appending(path: "config/toolchain.lock.yaml")
        try FileManager.default.createDirectory(at: lockPath.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(
            """
            schemaVersion: 2
            tools:
              swift:
                versionRule:
                  kind: semver-range
                  value: ">=6.0 <7.0"
                requiredFor: [plan, apply, verify, release-init]
                installHints:
                  - xcode-select --install
              tuist:
                versionRule:
                  kind: exact
                  value: "0.0.0"
                requiredFor: [apply, verify]
                installHints:
                  - no-such-installer tuist
              fastlane:
                versionRule:
                  kind: semver-range
                  value: ">=2.0 <3.0"
                requiredFor: [release-init]
                installHints:
                  - no-such-installer fastlane
            tmaPluginRef:
              type: git-sha
              value: unknown
            """.utf8
        ).write(to: lockPath, options: .atomic)

        let result = try runBootstrap(
            args: [
                "doctor",
                "--project-root", root.path(percentEncoded: false),
                "--for", "core",
                "--format", "json"
            ],
            cwd: root
        )
        XCTAssertEqual(result.status, 6)

        let payload = try JSONDecoder().decode(DoctorCommandPayload.self, from: Data(result.stdout.utf8))
        XCTAssertEqual(payload.command, "doctor")
        XCTAssertEqual(payload.status, "failed")
        XCTAssertTrue(payload.installAttempts.contains(where: { $0.tool == "tuist" && $0.status == "skipped-no-runner" }))
    }

    func testDoctorDefaultsToReleaseInitAndCreatesSigningEnvTemplate() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let signingPath = root.appending(path: ".bos/config/signing.env")
        let result = try runBootstrap(
            args: [
                "doctor",
                "--project-root", root.path(percentEncoded: false),
                "--format", "json"
            ],
            cwd: root,
            environment: [
                "ASC_ISSUER_ID": "",
                "ASC_KEY_ID": "",
                "ASC_KEY_P8_BASE64": "",
                "MATCH_GIT_URL": "",
                "MATCH_PASSWORD": ""
            ]
        )

        XCTAssertEqual(result.status, 6)
        XCTAssertTrue(FileManager.default.fileExists(atPath: signingPath.path(percentEncoded: false)))
        let permissions = try FileManager.default
            .attributesOfItem(atPath: signingPath.path(percentEncoded: false))[.posixPermissions] as? NSNumber
        XCTAssertEqual(permissions?.intValue, Int(0o600))

        let payload = try JSONDecoder().decode(DoctorCommandPayload.self, from: Data(result.stdout.utf8))
        XCTAssertEqual(payload.scope, "release-init")
        XCTAssertTrue(payload.findings.contains(where: { $0.tool == "signing-env" && $0.severity == "required" }))
        XCTAssertTrue(payload.artifacts.allSatisfy { $0.contains("/.bos/artifacts/doctor/") })
    }

    func testDoctorUsesProjectScopedArtifactDirectory() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let result = try runBootstrap(
            args: [
                "doctor",
                "--project-root", root.path(percentEncoded: false),
                "--for", "core",
                "--format", "json"
            ],
            cwd: root
        )
        XCTAssertEqual(result.status, 0)

        let payload = try JSONDecoder().decode(DoctorCommandPayload.self, from: Data(result.stdout.utf8))
        XCTAssertFalse(payload.artifacts.isEmpty)
        let expectedPrefix = root
            .standardizedFileURL
            .appending(path: ".bos/artifacts/doctor")
            .path(percentEncoded: false)
        XCTAssertTrue(
            payload.artifacts.allSatisfy { artifact in
                URL(fileURLWithPath: artifact).standardizedFileURL.path(percentEncoded: false)
                    .hasPrefix(expectedPrefix + "/")
            }
        )
    }

    func testDoctorReportsDoctorFailureCodeOnInvalidSigningEnvironmentSyntax() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let signingPath = root.appending(path: ".bos/config/signing.env")
        try FileManager.default.createDirectory(at: signingPath.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(
            """
            ASC_ISSUER_ID=123E4567-E89B-12D3-A456-426614174000
            BROKEN_LINE
            """.utf8
        ).write(to: signingPath, options: .atomic)

        let result = try runBootstrap(
            args: [
                "doctor",
                "--project-root", root.path(percentEncoded: false),
                "--format", "json"
            ],
            cwd: root
        )
        XCTAssertEqual(result.status, 6)

        let payload = try JSONDecoder().decode(CommandOutputV1.self, from: Data(result.stdout.utf8))
        XCTAssertEqual(payload.command, "doctor")
        XCTAssertEqual(payload.exitCode, 6)
        XCTAssertTrue(payload.summary.contains("invalid signing env in"))
        XCTAssertTrue(payload.summary.contains("line 2"))
    }

    func testDoctorReportsAccurateLineNumberWithCommentsAndBlankLines() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let signingPath = root.appending(path: ".bos/config/signing.env")
        try FileManager.default.createDirectory(at: signingPath.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(
            """
            # comment

            ASC_ISSUER_ID=123E4567-E89B-12D3-A456-426614174000

            BROKEN_LINE
            """.utf8
        ).write(to: signingPath, options: .atomic)

        let result = try runBootstrap(
            args: [
                "doctor",
                "--project-root", root.path(percentEncoded: false),
                "--format", "json"
            ],
            cwd: root
        )
        XCTAssertEqual(result.status, 6)

        let payload = try JSONDecoder().decode(CommandOutputV1.self, from: Data(result.stdout.utf8))
        XCTAssertEqual(payload.command, "doctor")
        XCTAssertEqual(payload.exitCode, 6)
        XCTAssertTrue(payload.summary.contains("line 5"))
    }

    func testDoctorRetainsArtifactsAcrossRuns() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let first = try runBootstrap(
            args: [
                "doctor",
                "--project-root", root.path(percentEncoded: false),
                "--for", "core",
                "--format", "json"
            ],
            cwd: root
        )
        XCTAssertEqual(first.status, 0)
        let firstPayload = try JSONDecoder().decode(DoctorCommandPayload.self, from: Data(first.stdout.utf8))

        Thread.sleep(forTimeInterval: 1.1)

        let second = try runBootstrap(
            args: [
                "doctor",
                "--project-root", root.path(percentEncoded: false),
                "--for", "core",
                "--format", "json"
            ],
            cwd: root
        )
        XCTAssertEqual(second.status, 0)
        let secondPayload = try JSONDecoder().decode(DoctorCommandPayload.self, from: Data(second.stdout.utf8))

        for artifact in firstPayload.artifacts + secondPayload.artifacts {
            XCTAssertTrue(FileManager.default.fileExists(atPath: artifact))
        }
    }

    func testReleaseInitReportsReleaseFailureCodeOnInvalidSigningEnvironmentSyntax() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let prd = root.appending(path: "PRD.md")
        try Data(
            """
            Project: Daycraft
            App Identifier: com.axiomorient.daycraft
            Apple Team ID: A1B2C3D4E5

            Requirements
            - REQ-001 홈 화면 진입

            Screens
            - SCR_TODAY_HOME

            Entities
            - Entity: User
            """.utf8
        ).write(to: prd, options: .atomic)

        let planResult = try runBootstrap(
            args: [
                "plan",
                "--project-root", root.path(percentEncoded: false),
                "--prd", "PRD.md",
                "--format", "json"
            ],
            cwd: root
        )
        XCTAssertEqual(planResult.status, 0)

        let signingPath = root.appending(path: ".bos/config/signing.env")
        try FileManager.default.createDirectory(at: signingPath.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(
            """
            ASC_ISSUER_ID=123E4567-E89B-12D3-A456-426614174000
            BROKEN_LINE
            """.utf8
        ).write(to: signingPath, options: .atomic)

        let result = try runBootstrap(
            args: [
                "release-init",
                "--project-root", root.path(percentEncoded: false),
                "--blueprint", ".bos/plan/blueprint.yaml",
                "--format", "json"
            ],
            cwd: root
        )
        XCTAssertEqual(result.status, 5)

        let payload = try JSONDecoder().decode(CommandOutputV1.self, from: Data(result.stdout.utf8))
        XCTAssertEqual(payload.command, "release-init")
        XCTAssertEqual(payload.exitCode, 5)
        XCTAssertTrue(payload.summary.contains("invalid signing env in"))
        XCTAssertTrue(payload.summary.contains("line 2"))
    }
}

private extension CLIJsonOutputIntegrationTests {
    struct DoctorCommandPayload: Decodable {
        struct Finding: Decodable {
            let tool: String
            let severity: String
            let action: String
            let installCommands: [String]
        }

        struct InstallAttempt: Decodable {
            let tool: String
            let status: String
        }

        let command: String
        let status: String
        let scope: String
        let findings: [Finding]
        let installAttempts: [InstallAttempt]
        let artifacts: [String]
    }

    struct ProcessResult {
        let status: Int32
        let stdout: String
        let stderr: String
    }

    func runBootstrap(
        args: [String],
        cwd: URL? = nil,
        environment: [String: String] = [:],
        timeoutSeconds: TimeInterval = 60
    ) throws -> ProcessResult {
        let fm = FileManager.default
        let process = Process()
        process.executableURL = try bootstrapBinaryURL()
        process.arguments = args
        process.currentDirectoryURL = cwd ?? repositoryRoot()
        process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }

        let captureDir = fm.temporaryDirectory
            .appendingPathComponent("bos-cli-capture-\(ProcessInfo.processInfo.globallyUniqueString)", isDirectory: true)
        let stdoutPath = captureDir.appending(path: "stdout.log")
        let stderrPath = captureDir.appending(path: "stderr.log")
        try fm.createDirectory(at: captureDir, withIntermediateDirectories: true)
        fm.createFile(atPath: stdoutPath.path(percentEncoded: false), contents: nil)
        fm.createFile(atPath: stderrPath.path(percentEncoded: false), contents: nil)

        let stdoutHandle = try FileHandle(forWritingTo: stdoutPath)
        let stderrHandle = try FileHandle(forWritingTo: stderrPath)
        defer {
            try? stdoutHandle.close()
            try? stderrHandle.close()
            try? fm.removeItem(at: captureDir)
        }
        process.standardOutput = stdoutHandle
        process.standardError = stderrHandle

        try process.run()
        let exited = waitForExit(process, timeoutSeconds: timeoutSeconds)
        if !exited {
            if process.isRunning {
                process.terminate()
            }
            _ = waitForExit(process, timeoutSeconds: 2)
            if process.isRunning {
                process.interrupt()
            }
            _ = waitForExit(process, timeoutSeconds: 2)
            throw NSError(
                domain: "CLIJsonOutputIntegrationTests",
                code: 2,
                userInfo: [
                    NSLocalizedDescriptionKey: "process timeout (\(Int(timeoutSeconds))s): bos \(args.joined(separator: " "))"
                ]
            )
        }

        try stdoutHandle.close()
        try stderrHandle.close()

        let stdoutData = try Data(contentsOf: stdoutPath)
        let stderrData = try Data(contentsOf: stderrPath)
        let stdout = String(decoding: stdoutData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        let stderr = String(decoding: stderrData, as: UTF8.self)

        return ProcessResult(status: process.terminationStatus, stdout: stdout, stderr: stderr)
    }

    func waitForExit(_ process: Process, timeoutSeconds: TimeInterval) -> Bool {
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            process.waitUntilExit()
            group.leave()
        }
        return group.wait(timeout: .now() + timeoutSeconds) == .success
    }

    func makeTempDir() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("bos-cli-e2e-\(ProcessInfo.processInfo.globallyUniqueString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    func bootstrapBinaryURL() throws -> URL {
        let candidate = productsDirectory().appending(path: "bos")
        guard FileManager.default.isExecutableFile(atPath: candidate.path(percentEncoded: false)) else {
            throw NSError(domain: "CLIJsonOutputIntegrationTests", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "bos binary not found at \(candidate.path(percentEncoded: false))"
            ])
        }
        return candidate
    }

    func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func productsDirectory() -> URL {
        #if os(macOS)
        for bundle in Bundle.allBundles where bundle.bundlePath.hasSuffix(".xctest") {
            return bundle.bundleURL.deletingLastPathComponent()
        }
        #endif
        return Bundle.main.bundleURL
    }
}
