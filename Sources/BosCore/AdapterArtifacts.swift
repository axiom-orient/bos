import Foundation

public struct AdapterRunEnvelope<Payload: Codable & Sendable>: Codable, Sendable {
    public let command: String
    public let status: String
    public let exitCode: Int
    public let summary: String
    public let payload: Payload

    public init(
        command: String,
        status: String,
        exitCode: Int,
        summary: String,
        payload: Payload
    ) {
        self.command = command
        self.status = status
        self.exitCode = exitCode
        self.summary = summary
        self.payload = payload
    }
}

public struct AdapterArtifactBundle: Sendable, Equatable {
    public let command: String
    public let directory: URL
    public let runJSONPath: URL
    public let stdoutLogPath: URL
    public let stderrLogPath: URL
    public let manifestPath: URL

    public var artifacts: [String] {
        [
            runJSONPath.path(percentEncoded: false),
            stdoutLogPath.path(percentEncoded: false),
            stderrLogPath.path(percentEncoded: false),
            manifestPath.path(percentEncoded: false)
        ]
    }
}

public struct AdapterArtifactManifest: Codable, Sendable, Equatable {
    public struct FileEntry: Codable, Sendable, Equatable {
        public let kind: String
        public let path: String

        public init(kind: String, path: String) {
            self.kind = kind
            self.path = path
        }
    }

    public let command: String
    public let createdAt: String
    public let files: [FileEntry]

    public init(command: String, createdAt: String, files: [FileEntry]) {
        self.command = command
        self.createdAt = createdAt
        self.files = files
    }
}

public enum AdapterArtifacts {
    public static func makeBundle(
        command: String,
        projectRoot: URL
    ) throws -> AdapterArtifactBundle {
        try makeBundle(command: command, projectRoot: projectRoot, stamp: RuntimeSupport.timestamp())
    }

    public static func makeBundle(
        command: String,
        projectRoot: URL,
        stamp: String
    ) throws -> AdapterArtifactBundle {
        let commandDirectory = try RuntimeArtifacts.makeDirectory(for: command, projectRoot: projectRoot)
        let bundleDirectory = commandDirectory.appending(path: "\(command)-\(stamp)")
        try FileManager.default.createDirectory(at: bundleDirectory, withIntermediateDirectories: true)

        return AdapterArtifactBundle(
            command: command,
            directory: bundleDirectory,
            runJSONPath: bundleDirectory.appending(path: "run.json"),
            stdoutLogPath: bundleDirectory.appending(path: "stdout.log"),
            stderrLogPath: bundleDirectory.appending(path: "stderr.log"),
            manifestPath: bundleDirectory.appending(path: "manifest.json")
        )
    }

    public static func write<Payload: Codable & Sendable>(
        bundle: AdapterArtifactBundle,
        envelope: AdapterRunEnvelope<Payload>,
        stdout: String,
        stderr: String,
        extraArtifacts: [URL] = []
    ) throws -> AdapterArtifactManifest {
        try write(
            bundle: bundle,
            envelope: envelope,
            stdout: stdout,
            stderr: stderr,
            extraArtifacts: extraArtifacts,
            createdAt: RuntimeSupport.isoNow()
        )
    }

    public static func write<Payload: Codable & Sendable>(
        bundle: AdapterArtifactBundle,
        envelope: AdapterRunEnvelope<Payload>,
        stdout: String,
        stderr: String,
        extraArtifacts: [URL],
        createdAt: String
    ) throws -> AdapterArtifactManifest {
        let fm = FileManager.default
        try RuntimeSupport.writeFile(to: bundle.stdoutLogPath, content: stdout)
        try RuntimeSupport.writeFile(to: bundle.stderrLogPath, content: stderr)
        try writeJSON(envelope, to: bundle.runJSONPath)

        let manifest = AdapterArtifactManifest(
            command: bundle.command,
            createdAt: createdAt,
            files: [
                .init(kind: "run", path: bundle.runJSONPath.path(percentEncoded: false)),
                .init(kind: "stdout", path: bundle.stdoutLogPath.path(percentEncoded: false)),
                .init(kind: "stderr", path: bundle.stderrLogPath.path(percentEncoded: false)),
                .init(kind: "manifest", path: bundle.manifestPath.path(percentEncoded: false))
            ] + extraArtifacts
                .filter { fm.fileExists(atPath: $0.path(percentEncoded: false)) }
                .map { .init(kind: "attachment", path: $0.path(percentEncoded: false)) }
        )
        try writeJSON(manifest, to: bundle.manifestPath)
        return manifest
    }

    private static func writeJSON<T: Encodable>(_ value: T, to path: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        try RuntimeSupport.writeFile(to: path, content: String(decoding: data, as: UTF8.self))
    }
}
