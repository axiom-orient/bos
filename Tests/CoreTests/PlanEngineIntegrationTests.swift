import Testing
@testable import BosCore

@Suite
struct PlanEngineIntegrationTests {
    private let engine = PlanEngine()

    @Test func generateBlueprintExtractsReqScrEntities() throws {
        let prd = """
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
        """

        let blueprint = try engine.generateBlueprint(prd: prd, profile: makeProfile())

        #expect(blueprint.schemaVersion == 1)
        #expect(blueprint.project.name == "Daycraft")
        #expect(blueprint.project.bundleIdPrefix == "com.axiomorient")
        #expect(blueprint.project.deploymentTarget == "18.0")

        #expect(blueprint.requirements.reqIds == ["REQ-001", "REQ-002"])
        #expect(blueprint.requirements.screens == ["SCR_TODAY_HOME", "SCR_CHAT_THREAD"])

        #expect(blueprint.modules.features == ["Root", "TodayHome", "ChatThread"])
        #expect(blueprint.modules.domains == ["User", "Routine", "Session"])
        #expect(blueprint.modules.services == ["UserService", "RoutineService", "SessionService"])
        #expect(blueprint.modules.shared == ["Core", "DesignSystem"])

        #expect(blueprint.release.fastlane.appIdentifier == "com.axiomorient.daycraft")
        #expect(blueprint.release.fastlane.appleTeamId == "A1B2C3D4E5")
    }

    @Test func missingReqIDsFailsHard() throws {
        let prd = """
        Project: Daycraft
        App Identifier: com.axiomorient.daycraft
        Apple Team ID: A1B2C3D4E5

        Screens
        - SCR_TODAY_HOME

        Entities
        - Entity: User
        """

        do {
            _ = try engine.generateBlueprint(prd: prd, profile: makeProfile())
            Issue.record("expected PlanEngineError.missingReqIDs to be thrown")
        } catch let error as PlanEngineError {
            #expect(error == .missingReqIDs)
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test func missingScreensFailsHard() throws {
        let prd = """
        Project: Daycraft
        App Identifier: com.axiomorient.daycraft
        Apple Team ID: A1B2C3D4E5

        Requirements
        - REQ-001 홈 화면 진입

        Entities
        - Entity: User
        """

        do {
            _ = try engine.generateBlueprint(prd: prd, profile: makeProfile())
            Issue.record("expected PlanEngineError.missingScreens to be thrown")
        } catch let error as PlanEngineError {
            #expect(error == .missingScreens)
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test func missingEntitiesFailsHard() throws {
        let prd = """
        Project: Daycraft
        App Identifier: com.axiomorient.daycraft
        Apple Team ID: A1B2C3D4E5

        Requirements
        - REQ-001 홈 화면 진입

        Screens
        - SCR_TODAY_HOME
        """

        do {
            _ = try engine.generateBlueprint(prd: prd, profile: makeProfile())
            Issue.record("expected PlanEngineError.missingEntities to be thrown")
        } catch let error as PlanEngineError {
            #expect(error == .missingEntities)
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test func generateBlueprintPreservesPascalCaseEntityNames() throws {
        let prd = """
        Project: Aether
        App Identifier: com.axient.aether
        Apple Team ID: A1B2C3D4E5

        Requirements
        - REQ-001 기본 흐름

        Screens
        - SCR_WEEKLY_REVIEW

        Entities
        - Entity: DraftItem
        - Entity: FocusSession
        - Entity: SpeechCaptureSession
        """

        let blueprint = try engine.generateBlueprint(prd: prd, profile: makeProfile())

        #expect(blueprint.modules.domains == ["DraftItem", "FocusSession", "SpeechCaptureSession"])
        #expect(blueprint.modules.services == ["DraftItemService", "FocusSessionService", "SpeechCaptureSessionService"])
    }

    @Test func derivePRDFromPlanTextExtractsFRScreensAndEntities() throws {
        let planText = """
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
        """

        let prd = engine.derivePRD(
            fromPlanText: planText,
            options: PlanDeriveOptions(
                appIdentifier: "com.axient.aether",
                appleTeamID: "A1B2C3D4E5"
            )
        )
        let blueprint = try engine.generateBlueprint(prd: prd, profile: makeProfile())

        #expect(blueprint.requirements.reqIds == ["REQ-001", "REQ-002", "REQ-010"])
        #expect(blueprint.requirements.screens.contains("SCR_TODAY"))
        #expect(blueprint.requirements.screens.contains("SCR_WEEKLY_REVIEW"))
        #expect(
            blueprint.modules.domains ==
            ["Item", "DraftItem", "FocusSession", "ReflectionRecord", "SpeechCaptureSession"]
        )
    }
}

private extension PlanEngineIntegrationTests {
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
