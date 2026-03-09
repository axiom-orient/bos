import Foundation
import Testing
@testable import BosCore

@Suite
struct ApplyEngineIntegrationTests {
    private let engine = ApplyEngine()

    @Test func initModeGeneratesTuistScaffoldAndManagedBlock() throws {
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
        #expect(composition.contains("// bootstrap:begin app.dependencies"))
        #expect(composition.contains("// bootstrap:end app.dependencies"))
        #expect(composition.contains("// FeatureRoot"))
        #expect(composition.contains("// FeatureToday"))
        #expect(composition.contains("// DomainUser"))
        #expect(composition.contains("// ServiceAuth"))

        #expect(FileManager.default.fileExists(atPath: root.appending(path: "Tuist.swift").path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: root.appending(path: "Workspace.swift").path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: root.appending(path: "Tuist/Package.swift").path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: root.appending(path: "AGENTS.md").path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: root.appending(path: "CLAUDE.md").path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: root.appending(path: "Rules/RULES.md").path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: root.appending(path: "Rules/L1_universal/Tuist.md").path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: root.appending(path: "Rules/L2_project/TechStack.md").path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: root.appending(path: "Tuist/Plugins/tma/Plugin.swift").path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: root.appending(path: "Tuist/Plugins/tma/Templates/app/app.swift").path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: root.appending(path: "Projects/App/Project.swift").path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: root.appending(path: "Projects/Domains/User/Project.swift").path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: root.appending(path: "Projects/Features/Today/Project.swift").path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: root.appending(path: "Projects/Services/Auth/Project.swift").path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: root.appending(path: "Projects/Shared/Core/Project.swift").path(percentEncoded: false)))

        let packageText = try String(contentsOf: root.appending(path: "Tuist/Package.swift"), encoding: .utf8)
        #expect(packageText.contains("swift-composable-architecture"))
        #expect(packageText.contains("swift-dependencies"))
        #expect(packageText.contains("swift-navigation"))
        #expect(packageText.contains("sqlite-data"))
        #expect(packageText.contains("swift-identified-collections"))
        #expect(packageText.contains("from: \"2.4.0\""))
        #expect(packageText.contains("from: \"1.6.0\""))
        #expect(packageText.contains("from: \"1.1.0\""))
        let agentsText = try String(contentsOf: root.appending(path: "AGENTS.md"), encoding: .utf8)
        #expect(agentsText.contains("# AGENTS.md (L0: Universal Behavior Rules)"))
        let claudeText = try String(contentsOf: root.appending(path: "CLAUDE.md"), encoding: .utf8)
        #expect(claudeText.contains("# CLAUDE.md (L2: Project Absolute Rules)"))
        let techStackText = try String(contentsOf: root.appending(path: "Rules/L2_project/TechStack.md"), encoding: .utf8)
        #expect(techStackText.contains("swift-navigation"))
        #expect(techStackText.contains("swift-identified-collections"))
        #expect(!techStackText.contains("firebase-ios-sdk"))
        let tuistText = try String(contentsOf: root.appending(path: "Tuist.swift"), encoding: .utf8)
        #expect(tuistText.contains(#".local(path: .relativeToRoot("Tuist/Plugins/tma"))"#))
        #expect(!tuistText.contains("/Users/axient/repository/tma"))
        let appProjectText = try String(contentsOf: root.appending(path: "Projects/App/Project.swift"), encoding: .utf8)
        #expect(appProjectText.contains(#"let teamID = "A1B2C3D4E5""#))
        #expect(appProjectText.contains(#""DEVELOPMENT_TEAM": .string(teamID)"#))
        #expect(appProjectText.contains(#""CODE_SIGNING_ALLOWED": .string("NO")"#))
        #expect(appProjectText.contains(#""CODE_SIGNING_REQUIRED": .string("NO")"#))
        let domainProjectText = try String(contentsOf: root.appending(path: "Projects/Domains/User/Project.swift"), encoding: .utf8)
        #expect(domainProjectText.contains(#"let teamID = "A1B2C3D4E5""#))
        #expect(domainProjectText.contains(#""DEVELOPMENT_TEAM": .string(teamID)"#))

        let stateFile = root.appending(path: ".bos/state/bos.state.yaml")
        let lockText = try String(contentsOf: stateFile, encoding: .utf8)
        #expect(lockText.contains("blueprintHash:"))
        #expect(lockText.contains("profileHash:"))
        #expect(lockText.contains("managedFiles:"))
        #expect(!FileManager.default.fileExists(atPath: root.appending(path: "bos.lock.yaml").path(percentEncoded: false)))

        #expect(result.managedFiles.count == 1)
        #expect(result.artifacts.count == 1)
        #expect(FileManager.default.fileExists(atPath: result.lockFile))
        #expect(result.lockFile.hasSuffix(".bos/state/bos.state.yaml"))
        #expect(FileManager.default.fileExists(atPath: result.artifacts[0]))
    }

    @Test func incrementalDriftFailsWithoutFixWhenManagedBlockChanged() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        try bootstrapInit(root: root)

        let target = root.appending(path: "Projects/App/Sources/Dependencies/AppComposition.swift")
        let drifted = try String(contentsOf: target, encoding: .utf8)
            .replacingOccurrences(of: "// FeatureToday", with: "// FeatureTodayDrifted")
        try Data(drifted.utf8).write(to: target, options: .atomic)

        do {
            _ = try engine.apply(
                request: ApplyRequest(
                    projectRoot: root,
                    blueprint: try makeBlueprint(),
                    profile: try makeProfile(),
                    mode: .incremental,
                    fix: false
                )
            )
            Issue.record("expected ApplyEngineError.driftDetected to be thrown")
        } catch ApplyEngineError.driftDetected(let path) {
            #expect(path.hasSuffix("Projects/App/Sources/Dependencies/AppComposition.swift"))
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test func incrementalFixRepairsManagedBlock() throws {
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
        #expect(!repaired.contains("// FeatureTodayDrifted"))
        #expect(repaired.contains("// FeatureToday"))
    }

    @Test func incrementalFailsWhenOutsideManagedAreaChangedEvenWithFix() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        try bootstrapInit(root: root)

        let target = root.appending(path: "Projects/App/Sources/Dependencies/AppComposition.swift")
        let drifted = try String(contentsOf: target, encoding: .utf8)
            .replacingOccurrences(of: "import Dependencies", with: "import Foundation")
        try Data(drifted.utf8).write(to: target, options: .atomic)

        do {
            _ = try engine.apply(
                request: ApplyRequest(
                    projectRoot: root,
                    blueprint: try makeBlueprint(),
                    profile: try makeProfile(),
                    mode: .incremental,
                    fix: true
                )
            )
            Issue.record("expected ApplyEngineError.outsideManagedAreaChanged to be thrown")
        } catch ApplyEngineError.outsideManagedAreaChanged(let path) {
            #expect(path.hasSuffix("Projects/App/Sources/Dependencies/AppComposition.swift"))
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test func incrementalManagedBlockMissingFailsWithoutFix() throws {
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

        do {
            _ = try engine.apply(
                request: ApplyRequest(
                    projectRoot: root,
                    blueprint: try makeBlueprint(),
                    profile: try makeProfile(),
                    mode: .incremental,
                    fix: false
                )
            )
            Issue.record("expected ApplyEngineError.managedBlockMissing to be thrown")
        } catch ApplyEngineError.managedBlockMissing(let path) {
            #expect(path.hasSuffix("Projects/App/Sources/Dependencies/AppComposition.swift"))
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test func incrementalFixInsertsManagedBlockWhenMissing() throws {
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
        #expect(updated.contains("// bootstrap:begin app.dependencies"))
        #expect(updated.contains("// bootstrap:end app.dependencies"))
        #expect(updated.contains("// FeatureToday"))
    }

    @Test func initNormalizesServiceSuffixToAvoidDoubleServiceInTypeNames() throws {
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
        #expect(FileManager.default.fileExists(atPath: expectedFile.path(percentEncoded: false)))

        let appComposition = try String(
            contentsOf: root.appending(path: "Projects/App/Sources/Dependencies/AppComposition.swift"),
            encoding: .utf8
        )
        #expect(appComposition.contains("// ServiceUser"))
        #expect(!appComposition.contains("// ServiceUserService"))
    }

    @Test func initDoesNotOverwriteExistingModuleFile() throws {
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
        #expect(after == customContent)
    }

    @Test func initDoesNotOverwriteExistingRootGuideFiles() throws {
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
        #expect(agentsAfter == customAgents)
        let rulesAfter = try String(contentsOf: customRules, encoding: .utf8)
        #expect(rulesAfter == customRulesText)
        #expect(FileManager.default.fileExists(atPath: root.appending(path: "CLAUDE.md").path(percentEncoded: false)))
    }

    @Test func initPreservesPascalCaseModuleDirectoryNames() throws {
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
        #expect(fm.fileExists(atPath: root.appending(path: "Projects/Features/WeeklyReview/Project.swift").path(percentEncoded: false)))
        #expect(fm.fileExists(atPath: root.appending(path: "Projects/Domains/DraftItem/Project.swift").path(percentEncoded: false)))
        #expect(fm.fileExists(atPath: root.appending(path: "Projects/Domains/FocusSession/Project.swift").path(percentEncoded: false)))
        #expect(fm.fileExists(atPath: root.appending(path: "Projects/Services/SpeechCaptureSession/Project.swift").path(percentEncoded: false)))
        #expect(fm.fileExists(atPath: root.appending(path: "Projects/Services/ReviewDecision/Project.swift").path(percentEncoded: false)))
        #expect(fm.fileExists(atPath: root.appending(path: "Projects/Shared/DesignSystem/Project.swift").path(percentEncoded: false)))
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
    ) throws -> Blueprint {
        let project = try Blueprint.Project(
            name: "Daycraft",
            bundleIdPrefix: "com.axiomorient",
            deploymentTarget: "18.0"
        )
        let requirements = try Blueprint.Requirements(
            reqIds: ["REQ-001"],
            screens: ["SCR_TODAY", "SCR_CHAT"]
        )
        let app = try Blueprint.AppModule(name: "Daycraft")
        let modules = try Blueprint.Modules(
            app: app,
            features: features,
            domains: domains,
            services: services,
            shared: shared
        )
        let wiring = try Blueprint.Wiring(rootFeature: "Root")
        let fastlane = try Blueprint.Fastlane(
            appIdentifier: "com.axiomorient.daycraft",
            appleTeamId: "A1B2C3D4E5"
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

    func makeProfile() throws -> Profile {
        let appTargets = Profile.AppTargets(controlsExtension: true, uiTests: true)
        let defaults = Profile.Defaults(deploymentTarget: "18.0", appTargets: appTargets)
        let pattern = Profile.FeaturePattern(sourcesInterface: true, designFolder: true)
        let rules = try Profile.Rules(
            testingStyle: "swift-testing",
            forbidPatterns: ["@unchecked Sendable", "Date()", "UUID()"]
        )
        return try Profile(
            schemaVersion: 1,
            name: "daycraft",
            defaults: defaults,
            featurePattern: pattern,
            rules: rules
        )
    }
}
