import Foundation

public struct CommandOutput: Codable, Sendable, Equatable {
    public let command: String
    public let status: String
    public let exitCode: Int
    public let summary: String
    public let artifacts: [String]

    public init(
        command: String,
        status: String,
        exitCode: Int,
        summary: String,
        artifacts: [String] = []
    ) {
        self.command = command
        self.status = status
        self.exitCode = exitCode
        self.summary = summary
        self.artifacts = artifacts
    }

    public func toJSONString(pretty: Bool = true) throws -> String {
        let encoder = JSONEncoder()
        if pretty {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        } else {
            encoder.outputFormatting = [.sortedKeys]
        }
        let data = try encoder.encode(self)
        return String(decoding: data, as: UTF8.self)
    }
}
