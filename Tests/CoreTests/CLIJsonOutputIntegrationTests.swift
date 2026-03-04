import Foundation
import XCTest
@testable import BosCore

final class CLIJsonOutputIntegrationTests: XCTestCase {
    func testCommandsReturnParseableJSONOnContractErrors() throws {
        let cases: [(command: String, args: [String])] = [
            ("doctor", ["doctor", "--project-root", "--format", "json"]),
            ("plan", ["plan", "--format", "json"]),
            ("apply", ["apply", "--format", "json"]),
            ("verify", ["verify", "--format", "json"]),
            ("release-init", ["release-init", "--format", "json"])
        ]

        for item in cases {
            let result = try runBootstrap(args: item.args)
            XCTAssertEqual(result.status, 2, "unexpected exit for command=\(item.command)")
            let payload = try JSONDecoder().decode(CommandOutputV1.self, from: Data(result.stdout.utf8))
            XCTAssertEqual(payload.command, item.command)
            XCTAssertEqual(payload.status, "failed")
            XCTAssertEqual(payload.exitCode, 2)
        }
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
                "ASC_ISSUER_ID": "issuer-id",
                "ASC_KEY_ID": "key-id",
                "ASC_KEY_P8_BASE64": "key-base64",
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
                "ASC_ISSUER_ID": "issuer-id",
                "ASC_KEY_ID": "key-id",
                "ASC_KEY_P8_BASE64": "key-base64",
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

        let lockPath = root.appending(path: ".bos/config/toolchain.lock.yaml")
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
                "--init-lock",
                "--format", "json"
            ],
            cwd: root
        )
        XCTAssertEqual(result.status, 0)

        let generated = root.appending(path: ".bos/config/toolchain.lock.yaml")
        XCTAssertTrue(FileManager.default.fileExists(atPath: generated.path(percentEncoded: false)))

        let content = try String(contentsOf: generated, encoding: .utf8)
        XCTAssertTrue(content.contains("schemaVersion: 2"))
        XCTAssertTrue(content.contains("requiredFor"))
    }

    func testDoctorInstallFlagReportsSkippedWhenInstallerIsUnavailable() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let lockPath = root.appending(path: ".bos/config/toolchain.lock.yaml")
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
                "--install",
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
    }

    struct ProcessResult {
        let status: Int32
        let stdout: String
        let stderr: String
    }

    func runBootstrap(
        args: [String],
        cwd: URL? = nil,
        environment: [String: String] = [:]
    ) throws -> ProcessResult {
        let process = Process()
        process.executableURL = try bootstrapBinaryURL()
        process.arguments = args
        process.currentDirectoryURL = cwd ?? repositoryRoot()
        process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stdout = String(decoding: stdoutData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        let stderr = String(decoding: stderrData, as: UTF8.self)

        return ProcessResult(status: process.terminationStatus, stdout: stdout, stderr: stderr)
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
