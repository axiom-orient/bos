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

        let engine = ScreenshotsEngine(captureAdapter: RecordingCaptureAdapter())
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

        let engine = ScreenshotsEngine(captureAdapter: RecordingCaptureAdapter())
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

        let manifest = try JSONDecoder().decode(
            Manifest.self,
            from: Data(contentsOf: root.appending(path: "screenshots/raw/manifest.json"))
        )
        #expect(manifest.entries.first?.captureBackend == "recording")
    }

    @Test func composeThenValidatePassesAndWritesExportManifest() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let planPath = root.appending(path: "config/screenshots.plan.yaml")
        try writePlan(to: planPath)
        let plan = try makePlan()
        let engine = ScreenshotsEngine(captureAdapter: RecordingCaptureAdapter())

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
        let engine = ScreenshotsEngine(captureAdapter: RecordingCaptureAdapter())

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

    @Test func captureUsesSimulatorAdapterCommandsAndWritesEvidence() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let planPath = root.appending(path: "config/screenshots.plan.yaml")
        try writePlan(to: planPath)
        let runner = RecordingCaptureRunner()
        let adapter = SimulatorScreenshotAdapter(runner: runner)
        let engine = ScreenshotsEngine(captureAdapter: adapter)

        let result = try engine.run(
            request: ScreenshotRequest(
                projectRoot: root,
                planPath: planPath,
                plan: try makePlan(),
                subcommand: .capture
            )
        )

        #expect(result.capturedShots.count == 6)
        #expect(runner.commands.contains(["xcrun", "simctl", "list", "devices", "available", "-j"]))
        #expect(runner.commands.contains(where: {
            $0.count == 5
                && Array($0.prefix(4)) == ["xcrun", "simctl", "bootstatus", runner.bootedUDID]
        }))
        #expect(runner.commands.contains(where: {
            $0.count == 6
                && Array($0.prefix(5)) == ["xcrun", "simctl", "io", runner.bootedUDID, "screenshot"]
        }))

        let manifest = try JSONDecoder().decode(
            Manifest.self,
            from: Data(contentsOf: root.appending(path: "screenshots/raw/manifest.json"))
        )
        #expect(manifest.entries.first?.captureBackend == "simctl")
        #expect(manifest.entries.contains(where: { $0.runtimeDeviceID == runner.bootedUDID }))
        #expect(manifest.entries.allSatisfy { $0.command.first == "xcrun" })
    }

    @Test func captureFailsWithSimulatorClassificationWhenNoMatchingSimulatorExists() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let planPath = root.appending(path: "config/screenshots.plan.yaml")
        try writePlan(to: planPath)
        let runner = RecordingCaptureRunner(availableDevicesJSON: #"{"devices":{"iOS 18.0":[]}}"#)
        let adapter = SimulatorScreenshotAdapter(runner: runner)
        let engine = ScreenshotsEngine(captureAdapter: adapter)

        do {
            _ = try engine.run(
                request: ScreenshotRequest(
                    projectRoot: root,
                    planPath: planPath,
                    plan: try makePlan(),
                    subcommand: .capture
                )
            )
            Issue.record("expected ScreenshotsEngineError.failed")
        } catch ScreenshotsEngineError.failed(let classification, let summary, _, _, _, _, let failedShots, _, _, _, _) {
            #expect(classification == .simulator)
            #expect(summary.contains("no available simulator named"))
            #expect(failedShots.count == 6)
        }
    }
}

private extension ScreenshotsEngineIntegrationTests {
    struct Manifest: Decodable {
        struct Entry: Decodable {
            let captureBackend: String
            let runtimeDeviceID: String?
            let command: [String]
        }

        let entries: [Entry]
    }

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

    struct RecordingCaptureAdapter: ScreenshotCaptureAdapting {
        func capture(
            asset: ScreenshotCaptureAsset,
            outputURL: URL,
            projectRoot: URL
        ) throws -> ScreenshotCaptureEvidence {
            try RuntimeSupport.writeFile(to: outputURL, data: Self.tinyPNGData)
            return ScreenshotCaptureEvidence(
                adapter: "recording",
                runtimeDeviceID: "SIM-\(asset.device.id)",
                command: ["recording-capture", asset.device.id, outputURL.path(percentEncoded: false)]
            )
        }

        private static let tinyPNGData = Data(
            base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+XG4sAAAAASUVORK5CYII="
        )!
    }

    final class RecordingCaptureRunner: ScreenshotCaptureRunning, @unchecked Sendable {
        private(set) var commands: [[String]] = []
        let availableDevicesJSON: String
        let bootedUDID: String

        init(
            availableDevicesJSON: String = """
            {"devices":{"iOS 18.0":[
              {"udid":"SIM-IPHONE-69","name":"iPhone 16 Pro Max","state":"Booted","isAvailable":true},
              {"udid":"SIM-IPAD-13","name":"iPad Pro 13-inch","state":"Shutdown","isAvailable":true}
            ]}}
            """,
            bootedUDID: String = "SIM-IPHONE-69"
        ) {
            self.availableDevicesJSON = availableDevicesJSON
            self.bootedUDID = bootedUDID
        }

        func run(command: [String], in workingDirectory: URL) throws -> ScreenshotCaptureCommandResult {
            commands.append(command)

            if command == ["xcrun", "simctl", "list", "devices", "available", "-j"] {
                return ScreenshotCaptureCommandResult(exitCode: 0, stdout: availableDevicesJSON)
            }

            if command.count == 4, Array(command.prefix(3)) == ["xcrun", "simctl", "boot"] {
                return ScreenshotCaptureCommandResult(exitCode: 0)
            }

            if command.count == 5, Array(command.prefix(3)) == ["xcrun", "simctl", "bootstatus"] {
                return ScreenshotCaptureCommandResult(exitCode: 0)
            }

            if command.count == 6,
               command[0] == "xcrun",
               command[1] == "simctl",
               command[2] == "io",
               command[4] == "screenshot" {
                let outputPath = URL(fileURLWithPath: command[5], isDirectory: false)
                try RuntimeSupport.writeFile(to: outputPath, data: Self.tinyPNGData)
                return ScreenshotCaptureCommandResult(exitCode: 0)
            }

            return ScreenshotCaptureCommandResult(exitCode: 64, stderr: "unexpected command: \(command.joined(separator: " "))")
        }

        private static let tinyPNGData = Data(
            base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+XG4sAAAAASUVORK5CYII="
        )!
    }
}
