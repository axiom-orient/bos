import Foundation
import XCTest
@testable import BosCore

final class ApplyEngineIntegrationTests: XCTestCase {
    private let engine = ApplyEngine()

    func testInitModeGeneratesTuistScaffoldAndManagedBlock() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let result = try engine.apply(
            request: ApplyRequest(
                projectRoot: root,
                blueprint: try makeBlueprint(),
                profile: try makeProfile(),
                mode: .initMode
            )
        )

        let appComposition = root.appending(path: "Projects/App/Sources/Dependencies/AppComposition.swift")
        let composition = try String(contentsOf: appComposition, encoding: .utf8)
        XCTAssertTrue(composition.contains("// bootstrap:begin app.dependencies"))
        XCTAssertTrue(composition.contains("// bootstrap:end app.dependencies"))
        XCTAssertTrue(composition.contains("// FeatureRoot"))
        XCTAssertTrue(composition.contains("// FeatureToday"))
        XCTAssertTrue(composition.contains("// DomainUser"))
        XCTAssertTrue(composition.contains("// ServiceAuth"))

        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appending(path: "Tuist.swift").path(percentEncoded: false)))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appending(path: "Workspace.swift").path(percentEncoded: false)))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appending(path: "Tuist/Package.swift").path(percentEncoded: false)))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appending(path: "AGENTS.md").path(percentEncoded: false)))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appending(path: "CLAUDE.md").path(percentEncoded: false)))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appending(path: "Rules/RULES.md").path(percentEncoded: false)))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appending(path: "Rules/L1_universal/Tuist.md").path(percentEncoded: false)))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appending(path: "Rules/L2_project/TechStack.md").path(percentEncoded: false)))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appending(path: "Tuist/Plugins/tma/Plugin.swift").path(percentEncoded: false)))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appending(path: "Tuist/Plugins/tma/Templates/app/app.swift").path(percentEncoded: false)))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appending(path: "Projects/App/Project.swift").path(percentEncoded: false)))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appending(path: "Projects/Domains/User/Project.swift").path(percentEncoded: false)))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appending(path: "Projects/Features/Today/Project.swift").path(percentEncoded: false)))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appending(path: "Projects/Services/Auth/Project.swift").path(percentEncoded: false)))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appending(path: "Projects/Shared/Core/Project.swift").path(percentEncoded: false)))

        let packageText = try String(contentsOf: root.appending(path: "Tuist/Package.swift"), encoding: .utf8)
        XCTAssertTrue(packageText.contains("swift-composable-architecture"))
        XCTAssertTrue(packageText.contains("swift-dependencies"))
        XCTAssertTrue(packageText.contains("swift-navigation"))
        XCTAssertTrue(packageText.contains("sqlite-data"))
        XCTAssertTrue(packageText.contains("swift-identified-collections"))
        XCTAssertTrue(packageText.contains("from: \"2.4.0\""))
        XCTAssertTrue(packageText.contains("from: \"1.6.0\""))
        XCTAssertTrue(packageText.contains("from: \"1.1.0\""))
        let agentsText = try String(contentsOf: root.appending(path: "AGENTS.md"), encoding: .utf8)
        XCTAssertTrue(agentsText.contains("# AGENTS.md (L0: Universal Behavior Rules)"))
        let claudeText = try String(contentsOf: root.appending(path: "CLAUDE.md"), encoding: .utf8)
        XCTAssertTrue(claudeText.contains("# CLAUDE.md (L2: Project Absolute Rules)"))
        let techStackText = try String(contentsOf: root.appending(path: "Rules/L2_project/TechStack.md"), encoding: .utf8)
        XCTAssertTrue(techStackText.contains("swift-navigation"))
        XCTAssertTrue(techStackText.contains("swift-identified-collections"))
        XCTAssertFalse(techStackText.contains("firebase-ios-sdk"))
        let tuistText = try String(contentsOf: root.appending(path: "Tuist.swift"), encoding: .utf8)
        XCTAssertTrue(tuistText.contains(#".local(path: .relativeToRoot("Tuist/Plugins/tma"))"#))
        XCTAssertFalse(tuistText.contains("/Users/axient/repository/tma"))
        let appProjectText = try String(contentsOf: root.appending(path: "Projects/App/Project.swift"), encoding: .utf8)
        XCTAssertTrue(appProjectText.contains(#"let teamID = "A1B2C3D4E5""#))
        XCTAssertTrue(appProjectText.contains(#""DEVELOPMENT_TEAM": .string(teamID)"#))
        let domainProjectText = try String(contentsOf: root.appending(path: "Projects/Domains/User/Project.swift"), encoding: .utf8)
        XCTAssertTrue(domainProjectText.contains(#"let teamID = "A1B2C3D4E5""#))
        XCTAssertTrue(domainProjectText.contains(#""DEVELOPMENT_TEAM": .string(teamID)"#))

        let stateFile = root.appending(path: ".bos/state/bos.state.yaml")
        let lockText = try String(contentsOf: stateFile, encoding: .utf8)
        XCTAssertTrue(lockText.contains("blueprintHash:"))
        XCTAssertTrue(lockText.contains("profileHash:"))
        XCTAssertTrue(lockText.contains("managedFiles:"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appending(path: "bos.lock.yaml").path(percentEncoded: false)))

        XCTAssertEqual(result.managedFiles.count, 1)
        XCTAssertEqual(result.artifacts.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.lockFile))
        XCTAssertTrue(result.lockFile.hasSuffix(".bos/state/bos.state.yaml"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.artifacts[0]))
    }

    func testIncrementalDriftFailsWithoutFixWhenManagedBlockChanged() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        try bootstrapInit(root: root)

        let target = root.appending(path: "Projects/App/Sources/Dependencies/AppComposition.swift")
        let drifted = try String(contentsOf: target, encoding: .utf8)
            .replacingOccurrences(of: "// FeatureToday", with: "// FeatureTodayDrifted")
        try Data(drifted.utf8).write(to: target, options: .atomic)

        XCTAssertThrowsError(
            try engine.apply(
                request: ApplyRequest(
                    projectRoot: root,
                    blueprint: try makeBlueprint(),
                    profile: try makeProfile(),
                    mode: .incremental,
                    fix: false
                )
            )
        ) { error in
            guard case ApplyEngineError.driftDetected(let path) = error else {
                return XCTFail("unexpected error: \(error)")
            }
            XCTAssertTrue(path.hasSuffix("Projects/App/Sources/Dependencies/AppComposition.swift"))
        }
    }

    func testIncrementalFixRepairsManagedBlock() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        try bootstrapInit(root: root)

        let target = root.appending(path: "Projects/App/Sources/Dependencies/AppComposition.swift")
        let drifted = try String(contentsOf: target, encoding: .utf8)
            .replacingOccurrences(of: "// FeatureToday", with: "// FeatureTodayDrifted")
        try Data(drifted.utf8).write(to: target, options: .atomic)

        _ = try engine.apply(
            request: ApplyRequest(
                projectRoot: root,
                blueprint: try makeBlueprint(),
                profile: try makeProfile(),
                mode: .incremental,
                fix: true
            )
        )

        let repaired = try String(contentsOf: target, encoding: .utf8)
        XCTAssertFalse(repaired.contains("// FeatureTodayDrifted"))
        XCTAssertTrue(repaired.contains("// FeatureToday"))
    }

    func testIncrementalFailsWhenOutsideManagedAreaChangedEvenWithFix() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        try bootstrapInit(root: root)

        let target = root.appending(path: "Projects/App/Sources/Dependencies/AppComposition.swift")
        let drifted = try String(contentsOf: target, encoding: .utf8)
            .replacingOccurrences(of: "import Dependencies", with: "import Foundation")
        try Data(drifted.utf8).write(to: target, options: .atomic)

        XCTAssertThrowsError(
            try engine.apply(
                request: ApplyRequest(
                    projectRoot: root,
                    blueprint: try makeBlueprint(),
                    profile: try makeProfile(),
                    mode: .incremental,
                    fix: true
                )
            )
        ) { error in
            guard case ApplyEngineError.outsideManagedAreaChanged(let path) = error else {
                return XCTFail("unexpected error: \(error)")
            }
            XCTAssertTrue(path.hasSuffix("Projects/App/Sources/Dependencies/AppComposition.swift"))
        }
    }

    func testIncrementalManagedBlockMissingFailsWithoutFix() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let target = root.appending(path: "Projects/App/Sources/Dependencies/AppComposition.swift")
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        let noMarkers = """
        import Dependencies

        public enum AppComposition {
            public static func configureAll(_ values: inout DependencyValues) {
                values.appAnalyticsService = .live
            }
        }
        """
        try Data(noMarkers.utf8).write(to: target, options: .atomic)

        XCTAssertThrowsError(
            try engine.apply(
                request: ApplyRequest(
                    projectRoot: root,
                    blueprint: try makeBlueprint(),
                    profile: try makeProfile(),
                    mode: .incremental,
                    fix: false
                )
            )
        ) { error in
            guard case ApplyEngineError.managedBlockMissing(let path) = error else {
                return XCTFail("unexpected error: \(error)")
            }
            XCTAssertTrue(path.hasSuffix("Projects/App/Sources/Dependencies/AppComposition.swift"))
        }
    }

    func testIncrementalFixInsertsManagedBlockWhenMissing() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let target = root.appending(path: "Projects/App/Sources/Dependencies/AppComposition.swift")
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        let noMarkers = """
        import Dependencies

        public enum AppComposition {
            public static func configureAll(_ values: inout DependencyValues) {
                values.appAnalyticsService = .live
            }
        }
        """
        try Data(noMarkers.utf8).write(to: target, options: .atomic)

        _ = try engine.apply(
            request: ApplyRequest(
                projectRoot: root,
                blueprint: try makeBlueprint(),
                profile: try makeProfile(),
                mode: .incremental,
                fix: true
            )
        )

        let updated = try String(contentsOf: target, encoding: .utf8)
        XCTAssertTrue(updated.contains("// bootstrap:begin app.dependencies"))
        XCTAssertTrue(updated.contains("// bootstrap:end app.dependencies"))
        XCTAssertTrue(updated.contains("// FeatureToday"))
    }

    func testInitNormalizesServiceSuffixToAvoidDoubleServiceInTypeNames() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let blueprint = try makeBlueprint(services: ["UserService"])
        _ = try engine.apply(
            request: ApplyRequest(
                projectRoot: root,
                blueprint: blueprint,
                profile: try makeProfile(),
                mode: .initMode
            )
        )

        let expectedFile = root.appending(path: "Projects/Services/User/Interface/UserService.swift")
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedFile.path(percentEncoded: false)))

        let appComposition = try String(
            contentsOf: root.appending(path: "Projects/App/Sources/Dependencies/AppComposition.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(appComposition.contains("// ServiceUser"))
        XCTAssertFalse(appComposition.contains("// ServiceUserService"))
    }

    func testInitDoesNotOverwriteExistingModuleFile() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        try bootstrapInit(root: root)
        let target = root.appending(path: "Projects/Features/Today/Sources/TodayFeature.swift")
        let customContent = """
        // custom user file
        import Foundation

        enum TodayFeature {
            static let marker = "preserved"
        }
        """
        try Data(customContent.utf8).write(to: target, options: .atomic)

        _ = try engine.apply(
            request: ApplyRequest(
                projectRoot: root,
                blueprint: try makeBlueprint(),
                profile: try makeProfile(),
                mode: .initMode
            )
        )

        let after = try String(contentsOf: target, encoding: .utf8)
        XCTAssertEqual(after, customContent)
    }

    func testInitDoesNotOverwriteExistingRootGuideFiles() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let agents = root.appending(path: "AGENTS.md")
        let customAgents = "# custom agents"
        try Data(customAgents.utf8).write(to: agents, options: .atomic)

        let rulesDir = root.appending(path: "Rules")
        try FileManager.default.createDirectory(at: rulesDir, withIntermediateDirectories: true)
        let customRules = rulesDir.appending(path: "RULES.md")
        let customRulesText = "# custom rules"
        try Data(customRulesText.utf8).write(to: customRules, options: .atomic)

        _ = try engine.apply(
            request: ApplyRequest(
                projectRoot: root,
                blueprint: try makeBlueprint(),
                profile: try makeProfile(),
                mode: .initMode
            )
        )

        let agentsAfter = try String(contentsOf: agents, encoding: .utf8)
        XCTAssertEqual(agentsAfter, customAgents)
        let rulesAfter = try String(contentsOf: customRules, encoding: .utf8)
        XCTAssertEqual(rulesAfter, customRulesText)
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appending(path: "CLAUDE.md").path(percentEncoded: false)))
    }

    func testInitPreservesPascalCaseModuleDirectoryNames() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let blueprint = try makeBlueprint(
            features: ["Root", "WeeklyReview"],
            domains: ["DraftItem", "FocusSession"],
            services: ["SpeechCaptureSessionService", "ReviewDecisionService"],
            shared: ["Core", "DesignSystem"]
        )
        _ = try engine.apply(
            request: ApplyRequest(
                projectRoot: root,
                blueprint: blueprint,
                profile: try makeProfile(),
                mode: .initMode
            )
        )

        let fm = FileManager.default
        XCTAssertTrue(fm.fileExists(atPath: root.appending(path: "Projects/Features/WeeklyReview/Project.swift").path(percentEncoded: false)))
        XCTAssertTrue(fm.fileExists(atPath: root.appending(path: "Projects/Domains/DraftItem/Project.swift").path(percentEncoded: false)))
        XCTAssertTrue(fm.fileExists(atPath: root.appending(path: "Projects/Domains/FocusSession/Project.swift").path(percentEncoded: false)))
        XCTAssertTrue(fm.fileExists(atPath: root.appending(path: "Projects/Services/SpeechCaptureSession/Project.swift").path(percentEncoded: false)))
        XCTAssertTrue(fm.fileExists(atPath: root.appending(path: "Projects/Services/ReviewDecision/Project.swift").path(percentEncoded: false)))
        XCTAssertTrue(fm.fileExists(atPath: root.appending(path: "Projects/Shared/DesignSystem/Project.swift").path(percentEncoded: false)))
    }
}

private extension ApplyEngineIntegrationTests {
    func bootstrapInit(root: URL) throws {
        _ = try engine.apply(
            request: ApplyRequest(
                projectRoot: root,
                blueprint: try makeBlueprint(),
                profile: try makeProfile(),
                mode: .initMode
            )
        )
    }

    func makeTempDir() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("bos-apply-\(ProcessInfo.processInfo.globallyUniqueString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    func makeBlueprint(
        features: [String] = ["Root", "Today"],
        domains: [String] = ["User"],
        services: [String] = ["Auth"],
        shared: [String] = ["Core", "DesignSystem"]
    ) throws -> BlueprintV1 {
        let project = try BlueprintV1.Project(
            name: "Daycraft",
            bundleIdPrefix: "com.axiomorient",
            deploymentTarget: "18.0"
        )
        let requirements = try BlueprintV1.Requirements(
            reqIds: ["REQ-001"],
            screens: ["SCR_TODAY", "SCR_CHAT"]
        )
        let app = try BlueprintV1.AppModule(name: "Daycraft")
        let modules = try BlueprintV1.Modules(
            app: app,
            features: features,
            domains: domains,
            services: services,
            shared: shared
        )
        let wiring = try BlueprintV1.Wiring(rootFeature: "Root")
        let fastlane = try BlueprintV1.Fastlane(
            appIdentifier: "com.axiomorient.daycraft",
            appleTeamId: "A1B2C3D4E5"
        )
        let release = BlueprintV1.Release(fastlane: fastlane)
        return try BlueprintV1(
            schemaVersion: 1,
            project: project,
            requirements: requirements,
            modules: modules,
            wiring: wiring,
            release: release
        )
    }

    func makeProfile() throws -> ProfileV1 {
        let appTargets = ProfileV1.AppTargets(controlsExtension: true, uiTests: true)
        let defaults = ProfileV1.Defaults(deploymentTarget: "18.0", appTargets: appTargets)
        let pattern = ProfileV1.FeaturePattern(sourcesInterface: true, designFolder: true)
        let rules = try ProfileV1.Rules(
            testingStyle: "swift-testing",
            forbidPatterns: ["@unchecked Sendable", "Date()", "UUID()"]
        )
        return try ProfileV1(
            schemaVersion: 1,
            name: "daycraft",
            defaults: defaults,
            featurePattern: pattern,
            rules: rules
        )
    }
}
