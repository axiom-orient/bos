import Foundation
import Testing
@testable import BosCore

@Suite
struct DoctorEngineIntegrationTests {
    private let engine = DoctorEngine()

    @Test func doctorCoreScopeDoesNotBlockMissingFastlane() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let lock = try makePolicy(
            swiftRule: .init(kind: "semver-range", value: ">=6.0 <7.0"),
            tuistRule: .init(kind: "semver-range", value: ">=4.0 <5.0"),
            fastlaneRule: .init(kind: "semver-range", value: ">=2.0 <3.0"),
            ascRule: .init(kind: "semver-range", value: ">=0.1.0"),
            swiftRequiredFor: ToolchainLock.allCommands,
            tuistRequiredFor: [ToolchainLock.commandApply, ToolchainLock.commandVerify],
            fastlaneRequiredFor: [ToolchainLock.commandReleaseInit],
            ascRequiredFor: [ToolchainLock.commandAppRegister, ToolchainLock.commandReleaseCheck, ToolchainLock.commandReleaseRun]
        )

        let detected = DetectedToolchain(
            swift: "6.2",
            tuist: "4.153.1",
            fastlane: "not-found",
            tmaPluginRef: try .init(type: "git-sha", value: "abc"),
            brewPath: "/opt/homebrew/bin/brew"
        )

        let result = try engine.check(
            request: DoctorRequest(
                projectRoot: root,
                lock: lock,
                detected: detected,
                checkCommands: ToolchainLock.coreCommands
            )
        )

        #expect(result.status == "success")
        #expect(result.exitCode == 0)

        let fastlane = try #require(result.findings.first(where: { $0.tool == "fastlane" }))
        #expect(fastlane.severity == .recommended)
        #expect(fastlane.status == .missing)
    }

    @Test func doctorFailsWhenRequiredToolMissingForScope() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let lock = try makePolicy(
            swiftRule: .init(kind: "semver-range", value: ">=6.0 <7.0"),
            tuistRule: .init(kind: "semver-range", value: ">=4.0 <5.0"),
            fastlaneRule: .init(kind: "semver-range", value: ">=2.0 <3.0"),
            ascRule: .init(kind: "semver-range", value: ">=0.1.0"),
            swiftRequiredFor: ToolchainLock.allCommands,
            tuistRequiredFor: [ToolchainLock.commandApply, ToolchainLock.commandVerify],
            fastlaneRequiredFor: [ToolchainLock.commandReleaseInit],
            ascRequiredFor: [ToolchainLock.commandAppRegister, ToolchainLock.commandReleaseCheck, ToolchainLock.commandReleaseRun]
        )

        let detected = DetectedToolchain(
            swift: "6.2",
            tuist: "not-found",
            fastlane: "not-found",
            tmaPluginRef: try .init(type: "git-sha", value: "abc")
        )

        let result = try engine.check(
            request: DoctorRequest(
                projectRoot: root,
                lock: lock,
                detected: detected,
                checkCommands: ToolchainLock.coreCommands
            )
        )

        #expect(result.status == "failed")
        #expect(result.exitCode == 6)

        let tuist = try #require(result.findings.first(where: { $0.tool == "tuist" }))
        #expect(tuist.severity == .required)
        #expect(tuist.status == .missing)
    }

    @Test func doctorReleaseInitScopeFailsOnInvalidSigningEnvironment() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let lock = try makePolicy(
            swiftRule: .init(kind: "semver-range", value: ">=6.0 <7.0"),
            tuistRule: .init(kind: "semver-range", value: ">=4.0 <5.0"),
            fastlaneRule: .init(kind: "semver-range", value: ">=2.0 <3.0"),
            ascRule: .init(kind: "semver-range", value: ">=0.1.0"),
            swiftRequiredFor: ToolchainLock.allCommands,
            tuistRequiredFor: [ToolchainLock.commandApply, ToolchainLock.commandVerify],
            fastlaneRequiredFor: [ToolchainLock.commandReleaseInit],
            ascRequiredFor: [ToolchainLock.commandAppRegister, ToolchainLock.commandReleaseCheck, ToolchainLock.commandReleaseRun]
        )

        let detected = DetectedToolchain(
            swift: "6.2",
            tuist: "4.153.1",
            fastlane: "2.228.0",
            tmaPluginRef: try .init(type: "git-sha", value: "abc")
        )

        let result = try engine.check(
            request: DoctorRequest(
                projectRoot: root,
                lock: lock,
                detected: detected,
                checkCommands: [ToolchainLock.commandReleaseInit],
                environment: [
                    "ASC_ISSUER_ID": "issuer-id",
                    "ASC_KEY_ID": "bad",
                    "ASC_KEY_P8_BASE64": "not-base64",
                    "MATCH_GIT_URL": "ftp://example.com/repo",
                    "MATCH_PASSWORD": "secret"
                ]
            )
        )

        #expect(result.status == "failed")
        #expect(result.exitCode == 6)

        let signing = try #require(result.findings.first(where: { $0.tool == "signing-env" }))
        #expect(signing.severity == .required)
        #expect(signing.status == .incompatible)
        #expect(signing.actualVersion.contains("invalid="))
    }

    @Test func doctorAppRegisterScopeRequiresOnlyAppStoreConnectEnvironment() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let lock = try makePolicy(
            swiftRule: .init(kind: "semver-range", value: ">=6.0 <7.0"),
            tuistRule: .init(kind: "semver-range", value: ">=4.0 <5.0"),
            fastlaneRule: .init(kind: "semver-range", value: ">=2.0 <3.0"),
            ascRule: .init(kind: "semver-range", value: ">=0.1.0"),
            swiftRequiredFor: ToolchainLock.allCommands,
            tuistRequiredFor: [ToolchainLock.commandApply, ToolchainLock.commandVerify],
            fastlaneRequiredFor: [ToolchainLock.commandReleaseInit, ToolchainLock.commandReleaseCheck],
            ascRequiredFor: [ToolchainLock.commandAppRegister, ToolchainLock.commandReleaseCheck, ToolchainLock.commandReleaseRun]
        )

        let detected = DetectedToolchain(
            swift: "6.2",
            tuist: "4.153.1",
            fastlane: "not-found",
            asc: "0.18.0",
            tmaPluginRef: try .init(type: "git-sha", value: "abc"),
            gitVersion: "not-found"
        )

        let result = try engine.check(
            request: DoctorRequest(
                projectRoot: root,
                lock: lock,
                detected: detected,
                checkCommands: [ToolchainLock.commandAppRegister],
                environment: [
                    "ASC_ISSUER_ID": "123E4567-E89B-12D3-A456-426614174000",
                    "ASC_KEY_ID": "AB12CD34EF",
                    "ASC_KEY_P8_BASE64": "c3VwZXItc2VjcmV0",
                    "MATCH_GIT_URL": "",
                    "MATCH_PASSWORD": ""
                ]
            )
        )

        #expect(result.status == "success")
        #expect(result.exitCode == 0)

        let signing = try #require(result.findings.first(where: { $0.tool == "signing-env" }))
        #expect(signing.severity == .required)
        #expect(signing.status == .installed)

        let fastlane = try #require(result.findings.first(where: { $0.tool == "fastlane" }))
        #expect(fastlane.severity == .recommended)

        let asc = try #require(result.findings.first(where: { $0.tool == "asc" }))
        #expect(asc.severity == .required)
        #expect(asc.status == .installed)
    }

    @Test func doctorReleaseCheckScopeRequiresFastlaneGitAndSigningEnvironment() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let lock = try makePolicy(
            swiftRule: .init(kind: "semver-range", value: ">=6.0 <7.0"),
            tuistRule: .init(kind: "semver-range", value: ">=4.0 <5.0"),
            fastlaneRule: .init(kind: "semver-range", value: ">=2.0 <3.0"),
            ascRule: .init(kind: "semver-range", value: ">=0.1.0"),
            swiftRequiredFor: ToolchainLock.allCommands,
            tuistRequiredFor: [ToolchainLock.commandApply, ToolchainLock.commandVerify],
            fastlaneRequiredFor: [ToolchainLock.commandReleaseInit, ToolchainLock.commandReleaseCheck],
            ascRequiredFor: [ToolchainLock.commandAppRegister, ToolchainLock.commandReleaseCheck, ToolchainLock.commandReleaseRun]
        )

        let detected = DetectedToolchain(
            swift: "6.2",
            tuist: "4.153.1",
            fastlane: "not-found",
            tmaPluginRef: try .init(type: "git-sha", value: "abc"),
            gitVersion: "not-found"
        )

        let result = try engine.check(
            request: DoctorRequest(
                projectRoot: root,
                lock: lock,
                detected: detected,
                checkCommands: [ToolchainLock.commandReleaseCheck],
                environment: [
                    "ASC_ISSUER_ID": "issuer-id",
                    "ASC_KEY_ID": "bad",
                    "ASC_KEY_P8_BASE64": "not-base64",
                    "MATCH_GIT_URL": "ftp://example.com/repo",
                    "MATCH_PASSWORD": "secret"
                ]
            )
        )

        #expect(result.status == "failed")
        #expect(result.exitCode == 6)

        let fastlane = try #require(result.findings.first(where: { $0.tool == "fastlane" }))
        #expect(fastlane.severity == .required)
        #expect(fastlane.status == .missing)

        let asc = try #require(result.findings.first(where: { $0.tool == "asc" }))
        #expect(asc.severity == .required)
        #expect(asc.status == .missing)

        let git = try #require(result.findings.first(where: { $0.tool == "git" }))
        #expect(git.severity == .required)
        #expect(git.status == .missing)

        let signing = try #require(result.findings.first(where: { $0.tool == "signing-env" }))
        #expect(signing.severity == .required)
        #expect(signing.status == .incompatible)
    }
}

private extension DoctorEngineIntegrationTests {
    func makePolicy(
        swiftRule: ToolchainLock.VersionRule,
        tuistRule: ToolchainLock.VersionRule,
        fastlaneRule: ToolchainLock.VersionRule,
        ascRule: ToolchainLock.VersionRule,
        swiftRequiredFor: [String],
        tuistRequiredFor: [String],
        fastlaneRequiredFor: [String],
        ascRequiredFor: [String]
    ) throws -> ToolchainLock {
        try ToolchainLock(
            schemaVersion: 2,
            tools: .init(
                swift: try .init(
                    versionRule: swiftRule,
                    requiredFor: swiftRequiredFor,
                    installHints: ["xcode-select --install", "brew install swift"]
                ),
                tuist: try .init(
                    versionRule: tuistRule,
                    requiredFor: tuistRequiredFor,
                    installHints: ["brew install tuist"]
                ),
                fastlane: try .init(
                    versionRule: fastlaneRule,
                    requiredFor: fastlaneRequiredFor,
                    installHints: ["brew install fastlane", "gem install fastlane -NV"]
                ),
                asc: try .init(
                    versionRule: ascRule,
                    requiredFor: ascRequiredFor,
                    installHints: ["brew install asc", "curl -fsSL https://asccli.sh/install | bash"]
                )
            ),
            tmaPluginRef: .init(type: "git-sha", value: "abc")
        )
    }

    func makeTempDir() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("bos-doctor-\(ProcessInfo.processInfo.globallyUniqueString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
