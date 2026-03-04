import Foundation

enum RuntimeSupport {
    static func writeFile(to path: URL, content: String) throws {
        try writeFile(to: path, data: Data(content.utf8))
    }

    static func writeFile(to path: URL, data: Data) throws {
        let fm = FileManager.default
        let parent = path.deletingLastPathComponent()
        try fm.createDirectory(at: parent, withIntermediateDirectories: true)
        try data.write(to: path, options: .atomic)
    }

    static func isoNow() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: .now)
    }

    static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMddHHmmss"
        return formatter.string(from: .now)
    }

    static func uniqueOrdered<T: Hashable>(_ values: [T]) -> [T] {
        var seen = Set<T>()
        var result: [T] = []
        result.reserveCapacity(values.count)
        for value in values where seen.insert(value).inserted {
            result.append(value)
        }
        return result
    }
}
