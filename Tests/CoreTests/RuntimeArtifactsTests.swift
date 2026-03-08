import Foundation
import Testing
@testable import BosCore

@Suite
struct RuntimeArtifactsTests {
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
}

private extension RuntimeArtifactsTests {
    func makeTempDir() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "bos-runtime-artifacts-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
