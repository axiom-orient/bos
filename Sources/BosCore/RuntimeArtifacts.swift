import Foundation

enum RuntimeArtifacts {
    private static let fixedWorkspaceRoot = URL(
        fileURLWithPath: "/Users/axient/repository/bos",
        isDirectory: true
    )

    static func makeDirectory(for command: String) throws -> URL {
        let fm = FileManager.default
        let root = fixedWorkspaceRoot.appending(path: "temp")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)

        let directory = root.appending(path: command)
        if fm.fileExists(atPath: directory.path(percentEncoded: false)) {
            let children = try fm.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            for child in children {
                try fm.removeItem(at: child)
            }
        } else {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }
}
