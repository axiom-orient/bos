import Foundation
import Testing
@testable import BosCore

@Suite
struct RuntimeArtifactsTests {
    private struct SamplePayload: Codable, Equatable, Sendable {
        let mode: String
    }

    @Test func makeDirectoryPrunesOldArtifactsAboveRetentionLimit() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let fm = FileManager.default
        let commandDirectory = root.appending(path: ".bos/artifacts/doctor")
        try fm.createDirectory(at: commandDirectory, withIntermediateDirectories: true)

        for index in 0..<130 {
            let file = commandDirectory.appending(path: String(format: "doctor-%03d.json", index))
            try Data("{}".utf8).write(to: file, options: .atomic)
            try fm.setAttributes(
                [.modificationDate: Date(timeIntervalSince1970: Double(index))],
                ofItemAtPath: file.path(percentEncoded: false)
            )
        }

        _ = try RuntimeArtifacts.makeDirectory(for: "doctor", projectRoot: root)

        let remaining = try fm.contentsOfDirectory(
            at: commandDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        let names = Set(remaining.map(\.lastPathComponent))
        #expect(remaining.count == 120)
        #expect(names.contains("doctor-129.json"))
        #expect(names.contains("doctor-010.json"))
        #expect(!names.contains("doctor-009.json"))
        #expect(!names.contains("doctor-000.json"))
    }

    @Test func adapterBundleCreatesNormalizedLayout() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let bundle = try AdapterArtifacts.makeBundle(
            command: "verify",
            projectRoot: root,
            stamp: "20260314000100"
        )

        #expect(FileManager.default.fileExists(atPath: bundle.directory.path(percentEncoded: false)))
        #expect(bundle.runJSONPath.lastPathComponent == "run.json")
        #expect(bundle.stdoutLogPath.lastPathComponent == "stdout.log")
        #expect(bundle.stderrLogPath.lastPathComponent == "stderr.log")
        #expect(bundle.manifestPath.lastPathComponent == "manifest.json")
        #expect(bundle.directory.lastPathComponent == "verify-20260314000100")
    }

    @Test func adapterBundleWritesRunLogsAndManifest() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let bundle = try AdapterArtifacts.makeBundle(
            command: "release-run",
            projectRoot: root,
            stamp: "20260314000200"
        )
        let attachment = bundle.directory.appending(path: "artifacts/app.ipa")
        try FileManager.default.createDirectory(at: attachment.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("ipa".utf8).write(to: attachment, options: .atomic)

        let envelope = AdapterRunEnvelope(
            command: "release-run",
            status: "success",
            exitCode: 0,
            summary: "release-run completed",
            payload: SamplePayload(mode: "submit")
        )

        let manifest = try AdapterArtifacts.write(
            bundle: bundle,
            envelope: envelope,
            stdout: "upload ok\n",
            stderr: "",
            extraArtifacts: [attachment],
            createdAt: "2026-03-14T00:02:00Z"
        )

        let decodedEnvelope = try JSONDecoder().decode(
            AdapterRunEnvelope<SamplePayload>.self,
            from: Data(try String(contentsOf: bundle.runJSONPath, encoding: .utf8).utf8)
        )
        let decodedManifest = try JSONDecoder().decode(
            AdapterArtifactManifest.self,
            from: Data(try String(contentsOf: bundle.manifestPath, encoding: .utf8).utf8)
        )

        #expect(decodedEnvelope.command == "release-run")
        #expect(decodedEnvelope.payload == SamplePayload(mode: "submit"))
        #expect(try String(contentsOf: bundle.stdoutLogPath, encoding: .utf8) == "upload ok\n")
        #expect(try String(contentsOf: bundle.stderrLogPath, encoding: .utf8).isEmpty)
        #expect(manifest == decodedManifest)
        #expect(decodedManifest.files.map(\.kind) == ["run", "stdout", "stderr", "manifest", "attachment"])
        #expect(decodedManifest.files.last?.path == attachment.path(percentEncoded: false))
    }
}

private extension RuntimeArtifactsTests {
    func makeTempDir() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "bos-runtime-artifacts-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
