import Foundation
import Testing
@testable import BosCore

@Suite
struct RepositoryIntegrityTests {
    @Test func repositoryMarkdownLinksResolveWithoutAbsoluteLocalPaths() throws {
        let root = repositoryRoot()
        let repoMarkdownFiles = try markdownScopeRoots()
            .flatMap { try markdownFiles(under: root.appending(path: $0)) }
            .sorted { $0.path(percentEncoded: false) < $1.path(percentEncoded: false) }

        var issues: [String] = []
        for file in repoMarkdownFiles {
            let content = try String(contentsOf: file, encoding: .utf8)
            issues += validateMarkdownLinks(in: content, file: file, repositoryRoot: root)
        }

        #expect(issues.isEmpty, "Broken or non-portable markdown links:\n\(issues.joined(separator: "\n"))")
    }

    @Test func packagedResourcesMatchRepositorySources() throws {
        let root = repositoryRoot()
        let sourceRoot = root.appending(path: "Sources/BosCore/Resources")
        let bundleRoot = try #require(Bundle.module.resourceURL)

        for resourceFolder in ["project_bootstrap", "tma_plugin"] {
            let sourceFolder = sourceRoot.appending(path: resourceFolder)
            let bundleFolder = bundleRoot.appending(path: resourceFolder)
            let sourceFiles = try resourceFiles(under: sourceFolder)

            for sourceFile in sourceFiles {
                let relativePath = sourceFile.path(percentEncoded: false)
                    .replacingOccurrences(of: sourceFolder.path(percentEncoded: false) + "/", with: "")
                let bundledFile = bundleFolder.appending(path: relativePath)
                #expect(
                    FileManager.default.fileExists(atPath: bundledFile.path(percentEncoded: false)),
                    "Missing bundled resource: \(resourceFolder)/\(relativePath)"
                )
                let sourceData = try Data(contentsOf: sourceFile)
                let bundledData = try Data(contentsOf: bundledFile)
                #expect(sourceData == bundledData, "Bundled resource drift: \(resourceFolder)/\(relativePath)")
            }
        }
    }

    @Test func compatibilityAndTemplatePolicyDocsExistWithRequiredSections() throws {
        let root = repositoryRoot()
        let expectations: [(String, [String])] = [
            ("docs/COMPATIBILITY_POLICY.md", ["Path Compatibility Matrix", "Compatibility Window"]),
            ("docs/TEMPLATE_VERSIONING.md", ["Version Sources", "Required Proof"]),
            ("docs/TEST_MATRIX.md", ["Toolchain Matrix", "Required CI Gates"]),
            ("docs/MIGRATION_COMPLETION_CHECKLIST.md", ["Exit Criteria For BOS v2", "Fresh-Clone Path"])
        ]

        for (relativePath, requiredSnippets) in expectations {
            let file = root.appending(path: relativePath)
            #expect(FileManager.default.fileExists(atPath: file.path(percentEncoded: false)), "Missing required policy doc: \(relativePath)")
            let content = try String(contentsOf: file, encoding: .utf8)
            for snippet in requiredSnippets {
                #expect(content.contains(snippet), "\(relativePath) missing required section: \(snippet)")
            }
        }
    }

    @Test func sourceRepositoryKeepsManagedProjectExamplesOutOfRoot() throws {
        let root = repositoryRoot()
        let fm = FileManager.default

        #expect(!fm.fileExists(atPath: root.appending(path: "bos.project.yaml").path(percentEncoded: false)))
        #expect(!fm.fileExists(atPath: root.appending(path: "config/bos.profile.yaml").path(percentEncoded: false)))
        #expect(!fm.fileExists(atPath: root.appending(path: "config/release.policy.yaml").path(percentEncoded: false)))
        #expect(!fm.fileExists(atPath: root.appending(path: "config/screenshots.plan.yaml").path(percentEncoded: false)))

        let expectedExamples = [
            "bos_blueprint/examples/bos.project.yaml",
            "bos_blueprint/examples/bos.profile.yaml",
            "bos_blueprint/examples/blueprint.lock.yaml",
            "bos_blueprint/examples/release.policy.yaml",
            "bos_blueprint/examples/screenshots.plan.yaml"
        ]

        for relativePath in expectedExamples {
            #expect(
                fm.fileExists(atPath: root.appending(path: relativePath).path(percentEncoded: false)),
                "Missing managed-project example fixture: \(relativePath)"
            )
        }
    }
}

private extension RepositoryIntegrityTests {
    func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func markdownScopeRoots() throws -> [String] {
        let fm = FileManager.default
        return [
            "README.md",
            "AGENTS.md",
            "docs",
            "plans",
            fm.fileExists(atPath: repositoryRoot().appending(path: "bos_blueprint/docs").path(percentEncoded: false))
                ? "bos_blueprint/docs"
                : nil
        ].compactMap { $0 }
    }

    func markdownFiles(under path: URL) throws -> [URL] {
        let fm = FileManager.default
        let pathString = path.path(percentEncoded: false)
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: pathString, isDirectory: &isDirectory) else {
            return []
        }
        if !isDirectory.boolValue {
            return path.pathExtension.lowercased() == "md" ? [path] : []
        }

        guard let enumerator = fm.enumerator(
            at: path,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [URL] = []
        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true, fileURL.pathExtension.lowercased() == "md" else {
                continue
            }
            files.append(fileURL)
        }
        return files
    }

    func resourceFiles(under path: URL) throws -> [URL] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: path,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [URL] = []
        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else {
                continue
            }
            files.append(fileURL)
        }
        return files.sorted { $0.path(percentEncoded: false) < $1.path(percentEncoded: false) }
    }

    func validateMarkdownLinks(in content: String, file: URL, repositoryRoot: URL) -> [String] {
        let pattern = #"\[[^\]]+\]\(([^)]+)\)"#
        let regex = try! NSRegularExpression(pattern: pattern)

        var issues: [String] = []
        var inFence = false

        for (index, rawLine) in content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init).enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("```") {
                inFence.toggle()
                continue
            }
            if inFence {
                continue
            }

            let nsRange = NSRange(rawLine.startIndex..<rawLine.endIndex, in: rawLine)
            let matches = regex.matches(in: rawLine, range: nsRange)
            for match in matches {
                guard let range = Range(match.range(at: 1), in: rawLine) else { continue }
                let rawTarget = String(rawLine[range])
                let target = normalizeMarkdownTarget(rawTarget)
                guard !target.isEmpty else { continue }
                if target.hasPrefix("http://") || target.hasPrefix("https://") || target.hasPrefix("mailto:") || target.hasPrefix("#") {
                    continue
                }
                if target.hasPrefix("/Users/") || target.hasPrefix("file://") {
                    issues.append("\(relativePath(file, repositoryRoot: repositoryRoot)):\(index + 1) absolute local link \(target)")
                    continue
                }
                if target.contains("://") {
                    continue
                }

                let pathComponent = target.split(separator: "#", maxSplits: 1).first.map(String.init) ?? target
                guard !pathComponent.isEmpty else { continue }
                let resolved = file.deletingLastPathComponent().appending(path: pathComponent).standardizedFileURL
                if !FileManager.default.fileExists(atPath: resolved.path(percentEncoded: false)) {
                    issues.append("\(relativePath(file, repositoryRoot: repositoryRoot)):\(index + 1) missing link target \(target)")
                }
            }
        }

        return issues
    }

    func normalizeMarkdownTarget(_ rawTarget: String) -> String {
        let trimmed = rawTarget.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("<"), trimmed.hasSuffix(">") {
            return String(trimmed.dropFirst().dropLast())
        }
        return trimmed.split(separator: " ", maxSplits: 1).first.map(String.init) ?? trimmed
    }

    func relativePath(_ file: URL, repositoryRoot: URL) -> String {
        file.path(percentEncoded: false)
            .replacingOccurrences(of: repositoryRoot.path(percentEncoded: false) + "/", with: "")
    }
}
