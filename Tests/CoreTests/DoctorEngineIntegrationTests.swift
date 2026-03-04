import Foundation
import XCTest
@testable import BosCore

final class DoctorEngineIntegrationTests: XCTestCase {
    private let engine = DoctorEngine()

    func testLegacyV1ConvertsToPolicyV2() throws {
        let v1 = try ToolchainLockV1(
            schemaVersion: 1,
            swift: "6.0",
            tuist: "4.153.1",
            fastlane: "2.228.0",
            tmaPluginRef: .init(type: "git-sha", value: "abc")
        )
        let lock = try v1.asToolchainLockV2()
        XCTAssertEqual(lock.schemaVersion, 2)
        XCTAssertFalse(lock.tools.swift.requiredFor.isEmpty)
        XCTAssertFalse(lock.tools.tuist.requiredFor.isEmpty)
        XCTAssertFalse(lock.tools.fastlane.requiredFor.isEmpty)
    }

    func testDoctorCoreScopeDoesNotBlockMissingFastlane() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let lock = try makePolicy(
            swiftRule: .init(kind: "semver-range", value: ">=6.0 <7.0"),
            tuistRule: .init(kind: "semver-range", value: ">=4.0 <5.0"),
            fastlaneRule: .init(kind: "semver-range", value: ">=2.0 <3.0"),
            swiftRequiredFor: ToolchainLockV2.allCommands,
            tuistRequiredFor: [ToolchainLockV2.commandApply, ToolchainLockV2.commandVerify],
            fastlaneRequiredFor: [ToolchainLockV2.commandReleaseInit]
        )

        let detected = try DetectedToolchainV2(
            swift: "6.2",
            tuist: "4.153.1",
            fastlane: "not-found",
            tmaPluginRef: .init(type: "git-sha", value: "abc")
        )

        let result = try engine.check(
            request: DoctorRequest(
                projectRoot: root,
                lock: lock,
                detected: detected,
                checkCommands: ToolchainLockV2.coreCommands
            )
        )

        XCTAssertEqual(result.status, "success")
        XCTAssertEqual(result.exitCode, 0)

        let fastlane = try XCTUnwrap(result.findings.first(where: { $0.tool == "fastlane" }))
        XCTAssertEqual(fastlane.severity, .recommended)
        XCTAssertEqual(fastlane.status, .missing)
    }

    func testDoctorFailsWhenRequiredToolMissingForScope() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let lock = try makePolicy(
            swiftRule: .init(kind: "semver-range", value: ">=6.0 <7.0"),
            tuistRule: .init(kind: "semver-range", value: ">=4.0 <5.0"),
            fastlaneRule: .init(kind: "semver-range", value: ">=2.0 <3.0"),
            swiftRequiredFor: ToolchainLockV2.allCommands,
            tuistRequiredFor: [ToolchainLockV2.commandApply, ToolchainLockV2.commandVerify],
            fastlaneRequiredFor: [ToolchainLockV2.commandReleaseInit]
        )

        let detected = try DetectedToolchainV2(
            swift: "6.2",
            tuist: "not-found",
            fastlane: "not-found",
            tmaPluginRef: .init(type: "git-sha", value: "abc")
        )

        let result = try engine.check(
            request: DoctorRequest(
                projectRoot: root,
                lock: lock,
                detected: detected,
                checkCommands: ToolchainLockV2.coreCommands
            )
        )

        XCTAssertEqual(result.status, "failed")
        XCTAssertEqual(result.exitCode, 6)

        let tuist = try XCTUnwrap(result.findings.first(where: { $0.tool == "tuist" }))
        XCTAssertEqual(tuist.severity, .required)
        XCTAssertEqual(tuist.status, .missing)
    }
}

private extension DoctorEngineIntegrationTests {
    func makePolicy(
        swiftRule: ToolchainLockV2.VersionRule,
        tuistRule: ToolchainLockV2.VersionRule,
        fastlaneRule: ToolchainLockV2.VersionRule,
        swiftRequiredFor: [String],
        tuistRequiredFor: [String],
        fastlaneRequiredFor: [String]
    ) throws -> ToolchainLockV2 {
        try ToolchainLockV2(
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
