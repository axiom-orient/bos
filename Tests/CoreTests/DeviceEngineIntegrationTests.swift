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

        func listDevices() throws -> [DeviceRecord] {
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

        func register(deviceID: String, name: String?) throws {
            state.withLock { $0.registrations.append(deviceID) }
        }

        func install(deviceID: String, appPath: String) throws {
            state.withLock { $0.installs.append((deviceID, appPath)) }
        }

        func launch(deviceID: String, bundleIdentifier: String) throws {
            state.withLock { $0.launches.append((deviceID, bundleIdentifier)) }
        }

        func logs(deviceID: String) throws -> [String] {
            ["[device] boot complete", "[app] launched"]
        }

        func doctor() throws -> DeviceDoctorReport {
            doctorReport
        }
    }

    func makeTempDir() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("bos-device-\(ProcessInfo.processInfo.globallyUniqueString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
