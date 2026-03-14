import Foundation
import Testing
@testable import BosCore

@Suite
struct ScreenshotsEngineIntegrationTests {
    @Test func planSummarizesMatrixAndWritesArtifacts() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let planPath = root.appending(path: "config/screenshots.plan.yaml")
        try writePlan(to: planPath)

        let engine = ScreenshotsEngine()
        let result = try engine.run(
            request: ScreenshotRequest(
                projectRoot: root,
                planPath: planPath,
                plan: try makePlan(),
                subcommand: .plan
            )
        )

        #expect(result.summaryReport?.localeCount == 2)
        #expect(result.summaryReport?.deviceCount == 2)
        #expect(result.summaryReport?.shotCount == 2)
        #expect(result.artifacts.contains(where: { $0.hasSuffix("/run.json") }))
    }

    @Test func captureMaterializesRawPNGsAndManifest() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let planPath = root.appending(path: "config/screenshots.plan.yaml")
        try writePlan(to: planPath)

        let engine = ScreenshotsEngine()
        let result = try engine.run(
            request: ScreenshotRequest(
                projectRoot: root,
                planPath: planPath,
                plan: try makePlan(),
                subcommand: .capture
            )
        )

        #expect(result.capturedShots.count == 6)
        #expect(result.artifacts.contains(where: { $0.hasSuffix("/run.json") }))
        #expect(FileManager.default.fileExists(atPath: root.appending(path: "screenshots/raw/en-US/iphone-69/today-home.png").path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: root.appending(path: "screenshots/raw/ko-KR/ipad-13/today-home.png").path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: root.appending(path: "screenshots/raw/manifest.json").path(percentEncoded: false)))
    }

    @Test func composeThenValidatePassesAndWritesExportManifest() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let planPath = root.appending(path: "config/screenshots.plan.yaml")
        try writePlan(to: planPath)
        let plan = try makePlan()
        let engine = ScreenshotsEngine()

        _ = try engine.run(
            request: ScreenshotRequest(projectRoot: root, planPath: planPath, plan: plan, subcommand: .capture)
        )
        let composeResult = try engine.run(
            request: ScreenshotRequest(projectRoot: root, planPath: planPath, plan: plan, subcommand: .compose)
        )
        let validateResult = try engine.run(
            request: ScreenshotRequest(projectRoot: root, planPath: planPath, plan: plan, subcommand: .validate)
        )

        #expect(composeResult.composedFiles.count == 6)
        #expect(composeResult.artifacts.contains(where: { $0.hasSuffix("/manifest.json") }))
        #expect(FileManager.default.fileExists(atPath: root.appending(path: "screenshots/export/en-US/iphone-69/today-home.png").path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: root.appending(path: "screenshots/export/manifest.json").path(percentEncoded: false)))
        #expect(validateResult.valid == true)
        #expect(validateResult.artifacts.contains(where: { $0.hasSuffix("/run.json") }))
    }

    @Test func validateFailsWhenExpectedOutputIsMissing() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let planPath = root.appending(path: "config/screenshots.plan.yaml")
        try writePlan(to: planPath)
        let plan = try makePlan()
        let engine = ScreenshotsEngine()

        _ = try engine.run(
            request: ScreenshotRequest(projectRoot: root, planPath: planPath, plan: plan, subcommand: .capture)
        )
        _ = try engine.run(
            request: ScreenshotRequest(projectRoot: root, planPath: planPath, plan: plan, subcommand: .compose)
        )
        try FileManager.default.removeItem(at: root.appending(path: "screenshots/export/en-US/iphone-69/today-home.png"))

        do {
            _ = try engine.run(
                request: ScreenshotRequest(projectRoot: root, planPath: planPath, plan: plan, subcommand: .validate)
            )
            Issue.record("expected ScreenshotsEngineError.failed")
        } catch ScreenshotsEngineError.failed(let classification, _, let artifacts, _, _, _, _, _, let missingOutputs, _, let valid) {
            #expect(classification == .validation)
            #expect(valid == false)
            #expect(missingOutputs.contains(root.appending(path: "screenshots/export/en-US/iphone-69/today-home.png").path(percentEncoded: false)))
            #expect(artifacts.contains(where: { $0.hasSuffix("/run.json") }))
        }
    }
}

private extension ScreenshotsEngineIntegrationTests {
    func makeTempDir() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("bos-screenshots-\(ProcessInfo.processInfo.globallyUniqueString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    func writePlan(to path: URL) throws {
        try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(
            """
            schemaVersion: 1
            defaultLocale: en-US
            locales:
              - locale: en-US
                displayName: English (US)
              - locale: ko-KR
                displayName: Korean
            devices:
              - id: iphone-69
                name: iPhone 16 Pro Max
                family: iphone
                platform: simulator
                orientation: portrait
                pixelSize:
                  width: 1320
                  height: 2868
              - id: ipad-13
                name: iPad Pro 13-inch
                family: ipad
                platform: simulator
                orientation: portrait
                pixelSize:
                  width: 2064
                  height: 2752
            shots:
              - id: today-home
                screenID: SCR_TODAY_HOME
                locales: [en-US, ko-KR]
                devices: [iphone-69, ipad-13]
                outputName: today-home
              - id: task-detail
                screenID: SCR_TASK_DETAIL
                locales: [en-US, ko-KR]
                devices: [iphone-69]
                outputName: task-detail
            export:
              rootDirectory: screenshots/export
              format: png
              includeFrame: false
            """.utf8
        ).write(to: path, options: .atomic)
    }

    func makePlan() throws -> ScreenshotPlan {
        try ScreenshotPlan(
            defaultLocale: "en-US",
            locales: [
                try .init(locale: "en-US", displayName: "English (US)"),
                try .init(locale: "ko-KR", displayName: "Korean")
            ],
            devices: [
                try .init(
                    id: "iphone-69",
                    name: "iPhone 16 Pro Max",
                    family: "iphone",
                    platform: "simulator",
                    orientation: "portrait",
                    pixelSize: try .init(width: 1320, height: 2868)
                ),
                try .init(
                    id: "ipad-13",
                    name: "iPad Pro 13-inch",
                    family: "ipad",
                    platform: "simulator",
                    orientation: "portrait",
                    pixelSize: try .init(width: 2064, height: 2752)
                )
            ],
            shots: [
                try .init(
                    id: "today-home",
                    screenID: "SCR_TODAY_HOME",
                    locales: ["en-US", "ko-KR"],
                    devices: ["iphone-69", "ipad-13"],
                    outputName: "today-home"
                ),
                try .init(
                    id: "task-detail",
                    screenID: "SCR_TASK_DETAIL",
                    locales: ["en-US", "ko-KR"],
                    devices: ["iphone-69"],
                    outputName: "task-detail"
                )
            ],
            export: try .init(rootDirectory: "screenshots/export", format: "png", includeFrame: false)
        )
    }
}
