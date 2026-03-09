import Foundation

enum BootstrapStateSummaryKind: Sendable {
    case verify
    case release
    case releaseCheck
    case releaseRun
}

enum BosStateStore {
    private static let stateRelativePath = ".bos/state/bos.state.yaml"

    static func updateSummary(
        projectRoot: URL,
        kind: BootstrapStateSummaryKind,
        status: String,
        message: String
    ) {
        let statePath = projectRoot
            .standardizedFileURL
            .appending(path: stateRelativePath)
        let fm = FileManager.default
        guard fm.fileExists(atPath: statePath.path(percentEncoded: false)) else {
            return
        }

        guard let content = try? String(contentsOf: statePath, encoding: .utf8) else {
            return
        }

        let updated = replaceOrAppendSummaryBlock(
            in: content,
            key: summaryKey(for: kind),
            status: status,
            message: sanitizeMessage(message)
        )
        try? Data(updated.utf8).write(to: statePath, options: .atomic)
    }
}

extension BosStateStore {
    private static func summaryKey(for kind: BootstrapStateSummaryKind) -> String {
        switch kind {
        case .verify:
            return "verifySummary"
        case .release:
            return "releaseSummary"
        case .releaseCheck:
            return "releaseCheckSummary"
        case .releaseRun:
            return "releaseRunSummary"
        }
    }

    private static func sanitizeMessage(_ message: String) -> String {
        let collapsed = message
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let trimmed = collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
        let safe = trimmed.isEmpty ? "-" : trimmed
        return safe.replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func replaceOrAppendSummaryBlock(
        in content: String,
        key: String,
        status: String,
        message: String
    ) -> String {
        let block = [
            "\(key):",
            "  status: \"\(status)\"",
            "  message: \"\(message)\""
        ]

        var lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let hadTrailingNewline = content.hasSuffix("\n")

        if let start = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines) == "\(key):" }) {
            var end = start + 1
            while end < lines.count {
                let line = lines[end]
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                let isTopLevelKey = !line.hasPrefix(" ") && !line.hasPrefix("\t") && trimmed.hasSuffix(":")
                if isTopLevelKey {
                    break
                }
                end += 1
            }
            lines.replaceSubrange(start..<end, with: block)
        } else {
            if !lines.isEmpty, let last = lines.last, !last.isEmpty {
                lines.append("")
            }
            lines.append(contentsOf: block)
        }

        var output = lines.joined(separator: "\n")
        if hadTrailingNewline || !output.hasSuffix("\n") {
            output += "\n"
        }
        return output
    }
}
