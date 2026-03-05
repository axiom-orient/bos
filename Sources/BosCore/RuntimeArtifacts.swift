import Foundation

enum RuntimeArtifacts {
    private static let artifactsRelativeRoot = ".bos/artifacts"
    private static let maxRetainedArtifactsPerCommand = 120

    static func makeDirectory(for command: String, projectRoot: URL) throws -> URL {
        let fm = FileManager.default
        let root = projectRoot
            .standardizedFileURL
            .appending(path: artifactsRelativeRoot)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)

        let directory = root.appending(path: command)
        if !fm.fileExists(atPath: directory.path(percentEncoded: false)) {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        try pruneOldArtifacts(in: directory)
        return directory
    }

    private static func pruneOldArtifacts(in directory: URL) throws {
        let fm = FileManager.default
        let files = try fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        guard files.count > maxRetainedArtifactsPerCommand else { return }

        let dated = files.map { url -> (url: URL, modified: Date) in
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            return (url, values?.contentModificationDate ?? .distantPast)
        }
        let sorted = dated.sorted { lhs, rhs in
            if lhs.modified == rhs.modified {
                return lhs.url.path(percentEncoded: false) > rhs.url.path(percentEncoded: false)
            }
            return lhs.modified > rhs.modified
        }

        for entry in sorted.dropFirst(maxRetainedArtifactsPerCommand) {
            try fm.removeItem(at: entry.url)
        }
    }
}
