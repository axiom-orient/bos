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
            xcode: "16.2",
            tuist: "4.153.1",
            fastlane: "not-found",
            simctl: "present",
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
        #expect(fastlane.severity == DoctorSeverity.recommended)
        #expect(fastlane.status == DoctorFindingStatus.missing)
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
        #expect(tuist.severity == DoctorSeverity.required)
        #expect(tuist.status == DoctorFindingStatus.missing)
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
        #expect(signing.severity == DoctorSeverity.required)
        #expect(signing.status == DoctorFindingStatus.incompatible)
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
        #expect(signing.severity == DoctorSeverity.required)
        #expect(signing.status == DoctorFindingStatus.installed)

        let fastlane = try #require(result.findings.first(where: { $0.tool == "fastlane" }))
        #expect(fastlane.severity == DoctorSeverity.recommended)

        let asc = try #require(result.findings.first(where: { $0.tool == "asc" }))
        #expect(asc.severity == DoctorSeverity.required)
        #expect(asc.status == DoctorFindingStatus.installed)
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
        #expect(fastlane.severity == DoctorSeverity.required)
        #expect(fastlane.status == DoctorFindingStatus.missing)

        let asc = try #require(result.findings.first(where: { $0.tool == "asc" }))
        #expect(asc.severity == DoctorSeverity.required)
        #expect(asc.status == DoctorFindingStatus.missing)

        let git = try #require(result.findings.first(where: { $0.tool == "git" }))
        #expect(git.severity == DoctorSeverity.required)
        #expect(git.status == DoctorFindingStatus.missing)

        let signing = try #require(result.findings.first(where: { $0.tool == "signing-env" }))
        #expect(signing.severity == DoctorSeverity.required)
        #expect(signing.status == DoctorFindingStatus.incompatible)
    }

    @Test func doctorReleaseRunScopeEvaluatesExpandedToolchainRequirements() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let lock = try makePolicy(
            swiftRule: .init(kind: "semver-range", value: ">=6.0 <7.0"),
            xcodeRule: .init(kind: "semver-range", value: ">=16.0 <17.0"),
            tuistRule: .init(kind: "semver-range", value: ">=4.0 <5.0"),
            rubyRule: .init(kind: "semver-range", value: ">=3.0 <4.0"),
            bundlerRule: .init(kind: "semver-range", value: ">=2.0 <3.0"),
            nodeRule: .init(kind: "semver-range", value: ">=20.0 <23.0"),
            fastlaneRule: .init(kind: "semver-range", value: ">=2.0 <3.0"),
            ascRule: .init(kind: "semver-range", value: ">=0.1.0"),
            devicectlRule: .init(kind: "present", value: "present"),
            simctlRule: .init(kind: "present", value: "present"),
            swiftRequiredFor: ToolchainLock.allCommands,
            xcodeRequiredFor: [ToolchainLock.commandVerify, ToolchainLock.commandReleaseRun],
            tuistRequiredFor: [ToolchainLock.commandApply, ToolchainLock.commandVerify, ToolchainLock.commandReleaseRun],
            rubyRequiredFor: [ToolchainLock.commandReleaseInit, ToolchainLock.commandReleaseCheck, ToolchainLock.commandReleaseRun],
            bundlerRequiredFor: [ToolchainLock.commandReleaseInit, ToolchainLock.commandReleaseCheck, ToolchainLock.commandReleaseRun],
            nodeRequiredFor: ["metadata", "screenshots"],
            fastlaneRequiredFor: [ToolchainLock.commandReleaseInit, ToolchainLock.commandReleaseCheck, ToolchainLock.commandReleaseRun],
            ascRequiredFor: [ToolchainLock.commandAppRegister, ToolchainLock.commandReleaseCheck, ToolchainLock.commandReleaseRun],
            devicectlRequiredFor: ["device", "screenshots"],
            simctlRequiredFor: ["screenshots", ToolchainLock.commandVerify]
        )

        let detected = DetectedToolchain(
            swift: "6.2",
            xcode: "16.2",
            tuist: "4.153.1",
            ruby: "3.2.2",
            bundler: "2.5.6",
            node: "not-found",
            fastlane: "2.228.0",
            asc: "0.18.0",
            devicectl: "not-found",
            simctl: "present",
            tmaPluginRef: try .init(type: "git-sha", value: "abc"),
            brewPath: "/opt/homebrew/bin/brew",
            gitVersion: "2.50.1"
        )

        let result = try engine.check(
            request: DoctorRequest(
                projectRoot: root,
                lock: lock,
                detected: detected,
                checkCommands: [ToolchainLock.commandReleaseRun],
                environment: [
                    "ASC_ISSUER_ID": "123E4567-E89B-12D3-A456-426614174000",
                    "ASC_KEY_ID": "AB12CD34EF",
                    "ASC_KEY_P8_BASE64": "c3VwZXItc2VjcmV0",
                    "MATCH_GIT_URL": "git@github.com:org/certs.git",
                    "MATCH_PASSWORD": "match-secret"
                ]
            )
        )

        #expect(result.status == "success")
        let xcode = try #require(result.findings.first(where: { $0.tool == "xcode" }))
        #expect(xcode.severity == DoctorSeverity.required)
        #expect(xcode.status == DoctorFindingStatus.installed)

        let ruby = try #require(result.findings.first(where: { $0.tool == "ruby" }))
        #expect(ruby.severity == DoctorSeverity.required)
        #expect(ruby.status == DoctorFindingStatus.installed)

        let bundler = try #require(result.findings.first(where: { $0.tool == "bundler" }))
        #expect(bundler.severity == DoctorSeverity.required)
        #expect(bundler.status == DoctorFindingStatus.installed)

        let node = try #require(result.findings.first(where: { $0.tool == "node" }))
        #expect(node.severity == DoctorSeverity.recommended)
        #expect(node.status == DoctorFindingStatus.missing)
    }
}

private extension DoctorEngineIntegrationTests {
    func makePolicy(
        swiftRule: ToolchainLock.VersionRule,
        xcodeRule: ToolchainLock.VersionRule = try! .init(kind: "semver-range", value: ">=16.0 <17.0"),
        tuistRule: ToolchainLock.VersionRule,
        rubyRule: ToolchainLock.VersionRule = try! .init(kind: "semver-range", value: ">=3.0 <4.0"),
        bundlerRule: ToolchainLock.VersionRule = try! .init(kind: "semver-range", value: ">=2.0 <3.0"),
        nodeRule: ToolchainLock.VersionRule = try! .init(kind: "semver-range", value: ">=20.0 <23.0"),
        fastlaneRule: ToolchainLock.VersionRule,
        ascRule: ToolchainLock.VersionRule,
        devicectlRule: ToolchainLock.VersionRule = try! .init(kind: "present", value: "present"),
        simctlRule: ToolchainLock.VersionRule = try! .init(kind: "present", value: "present"),
        swiftRequiredFor: [String],
        xcodeRequiredFor: [String] = [ToolchainLock.commandVerify, ToolchainLock.commandReleaseRun],
        tuistRequiredFor: [String],
        rubyRequiredFor: [String] = [ToolchainLock.commandReleaseInit, ToolchainLock.commandReleaseCheck, ToolchainLock.commandReleaseRun],
        bundlerRequiredFor: [String] = [ToolchainLock.commandReleaseInit, ToolchainLock.commandReleaseCheck, ToolchainLock.commandReleaseRun],
        nodeRequiredFor: [String] = ["metadata", "screenshots"],
        fastlaneRequiredFor: [String],
        ascRequiredFor: [String],
        devicectlRequiredFor: [String] = ["device", "screenshots"],
        simctlRequiredFor: [String] = ["screenshots", ToolchainLock.commandVerify]
    ) throws -> ToolchainLock {
        try ToolchainLock(
            schemaVersion: 2,
            tools: .init(
                swift: try .init(
                    versionRule: swiftRule,
                    requiredFor: swiftRequiredFor,
                    installHints: ["xcode-select --install", "brew install swift"]
                ),
                xcode: try .init(
                    versionRule: xcodeRule,
                    requiredFor: xcodeRequiredFor,
                    installHints: ["xcode-select --install", "sudo xcode-select -s /Applications/Xcode.app"]
                ),
                tuist: try .init(
                    versionRule: tuistRule,
                    requiredFor: tuistRequiredFor,
                    installHints: ["brew install tuist"]
                ),
                ruby: try .init(
                    versionRule: rubyRule,
                    requiredFor: rubyRequiredFor,
                    installHints: ["brew install ruby"]
                ),
                bundler: try .init(
                    versionRule: bundlerRule,
                    requiredFor: bundlerRequiredFor,
                    installHints: ["gem install bundler"]
                ),
                node: try .init(
                    versionRule: nodeRule,
                    requiredFor: nodeRequiredFor,
                    installHints: ["brew install node"]
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
                ),
                devicectl: try .init(
                    versionRule: devicectlRule,
                    requiredFor: devicectlRequiredFor,
                    installHints: ["xcrun --find devicectl"]
                ),
                simctl: try .init(
                    versionRule: simctlRule,
                    requiredFor: simctlRequiredFor,
                    installHints: ["xcrun --find simctl"]
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
