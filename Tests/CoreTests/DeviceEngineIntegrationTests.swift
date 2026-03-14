import Foundation
import os
import Testing
@testable import BosCore

@Suite
struct DeviceEngineIntegrationTests {
    @Test func listReturnsNormalizedInventoryAndArtifacts() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let engine = DeviceEngine(runner: FakeDeviceRunner())
        let result = try engine.run(
            request: DeviceRequest(projectRoot: root, subcommand: .list)
        )

        #expect(result.devices.count == 2)
        #expect(result.devices.contains(where: { $0.kind == "simulator" }))
        #expect(result.artifacts.contains(where: { $0.hasSuffix("/run.json") }))
    }

    @Test func registerInstallLaunchAndLogsUseTargetDevice() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let runner = FakeDeviceRunner()
        let engine = DeviceEngine(runner: runner)

        let register = try engine.run(
            request: DeviceRequest(projectRoot: root, subcommand: .register, deviceID: "DEV-456", name: "Axient iPhone")
        )
        let install = try engine.run(
            request: DeviceRequest(projectRoot: root, subcommand: .install, deviceID: "DEV-456", appPath: "/tmp/App.app")
        )
        let launch = try engine.run(
            request: DeviceRequest(projectRoot: root, subcommand: .launch, deviceID: "DEV-456", bundleIdentifier: "com.example.app")
        )
        let logs = try engine.run(
            request: DeviceRequest(projectRoot: root, subcommand: .logs, deviceID: "DEV-456")
        )

        #expect(register.targetDevice == "DEV-456")
        #expect(install.appPath == "/tmp/App.app")
        #expect(launch.bundleIdentifier == "com.example.app")
        #expect(logs.logLines == ["[device] boot complete", "[app] launched"])
    }

    @Test func doctorReturnsFindingsAndFailsWhenRunnerReportsIssues() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let runner = FakeDeviceRunner(doctorReport: DeviceDoctorReport(healthy: false, findings: ["devicectl not found"]))
        let engine = DeviceEngine(runner: runner)

        do {
            _ = try engine.run(
                request: DeviceRequest(projectRoot: root, subcommand: .doctor)
            )
            Issue.record("expected DeviceEngineError.failed")
        } catch DeviceEngineError.failed(let classification, _, let artifacts, _, _, _, _, _, let findings) {
            #expect(classification == .execution)
            #expect(findings == ["devicectl not found"])
            #expect(artifacts.contains(where: { $0.hasSuffix("/run.json") }))
        }
    }

    @Test func installRequiresAppPath() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let engine = DeviceEngine(runner: FakeDeviceRunner())
        do {
            _ = try engine.run(
                request: DeviceRequest(projectRoot: root, subcommand: .install, deviceID: "DEV-456")
            )
            Issue.record("expected DeviceEngineError.failed")
        } catch DeviceEngineError.failed(let classification, let summary, _, _, _, _, _, _, _) {
            #expect(classification == .validation)
            #expect(summary.contains("requires --app"))
        }
    }

    @Test func processRunnerUsesRealSimulatorCommandsForListInstallAndLaunch() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let commandRunner = RecordingProcessDeviceCommandRunner()
        let engine = DeviceEngine(runner: ProcessDeviceRunner(commandRunner: commandRunner))

        let list = try engine.run(
            request: DeviceRequest(projectRoot: root, subcommand: .list)
        )
        let install = try engine.run(
            request: DeviceRequest(projectRoot: root, subcommand: .install, deviceID: "SIM-123", appPath: "/tmp/App.app")
        )
        let launch = try engine.run(
            request: DeviceRequest(projectRoot: root, subcommand: .launch, deviceID: "SIM-123", bundleIdentifier: "com.example.app")
        )

        #expect(list.devices.count == 2)
        #expect(list.devices.allSatisfy { $0.kind == "simulator" })
        #expect(install.appPath == "/tmp/App.app")
        #expect(launch.bundleIdentifier == "com.example.app")
        #expect(commandRunner.commands.contains(["xcrun", "simctl", "list", "devices", "available", "-j"]))
        #expect(commandRunner.commands.contains(["xcrun", "simctl", "bootstatus", "SIM-123", "-b"]))
        #expect(commandRunner.commands.contains(["xcrun", "simctl", "install", "SIM-123", "/tmp/App.app"]))
        #expect(commandRunner.commands.contains(["xcrun", "simctl", "launch", "SIM-123", "com.example.app"]))
        #expect(!commandRunner.commands.contains(["xcrun", "simctl", "boot", "SIM-123"]))
    }

    @Test func processRunnerBootsShutdownSimulatorBeforeInstallAndLaunch() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let commandRunner = RecordingProcessDeviceCommandRunner()
        let engine = DeviceEngine(runner: ProcessDeviceRunner(commandRunner: commandRunner))

        _ = try engine.run(
            request: DeviceRequest(projectRoot: root, subcommand: .install, deviceID: "SIM-456", appPath: "/tmp/App.app")
        )
        _ = try engine.run(
            request: DeviceRequest(projectRoot: root, subcommand: .launch, deviceID: "SIM-456", bundleIdentifier: "com.example.app")
        )

        #expect(commandRunner.commands.contains(["xcrun", "simctl", "boot", "SIM-456"]))
        #expect(commandRunner.commands.filter { $0 == ["xcrun", "simctl", "bootstatus", "SIM-456", "-b"] }.count == 2)
        #expect(commandRunner.commands.contains(["xcrun", "simctl", "install", "SIM-456", "/tmp/App.app"]))
        #expect(commandRunner.commands.contains(["xcrun", "simctl", "launch", "SIM-456", "com.example.app"]))
    }

    @Test func processRunnerReturnsUnsupportedFailuresForRegisterAndLogs() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let engine = DeviceEngine(runner: ProcessDeviceRunner(commandRunner: RecordingProcessDeviceCommandRunner()))

        do {
            _ = try engine.run(
                request: DeviceRequest(projectRoot: root, subcommand: .register, deviceID: "SIM-123")
            )
            Issue.record("expected DeviceEngineError.failed")
        } catch DeviceEngineError.failed(let classification, let summary, _, _, _, _, _, _, _) {
            #expect(classification == .unsupported)
            #expect(summary.contains("not supported"))
        }

        do {
            _ = try engine.run(
                request: DeviceRequest(projectRoot: root, subcommand: .logs, deviceID: "SIM-123")
            )
            Issue.record("expected DeviceEngineError.failed")
        } catch DeviceEngineError.failed(let classification, let summary, _, _, _, _, _, _, _) {
            #expect(classification == .unsupported)
            #expect(summary.contains("not supported"))
        }
    }

    @Test func processRunnerDoctorReportsSimctlReadinessIssues() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let commandRunner = RecordingProcessDeviceCommandRunner(simctlExitCode: 1, simctlStderr: "simctl missing")
        let engine = DeviceEngine(runner: ProcessDeviceRunner(commandRunner: commandRunner))

        do {
            _ = try engine.run(
                request: DeviceRequest(projectRoot: root, subcommand: .doctor)
            )
            Issue.record("expected DeviceEngineError.failed")
        } catch DeviceEngineError.failed(let classification, let summary, _, _, _, _, _, _, let findings) {
            #expect(classification == .execution)
            #expect(summary == "device doctor found issues")
            #expect(findings.contains(where: { $0.contains("simctl device inventory failed") }))
        }
    }
}

private extension DeviceEngineIntegrationTests {
    final class FakeDeviceRunner: DeviceRunning {
        private struct State {
            var registrations: [String] = []
            var installs: [(String, String)] = []
            var launches: [(String, String)] = []
        }

        private let state = OSAllocatedUnfairLock(initialState: State())
        private let doctorReport: DeviceDoctorReport

        init(doctorReport: DeviceDoctorReport = DeviceDoctorReport(healthy: true, findings: [])) {
            self.doctorReport = doctorReport
        }

        func listDevices(projectRoot: URL) throws -> [DeviceRecord] {
            [
                try DeviceRecord(
                    id: "SIM-123",
                    name: "iPhone 16 Pro Max",
                    kind: "simulator",
                    platform: "iOS",
                    state: "booted",
                    runtime: "iOS 18.0",
                    isAvailable: true
                ),
                try DeviceRecord(
                    id: "DEV-456",
                    name: "Axient iPhone",
                    kind: "physical",
                    platform: "iOS",
                    state: "connected",
                    runtime: nil,
                    isAvailable: true
                )
            ]
        }

        func register(deviceID: String, name: String?, projectRoot: URL) throws {
            state.withLock { $0.registrations.append(deviceID) }
        }

        func install(deviceID: String, appPath: String, projectRoot: URL) throws {
            state.withLock { $0.installs.append((deviceID, appPath)) }
        }

        func launch(deviceID: String, bundleIdentifier: String, projectRoot: URL) throws {
            state.withLock { $0.launches.append((deviceID, bundleIdentifier)) }
        }

        func logs(deviceID: String, projectRoot: URL) throws -> [String] {
            ["[device] boot complete", "[app] launched"]
        }

        func doctor(projectRoot: URL) throws -> DeviceDoctorReport {
            doctorReport
        }
    }

    final class RecordingProcessDeviceCommandRunner: DeviceCommandRunning, @unchecked Sendable {
        private(set) var commands: [[String]] = []
        let simctlExitCode: Int32
        let simctlStderr: String
        let deviceListJSON: String

        init(
            simctlExitCode: Int32 = 0,
            simctlStderr: String = "",
            deviceListJSON: String = """
            {"devices":{"iOS 18.0":[
              {"udid":"SIM-123","name":"iPhone 16 Pro Max","state":"Booted","isAvailable":true},
              {"udid":"SIM-456","name":"iPad Pro 13-inch","state":"Shutdown","isAvailable":true}
            ]}}
            """
        ) {
            self.simctlExitCode = simctlExitCode
            self.simctlStderr = simctlStderr
            self.deviceListJSON = deviceListJSON
        }

        func run(command: [String], in workingDirectory: URL) throws -> DeviceCommandResult {
            commands.append(command)

            if command == ["xcrun", "simctl", "list", "devices", "available", "-j"] {
                return DeviceCommandResult(exitCode: simctlExitCode, stdout: deviceListJSON, stderr: simctlStderr)
            }
            if command == ["xcrun", "--find", "devicectl"] {
                return DeviceCommandResult(exitCode: 1, stderr: "devicectl not found")
            }
            if command.count == 4, Array(command.prefix(3)) == ["xcrun", "simctl", "boot"] {
                return DeviceCommandResult(exitCode: 0)
            }
            if command.count == 5, Array(command.prefix(3)) == ["xcrun", "simctl", "bootstatus"] {
                return DeviceCommandResult(exitCode: 0)
            }
            if command.count == 5, Array(command.prefix(3)) == ["xcrun", "simctl", "install"] {
                return DeviceCommandResult(exitCode: 0)
            }
            if command.count == 5, Array(command.prefix(3)) == ["xcrun", "simctl", "launch"] {
                return DeviceCommandResult(exitCode: 0)
            }
            return DeviceCommandResult(exitCode: 64, stderr: "unexpected command: \(command.joined(separator: " "))")
        }
    }

    func makeTempDir() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("bos-device-\(ProcessInfo.processInfo.globallyUniqueString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
