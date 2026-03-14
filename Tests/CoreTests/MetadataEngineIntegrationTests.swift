import Foundation
import os
import Testing
@testable import BosCore

@Suite
struct MetadataEngineIntegrationTests {
    @Test func pullWritesLocalizedMetadataAndArtifacts() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeMetadataReadme(root: root)

        let runner = FakeMetadataRunner(remote: [
            "en-US": [
                "name.txt": "Daycraft",
                "subtitle.txt": "Calm planning",
                "description.txt": "Track the day.",
                "keywords.txt": "planner,calendar",
                "release_notes.txt": "Bug fixes"
            ],
            "ko-KR": [
                "name.txt": "데이크래프트",
                "subtitle.txt": "차분한 계획",
                "description.txt": "하루를 기록하세요.",
                "keywords.txt": "플래너,캘린더",
                "release_notes.txt": "버그 수정"
            ]
        ])
        let engine = MetadataEngine(runner: runner)

        let result = try engine.run(
            request: MetadataRequest(
                projectRoot: root,
                profile: try makeProfile(),
                environment: requiredEnvironment(),
                subcommand: .pull
            )
        )

        #expect(result.locales == ["en-US", "ko-KR"])
        #expect(result.validation?.valid == true)
        #expect(result.artifacts.contains(where: { $0.hasSuffix("/run.json") }))
        #expect(FileManager.default.fileExists(atPath: root.appending(path: "metadata/en-US/description.txt").path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: root.appending(path: "metadata/ko-KR/release_notes.txt").path(percentEncoded: false)))
    }

    @Test func diffReportsChangedFilesAndRemoteMissingLocale() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeMetadataReadme(root: root)
        try writeLocale(
            root: root,
            locale: "en-US",
            files: [
                "name.txt": "Daycraft",
                "subtitle.txt": "Calm planning",
                "description.txt": "Local description",
                "keywords.txt": "planner,calendar",
                "release_notes.txt": "Bug fixes"
            ]
        )

        let runner = FakeMetadataRunner(remote: [
            "en-US": [
                "name.txt": "Daycraft",
                "subtitle.txt": "Calm planning",
                "description.txt": "Remote description",
                "keywords.txt": "planner,calendar",
                "release_notes.txt": "Bug fixes"
            ],
            "ko-KR": [
                "name.txt": "데이크래프트",
                "subtitle.txt": "차분한 계획",
                "description.txt": "하루를 기록하세요.",
                "keywords.txt": "플래너,캘린더",
                "release_notes.txt": "버그 수정"
            ]
        ])
        let engine = MetadataEngine(runner: runner)

        let result = try engine.run(
            request: MetadataRequest(
                projectRoot: root,
                profile: try makeProfile(),
                environment: requiredEnvironment(),
                subcommand: .diff
            )
        )

        #expect(result.diff?.hasChanges == true)
        #expect(result.diff?.changedFiles.contains("metadata/en-US/description.txt") == true)
        #expect(result.diff?.missingLocales == ["ko-KR"])
    }

    @Test func pushUpdatesRemoteAndDiffBecomesClean() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeMetadataReadme(root: root)
        try writeLocale(
            root: root,
            locale: "en-US",
            files: [
                "name.txt": "Daycraft",
                "subtitle.txt": "Calm planning",
                "description.txt": "Updated description",
                "keywords.txt": "planner,calendar",
                "release_notes.txt": "Bug fixes"
            ]
        )

        let runner = FakeMetadataRunner(remote: [
            "en-US": [
                "name.txt": "Daycraft",
                "subtitle.txt": "Calm planning",
                "description.txt": "Old description",
                "keywords.txt": "planner,calendar",
                "release_notes.txt": "Bug fixes"
            ]
        ])
        let engine = MetadataEngine(runner: runner)

        let pushResult = try engine.run(
            request: MetadataRequest(
                projectRoot: root,
                profile: try makeProfile(),
                environment: requiredEnvironment(),
                subcommand: .push
            )
        )
        #expect(pushResult.pushedLocales == ["en-US"])

        let diffResult = try engine.run(
            request: MetadataRequest(
                projectRoot: root,
                profile: try makeProfile(),
                environment: requiredEnvironment(),
                subcommand: .diff
            )
        )
        #expect(diffResult.diff?.hasChanges == false)
    }

    @Test func validateFailsWhenRequiredFileIsMissing() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }
        try writeMetadataReadme(root: root)
        try writeLocale(
            root: root,
            locale: "en-US",
            files: [
                "name.txt": "Daycraft",
                "subtitle.txt": "Calm planning",
                "keywords.txt": "planner,calendar",
                "release_notes.txt": "Bug fixes"
            ]
        )

        let engine = MetadataEngine(runner: FakeMetadataRunner(remote: [:]))

        do {
            _ = try engine.run(
                request: MetadataRequest(
                    projectRoot: root,
                    profile: try makeProfile(),
                    environment: [:],
                    subcommand: .validate
                )
            )
            Issue.record("expected MetadataEngineError.failed")
        } catch MetadataEngineError.failed(let classification, _, _, let artifacts, _, _) {
            #expect(classification == .validation)
            #expect(artifacts.contains(where: { $0.hasSuffix("/run.json") }))
        }
    }
}

private extension MetadataEngineIntegrationTests {
    final class FakeMetadataRunner: MetadataCommandRunning {
        private struct State {
            var remote: [String: [String: String]]
            var commands: [[String]] = []
        }

        private let state: OSAllocatedUnfairLock<State>

        init(remote: [String: [String: String]]) {
            self.state = OSAllocatedUnfairLock(initialState: State(remote: remote))
        }

        func run(command: [String], in workingDirectory: URL, environment: [String : String]) throws -> MetadataCommandResult {
            state.withLock { $0.commands.append(command) }
            if command.contains("download_metadata") {
                let metadataPath = try metadataPath(from: command)
                try materializeRemote(to: URL(fileURLWithPath: metadataPath, isDirectory: true))
                return MetadataCommandResult(exitCode: 0, stdout: "downloaded")
            }
            let metadataPath = try metadataPath(from: command)
            try absorbLocal(from: URL(fileURLWithPath: metadataPath, isDirectory: true))
            return MetadataCommandResult(exitCode: 0, stdout: "uploaded")
        }

        private func metadataPath(from command: [String]) throws -> String {
            guard let index = command.firstIndex(of: "--metadata_path"), command.indices.contains(index + 1) else {
                throw NSError(domain: "MetadataEngineIntegrationTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "missing --metadata_path"])
            }
            return command[index + 1]
        }

        private func materializeRemote(to root: URL) throws {
            let remote = state.withLock { $0.remote }
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            for (locale, files) in remote {
                let localeRoot = root.appending(path: locale)
                try FileManager.default.createDirectory(at: localeRoot, withIntermediateDirectories: true)
                for (name, content) in files {
                    try Data(content.utf8).write(to: localeRoot.appending(path: name), options: .atomic)
                }
            }
        }

        private func absorbLocal(from root: URL) throws {
            var nextRemote: [String: [String: String]] = [:]
            if let locales = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
                for localeDir in locales {
                    var isDirectory: ObjCBool = false
                    guard FileManager.default.fileExists(atPath: localeDir.path(percentEncoded: false), isDirectory: &isDirectory), isDirectory.boolValue else {
                        continue
                    }
                    let locale = localeDir.lastPathComponent
                    var files: [String: String] = [:]
                    let entries = try FileManager.default.contentsOfDirectory(at: localeDir, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
                    for file in entries {
                        let name = file.lastPathComponent
                        files[name] = try String(contentsOf: file, encoding: .utf8)
                    }
                    nextRemote[locale] = files
                }
            }
            let remoteSnapshot = nextRemote
            state.withLock { $0.remote = remoteSnapshot }
        }
    }

    func makeTempDir() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("bos-metadata-\(ProcessInfo.processInfo.globallyUniqueString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    func makeProfile() throws -> Profile {
        try Profile(
            schemaVersion: 1,
            name: "default",
            defaults: .init(
                deploymentTarget: "18.0",
                appTargets: .init(controlsExtension: false, uiTests: true)
            ),
            identity: .init(appIdentifier: "com.axiomorient.daycraft"),
            release: .init(primaryLanguage: "en-US"),
            featurePattern: .init(sourcesInterface: true, designFolder: false),
            rules: try .init(
                testingStyle: "swift-testing",
                forbidPatterns: ["@unchecked Sendable", "Date()", "UUID()"]
            )
        )
    }

    func requiredEnvironment() -> [String: String] {
        [
            "ASC_ISSUER_ID": "123E4567-E89B-12D3-A456-426614174000",
            "ASC_KEY_ID": "AB12CD34EF",
            "ASC_KEY_P8_BASE64": "LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0tCmZha2Uta2V5Ci0tLS0tRU5EIFBSSVZBVEUgS0VZLS0tLS0=",
            "MATCH_PASSWORD": "unused"
        ]
    }

    func writeMetadataReadme(root: URL) throws {
        let readme = root.appending(path: "metadata/README.md")
        try FileManager.default.createDirectory(at: readme.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("# Metadata\n".utf8).write(to: readme, options: .atomic)
    }

    func writeLocale(root: URL, locale: String, files: [String: String]) throws {
        let localeRoot = root.appending(path: "metadata/\(locale)")
        try FileManager.default.createDirectory(at: localeRoot, withIntermediateDirectories: true)
        for (name, content) in files {
            try Data(content.utf8).write(to: localeRoot.appending(path: name), options: .atomic)
        }
    }
}
