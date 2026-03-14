import Foundation

public struct BootstrapLock: Codable, Sendable {
    public let appliedAt: String
    public let blueprintHash: String
    public let profileHash: String
    public let managedFiles: [String]
    public let verifySummary: StepSummary
    public let releaseSummary: StepSummary
    public let releaseCheckSummary: StepSummary?
    public let releaseRunSummary: StepSummary?
    public let derivedState: DerivedState?

    public init(
        appliedAt: String,
        blueprintHash: String,
        profileHash: String,
        managedFiles: [String],
        verifySummary: StepSummary,
        releaseSummary: StepSummary,
        releaseCheckSummary: StepSummary? = nil,
        releaseRunSummary: StepSummary? = nil,
        derivedState: DerivedState? = nil
    ) throws {
        self.appliedAt = appliedAt
        self.blueprintHash = blueprintHash
        self.profileHash = profileHash
        self.managedFiles = managedFiles
        self.verifySummary = verifySummary
        self.releaseSummary = releaseSummary
        self.releaseCheckSummary = releaseCheckSummary
        self.releaseRunSummary = releaseRunSummary
        self.derivedState = derivedState
        try validate()
    }
}

extension BootstrapLock: StrictSchema {
    static let schemaName = "BootstrapLock"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case appliedAt
        case blueprintHash
        case profileHash
        case managedFiles
        case verifySummary
        case releaseSummary
        case releaseCheckSummary
        case releaseRunSummary
        case derivedState
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.appliedAt = try c.decode(String.self, forKey: .appliedAt)
        self.blueprintHash = try c.decode(String.self, forKey: .blueprintHash)
        self.profileHash = try c.decode(String.self, forKey: .profileHash)
        self.managedFiles = try c.decode([String].self, forKey: .managedFiles)
        self.verifySummary = try c.decode(StepSummary.self, forKey: .verifySummary)
        self.releaseSummary = try c.decode(StepSummary.self, forKey: .releaseSummary)
        self.releaseCheckSummary = try c.decodeIfPresent(StepSummary.self, forKey: .releaseCheckSummary)
        self.releaseRunSummary = try c.decodeIfPresent(StepSummary.self, forKey: .releaseRunSummary)
        self.derivedState = try c.decodeIfPresent(DerivedState.self, forKey: .derivedState)
        try validate()
    }

    func validate() throws {
        if appliedAt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: "appliedAt", reason: "must not be empty")
        }
    }
}

extension BootstrapLock {
    public struct StepSummary: Codable, Sendable {
        public let status: String
        public let message: String?

        public init(status: String, message: String?) throws {
            self.status = status
            self.message = message
            try validate()
        }
    }
}

extension BootstrapLock {
    public struct DerivedState: Codable, Sendable {
        public let releaseInit: ReleaseInitState?
        public let releaseCheck: ReleaseCheckState?
        public let releaseRun: ReleaseRunState?

        public init(
            releaseInit: ReleaseInitState? = nil,
            releaseCheck: ReleaseCheckState? = nil,
            releaseRun: ReleaseRunState? = nil
        ) throws {
            self.releaseInit = releaseInit
            self.releaseCheck = releaseCheck
            self.releaseRun = releaseRun
            try validate()
        }
    }

    public struct ReleaseInitState: Codable, Sendable {
        public let status: String
        public let summary: String
        public let updatedAt: String
        public let artifactDirectory: String?
        public let generatedFiles: [String]
        public let lanes: [String]

        public init(
            status: String,
            summary: String,
            updatedAt: String,
            artifactDirectory: String? = nil,
            generatedFiles: [String] = [],
            lanes: [String] = []
        ) throws {
            self.status = status
            self.summary = summary
            self.updatedAt = updatedAt
            self.artifactDirectory = artifactDirectory
            self.generatedFiles = generatedFiles
            self.lanes = lanes
            try validate()
        }
    }

    public struct ReleaseCheckState: Codable, Sendable {
        public let status: String
        public let summary: String
        public let updatedAt: String
        public let mode: String
        public let completedSteps: [String]
        public let nextStep: String?
        public let failedStep: String?
        public let failureCode: String?
        public let artifactDirectory: String?

        public init(
            status: String,
            summary: String,
            updatedAt: String,
            mode: String,
            completedSteps: [String] = [],
            nextStep: String? = nil,
            failedStep: String? = nil,
            failureCode: String? = nil,
            artifactDirectory: String? = nil
        ) throws {
            self.status = status
            self.summary = summary
            self.updatedAt = updatedAt
            self.mode = mode
            self.completedSteps = completedSteps
            self.nextStep = nextStep
            self.failedStep = failedStep
            self.failureCode = failureCode
            self.artifactDirectory = artifactDirectory
            try validate()
        }
    }

    public struct ReleaseRunState: Codable, Sendable {
        public let status: String
        public let summary: String
        public let updatedAt: String
        public let stage: String
        public let signingMode: String
        public let completedSteps: [String]
        public let nextStep: String?
        public let failedStep: String?
        public let failureCode: String?
        public let artifactDirectory: String?
        public let ipaPath: String?

        public init(
            status: String,
            summary: String,
            updatedAt: String,
            stage: String,
            signingMode: String,
            completedSteps: [String] = [],
            nextStep: String? = nil,
            failedStep: String? = nil,
            failureCode: String? = nil,
            artifactDirectory: String? = nil,
            ipaPath: String? = nil
        ) throws {
            self.status = status
            self.summary = summary
            self.updatedAt = updatedAt
            self.stage = stage
            self.signingMode = signingMode
            self.completedSteps = completedSteps
            self.nextStep = nextStep
            self.failedStep = failedStep
            self.failureCode = failureCode
            self.artifactDirectory = artifactDirectory
            self.ipaPath = ipaPath
            try validate()
        }
    }
}

extension BootstrapLock.StepSummary: StrictSchema {
    static let schemaName = "BootstrapLock.stepSummary"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case status
        case message
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.status = try c.decode(String.self, forKey: .status)
        self.message = try c.decodeIfPresent(String.self, forKey: .message)
        try validate()
    }

    func validate() throws {
        if status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: "status", reason: "must not be empty")
        }
    }
}

extension BootstrapLock.DerivedState: StrictSchema {
    static let schemaName = "BootstrapLock.derivedState"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case releaseInit
        case releaseCheck
        case releaseRun
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.releaseInit = try c.decodeIfPresent(BootstrapLock.ReleaseInitState.self, forKey: .releaseInit)
        self.releaseCheck = try c.decodeIfPresent(BootstrapLock.ReleaseCheckState.self, forKey: .releaseCheck)
        self.releaseRun = try c.decodeIfPresent(BootstrapLock.ReleaseRunState.self, forKey: .releaseRun)
        try validate()
    }

    func validate() throws {}
}

extension BootstrapLock.ReleaseInitState: StrictSchema {
    static let schemaName = "BootstrapLock.releaseInitState"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case status
        case summary
        case updatedAt
        case artifactDirectory
        case generatedFiles
        case lanes
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.status = try c.decode(String.self, forKey: .status)
        self.summary = try c.decode(String.self, forKey: .summary)
        self.updatedAt = try c.decode(String.self, forKey: .updatedAt)
        self.artifactDirectory = try c.decodeIfPresent(String.self, forKey: .artifactDirectory)
        self.generatedFiles = try c.decodeIfPresent([String].self, forKey: .generatedFiles) ?? []
        self.lanes = try c.decodeIfPresent([String].self, forKey: .lanes) ?? []
        try validate()
    }

    func validate() throws {
        try validateNonEmpty(status, field: "status")
        try validateNonEmpty(summary, field: "summary")
        try validateNonEmpty(updatedAt, field: "updatedAt")
    }
}

extension BootstrapLock.ReleaseCheckState: StrictSchema {
    static let schemaName = "BootstrapLock.releaseCheckState"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case status
        case summary
        case updatedAt
        case mode
        case completedSteps
        case nextStep
        case failedStep
        case failureCode
        case artifactDirectory
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.status = try c.decode(String.self, forKey: .status)
        self.summary = try c.decode(String.self, forKey: .summary)
        self.updatedAt = try c.decode(String.self, forKey: .updatedAt)
        self.mode = try c.decode(String.self, forKey: .mode)
        self.completedSteps = try c.decodeIfPresent([String].self, forKey: .completedSteps) ?? []
        self.nextStep = try c.decodeIfPresent(String.self, forKey: .nextStep)
        self.failedStep = try c.decodeIfPresent(String.self, forKey: .failedStep)
        self.failureCode = try c.decodeIfPresent(String.self, forKey: .failureCode)
        self.artifactDirectory = try c.decodeIfPresent(String.self, forKey: .artifactDirectory)
        try validate()
    }

    func validate() throws {
        try validateNonEmpty(status, field: "status")
        try validateNonEmpty(summary, field: "summary")
        try validateNonEmpty(updatedAt, field: "updatedAt")
        try validateNonEmpty(mode, field: "mode")
        try validateUniqueSteps(completedSteps, field: "completedSteps")
    }
}

extension BootstrapLock.ReleaseRunState: StrictSchema {
    static let schemaName = "BootstrapLock.releaseRunState"

    fileprivate enum CodingKeys: String, CodingKey, CaseIterable {
        case status
        case summary
        case updatedAt
        case stage
        case signingMode
        case completedSteps
        case nextStep
        case failedStep
        case failureCode
        case artifactDirectory
        case ipaPath
    }

    public init(from decoder: Decoder) throws {
        try rejectUnknownKeys(
            decoder,
            schema: Self.schemaName,
            allowedKeys: CodingKeys.allCases.map(\.stringValue)
        )
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.status = try c.decode(String.self, forKey: .status)
        self.summary = try c.decode(String.self, forKey: .summary)
        self.updatedAt = try c.decode(String.self, forKey: .updatedAt)
        self.stage = try c.decode(String.self, forKey: .stage)
        self.signingMode = try c.decode(String.self, forKey: .signingMode)
        self.completedSteps = try c.decodeIfPresent([String].self, forKey: .completedSteps) ?? []
        self.nextStep = try c.decodeIfPresent(String.self, forKey: .nextStep)
        self.failedStep = try c.decodeIfPresent(String.self, forKey: .failedStep)
        self.failureCode = try c.decodeIfPresent(String.self, forKey: .failureCode)
        self.artifactDirectory = try c.decodeIfPresent(String.self, forKey: .artifactDirectory)
        self.ipaPath = try c.decodeIfPresent(String.self, forKey: .ipaPath)
        try validate()
    }

    func validate() throws {
        try validateNonEmpty(status, field: "status")
        try validateNonEmpty(summary, field: "summary")
        try validateNonEmpty(updatedAt, field: "updatedAt")
        try validateNonEmpty(stage, field: "stage")
        try validateNonEmpty(signingMode, field: "signingMode")
        try validateUniqueSteps(completedSteps, field: "completedSteps")
    }
}

private extension BootstrapLock.ReleaseInitState {
    func validateNonEmpty(_ value: String, field: String) throws {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: field, reason: "must not be empty")
        }
    }
}

private extension BootstrapLock.ReleaseCheckState {
    func validateNonEmpty(_ value: String, field: String) throws {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: field, reason: "must not be empty")
        }
    }

    func validateUniqueSteps(_ steps: [String], field: String) throws {
        if Set(steps).count != steps.count {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: field, reason: "must not contain duplicates")
        }
    }
}

private extension BootstrapLock.ReleaseRunState {
    func validateNonEmpty(_ value: String, field: String) throws {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: field, reason: "must not be empty")
        }
    }

    func validateUniqueSteps(_ steps: [String], field: String) throws {
        if Set(steps).count != steps.count {
            throw SchemaValidationError.invalidValue(schema: Self.schemaName, field: field, reason: "must not contain duplicates")
        }
    }
}

extension Profile {
    public static let `default`: Profile = try! Profile(
        schemaVersion: 1,
        name: "default",
        defaults: .init(
            deploymentTarget: "18.0",
            appTargets: .init(controlsExtension: false, uiTests: true)
        ),
        identity: .init(),
        release: .init(primaryLanguage: "en-US"),
        featurePattern: .init(sourcesInterface: true, designFolder: false),
        rules: try! .init(
            testingStyle: "swift-testing",
            forbidPatterns: ["@unchecked Sendable", "Date()", "UUID()"]
        )
    )
}
