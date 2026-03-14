import Foundation

public struct ToolchainLock: Codable, Sendable {
    public let schemaVersion: Int
    public let tools: Tools
    public let tmaPluginRef: TMAPluginRef

    public init(schemaVersion: Int, tools: Tools, tmaPluginRef: TMAPluginRef) throws {
        self.schemaVersion = schemaVersion
        self.tools = tools
        self.tmaPluginRef = tmaPluginRef
        try validate()
    }
}

extension ToolchainLock: StrictSchema {
    static let schemaName = "ToolchainLock"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case tools
        case tmaPluginRef
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        self.tools = try c.decode(Tools.self, forKey: .tools)
        self.tmaPluginRef = try c.decode(TMAPluginRef.self, forKey: .tmaPluginRef)
        try validate()
    }

    func validate() throws {
        guard schemaVersion == 2 else {
            throw SchemaValidationError.unsupportedSchemaVersion(
                schema: Self.schemaName,
                expected: 2,
                actual: schemaVersion
            )
        }
    }
}

extension ToolchainLock {
    public struct Tools: Codable, Sendable {
        public let swift: ToolRequirement
        public let xcode: ToolRequirement?
        public let tuist: ToolRequirement
        public let ruby: ToolRequirement?
        public let bundler: ToolRequirement?
        public let node: ToolRequirement?
        public let fastlane: ToolRequirement
        public let asc: ToolRequirement
        public let devicectl: ToolRequirement?
        public let simctl: ToolRequirement?

        public init(
            swift: ToolRequirement,
            xcode: ToolRequirement? = nil,
            tuist: ToolRequirement,
            ruby: ToolRequirement? = nil,
            bundler: ToolRequirement? = nil,
            node: ToolRequirement? = nil,
            fastlane: ToolRequirement,
            asc: ToolRequirement? = nil,
            devicectl: ToolRequirement? = nil,
            simctl: ToolRequirement? = nil
        ) throws {
            self.swift = swift
            self.xcode = xcode
            self.tuist = tuist
            self.ruby = ruby
            self.bundler = bundler
            self.node = node
            self.fastlane = fastlane
            if let asc {
                self.asc = asc
            } else {
                self.asc = try Self.defaultASCRequirement()
            }
            self.devicectl = devicectl
            self.simctl = simctl
            try validate()
        }

        fileprivate static func defaultASCRequirement() throws -> ToolRequirement {
            try ToolRequirement(
                versionRule: .init(kind: "semver-range", value: ">=0.1.0"),
                requiredFor: [ToolchainLock.commandAppRegister, ToolchainLock.commandReleaseCheck, ToolchainLock.commandReleaseRun],
                installHints: [
                    "brew install asc",
                    "curl -fsSL https://asccli.sh/install | bash"
                ]
            )
        }
    }

    public struct ToolRequirement: Codable, Sendable {
        public let versionRule: VersionRule
        public let requiredFor: [String]
        public let installHints: [String]

        public init(versionRule: VersionRule, requiredFor: [String], installHints: [String]) throws {
            self.versionRule = versionRule
            self.requiredFor = requiredFor
            self.installHints = installHints
            try validate()
        }
    }

    public struct VersionRule: Codable, Sendable {
        public let kind: String
        public let value: String

        public init(kind: String, value: String) throws {
            self.kind = kind
            self.value = value
            try validate()
        }
    }

    public struct TMAPluginRef: Codable, Sendable {
        public let type: String
        public let value: String

        public init(type: String, value: String) throws {
            self.type = type
            self.value = value
            try validate()
        }
    }
}

extension ToolchainLock.Tools: StrictSchema {
    static let schemaName = "ToolchainLock.tools"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case swift
        case xcode
        case tuist
        case ruby
        case bundler
        case node
        case fastlane
        case asc
        case devicectl
        case simctl
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.swift = try c.decode(ToolchainLock.ToolRequirement.self, forKey: .swift)
        self.xcode = try c.decodeIfPresent(ToolchainLock.ToolRequirement.self, forKey: .xcode)
        self.tuist = try c.decode(ToolchainLock.ToolRequirement.self, forKey: .tuist)
        self.ruby = try c.decodeIfPresent(ToolchainLock.ToolRequirement.self, forKey: .ruby)
        self.bundler = try c.decodeIfPresent(ToolchainLock.ToolRequirement.self, forKey: .bundler)
        self.node = try c.decodeIfPresent(ToolchainLock.ToolRequirement.self, forKey: .node)
        self.fastlane = try c.decode(ToolchainLock.ToolRequirement.self, forKey: .fastlane)
        if let asc = try c.decodeIfPresent(ToolchainLock.ToolRequirement.self, forKey: .asc) {
            self.asc = asc
        } else {
            self.asc = try Self.defaultASCRequirement()
        }
        self.devicectl = try c.decodeIfPresent(ToolchainLock.ToolRequirement.self, forKey: .devicectl)
        self.simctl = try c.decodeIfPresent(ToolchainLock.ToolRequirement.self, forKey: .simctl)
        try validate()
    }

    func validate() throws {}
}

extension ToolchainLock.ToolRequirement: StrictSchema {
    static let schemaName = "ToolchainLock.tools.toolRequirement"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case versionRule
        case requiredFor
        case installHints
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.versionRule = try c.decode(ToolchainLock.VersionRule.self, forKey: .versionRule)
        self.requiredFor = try c.decode([String].self, forKey: .requiredFor)
        self.installHints = try c.decode([String].self, forKey: .installHints)
        try validate()
    }

    func validate() throws {
        if requiredFor.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: "requiredFor", reason: "must not include empty command")
        }
        if installHints.isEmpty {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: "installHints", reason: "must not be empty")
        }
        if installHints.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: "installHints", reason: "must not include empty command")
        }
    }
}

extension ToolchainLock.VersionRule: StrictSchema {
    static let schemaName = "ToolchainLock.tools.versionRule"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case kind
        case value
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.kind = try c.decode(String.self, forKey: .kind)
        self.value = try c.decode(String.self, forKey: .value)
        try validate()
    }

    func validate() throws {
        let normalizedKind = kind.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedKind != "exact" && normalizedKind != "semver-range" && normalizedKind != "present" {
            throw SchemaValidationError.invalidValue(
                schema: Self.schemaName,
                field: "kind",
                reason: "must be one of: exact, semver-range, present"
            )
        }
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: "value", reason: "must not be empty")
        }
    }
}

extension ToolchainLock.TMAPluginRef: StrictSchema {
    static let schemaName = "ToolchainLock.tmaPluginRef"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case type
        case value
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try c.decode(String.self, forKey: .type)
        self.value = try c.decode(String.self, forKey: .value)
        try validate()
    }

    func validate() throws {
        if type.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: "type", reason: "must not be empty")
        }
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: "value", reason: "must not be empty")
        }
    }
}

extension ToolchainLock {
    public static let commandPlan = "plan"
    public static let commandApply = "apply"
    public static let commandVerify = "verify"
    public static let commandAppRegister = "app-register"
    public static let commandReleaseInit = "release-init"
    public static let commandReleaseCheck = "release-check"
    public static let commandReleaseRun = "release-run"
    public static let commandDoctor = "doctor"

    public static var coreCommands: [String] {
        [commandPlan, commandApply, commandVerify]
    }

    public static var allCommands: [String] {
        [commandPlan, commandApply, commandVerify, commandAppRegister, commandReleaseInit, commandReleaseCheck, commandReleaseRun]
    }

    public static func defaultPolicy(tmaPluginRef: TMAPluginRef) throws -> ToolchainLock {
        let swiftRule = try VersionRule(kind: "semver-range", value: ">=6.0 <7.0")
        let xcodeRule = try VersionRule(kind: "semver-range", value: ">=16.0 <17.0")
        let tuistRule = try VersionRule(kind: "semver-range", value: ">=4.0.0 <5.0.0")
        let rubyRule = try VersionRule(kind: "semver-range", value: ">=3.0 <4.0")
        let bundlerRule = try VersionRule(kind: "semver-range", value: ">=2.0 <3.0")
        let nodeRule = try VersionRule(kind: "semver-range", value: ">=20.0 <23.0")
        let fastlaneRule = try VersionRule(kind: "semver-range", value: ">=2.228.0 <3.0.0")
        let presentRule = try VersionRule(kind: "present", value: "present")

        return try ToolchainLock(
            schemaVersion: 2,
            tools: Tools(
                swift: try ToolRequirement(
                    versionRule: swiftRule,
                    requiredFor: allCommands,
                    installHints: ["xcode-select --install", "brew install swift"]
                ),
                xcode: try ToolRequirement(
                    versionRule: xcodeRule,
                    requiredFor: [commandVerify, commandReleaseRun],
                    installHints: ["xcode-select --install", "sudo xcode-select -s /Applications/Xcode.app"]
                ),
                tuist: try ToolRequirement(
                    versionRule: tuistRule,
                    requiredFor: [commandApply, commandVerify, commandReleaseRun],
                    installHints: ["brew install tuist", "mise use -g tuist@latest"]
                ),
                ruby: try ToolRequirement(
                    versionRule: rubyRule,
                    requiredFor: [commandReleaseInit, commandReleaseCheck, commandReleaseRun],
                    installHints: ["brew install ruby", "mise use -g ruby@latest"]
                ),
                bundler: try ToolRequirement(
                    versionRule: bundlerRule,
                    requiredFor: [commandReleaseInit, commandReleaseCheck, commandReleaseRun],
                    installHints: ["gem install bundler", "bundle --version"]
                ),
                node: try ToolRequirement(
                    versionRule: nodeRule,
                    requiredFor: ["metadata", "screenshots"],
                    installHints: ["brew install node", "mise use -g node@latest"]
                ),
                fastlane: try ToolRequirement(
                    versionRule: fastlaneRule,
                    requiredFor: [commandReleaseInit, commandReleaseCheck, commandReleaseRun],
                    installHints: ["brew install fastlane", "gem install fastlane -NV"]
                ),
                asc: try ToolRequirement(
                    versionRule: .init(kind: "semver-range", value: ">=0.1.0"),
                    requiredFor: [commandAppRegister, commandReleaseCheck, commandReleaseRun],
                    installHints: ["brew install asc", "curl -fsSL https://asccli.sh/install | bash"]
                ),
                devicectl: try ToolRequirement(
                    versionRule: presentRule,
                    requiredFor: ["device", "screenshots"],
                    installHints: ["xcode-select --install", "xcrun --find devicectl"]
                ),
                simctl: try ToolRequirement(
                    versionRule: presentRule,
                    requiredFor: ["screenshots", commandVerify],
                    installHints: ["xcode-select --install", "xcrun --find simctl"]
                )
            ),
            tmaPluginRef: tmaPluginRef
        )
    }
}
