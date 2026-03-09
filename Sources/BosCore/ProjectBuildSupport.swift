import Foundation

enum ProjectBuildSupport {
    nonisolated(unsafe) private static let appNameRegex = #/let\s+appName\s*=\s*"([^"]+)"/#

    static func resolveBuildScheme(projectRoot: URL, profileName: String) -> String {
        let appProjectPath = projectRoot.appending(path: "Projects/App/Project.swift")
        if let appScheme = readAppScheme(from: appProjectPath) {
            return appScheme
        }
        return sanitizeModuleName(profileName)
    }

    static func readAppScheme(from projectFile: URL) -> String? {
        guard let text = try? String(contentsOf: projectFile, encoding: .utf8),
              let match = try? appNameRegex.firstMatch(in: text) else {
            return nil
        }
        let name = String(match.1).trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    static func sanitizeModuleName(_ raw: String) -> String {
        "\(NameNormalizer.pascalCase(raw, fallback: "App"))App"
    }

    static func resolveWorkspacePath(projectRoot: URL) -> URL? {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: projectRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        let workspaces = contents
            .filter { $0.pathExtension == "xcworkspace" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        return workspaces.first
    }

    static func cleanupGeneratedProjectArtifacts(at root: URL) {
        let fm = FileManager.default

        if let topLevel = try? fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            for item in topLevel {
                let name = item.lastPathComponent
                if item.pathExtension == "xcworkspace" || name.hasPrefix("TemporaryDirectory.") {
                    try? fm.removeItem(at: item)
                }
                if name == "swift-generated-sources" || (name.hasPrefix("_") && name.hasSuffix(".lock")) {
                    try? fm.removeItem(at: item)
                }
            }
        }

        let projectsRoot = root.appending(path: "Projects")
        if fm.fileExists(atPath: projectsRoot.path(percentEncoded: false)),
           let enumerator = fm.enumerator(
               at: projectsRoot,
               includingPropertiesForKeys: nil,
               options: [.skipsHiddenFiles]
           ) {
            for case let url as URL in enumerator {
                let name = url.lastPathComponent
                if url.pathExtension == "xcodeproj" || name == "Derived" {
                    try? fm.removeItem(at: url)
                    enumerator.skipDescendants()
                }
            }
        }

        let tuistBuild = root.appending(path: "Tuist/.build")
        if fm.fileExists(atPath: tuistBuild.path(percentEncoded: false)) {
            try? fm.removeItem(at: tuistBuild)
        }

        let tuistResolved = root.appending(path: "Tuist/Package.resolved")
        if fm.fileExists(atPath: tuistResolved.path(percentEncoded: false)) {
            try? fm.removeItem(at: tuistResolved)
        }
    }
}
