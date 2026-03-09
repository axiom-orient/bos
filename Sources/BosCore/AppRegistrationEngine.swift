import CryptoKit
import Foundation
import os

public struct AppRegistrationOverrides: Sendable, Equatable {
    public let companyName: String?
    public let appName: String?
    public let appIdentifier: String?
    public let appleTeamId: String?
    public let primaryLanguage: String?
    public let sku: String?
    public let matchGitURL: String?

    public init(
        companyName: String? = nil,
        appName: String? = nil,
        appIdentifier: String? = nil,
        appleTeamId: String? = nil,
        primaryLanguage: String? = nil,
        sku: String? = nil,
        matchGitURL: String? = nil
    ) {
        self.companyName = AppRegistrationSupport.normalized(companyName)
        self.appName = AppRegistrationSupport.normalized(appName)
        self.appIdentifier = AppRegistrationSupport.normalized(appIdentifier)
        self.appleTeamId = AppRegistrationSupport.normalized(appleTeamId)
        self.primaryLanguage = AppRegistrationSupport.normalized(primaryLanguage)
        self.sku = AppRegistrationSupport.normalized(sku)
        self.matchGitURL = AppRegistrationSupport.normalized(matchGitURL)
    }
}

public struct AppRegistrationRequest: Sendable {
    public let projectRoot: URL
    public let profile: Profile
    public let blueprint: Blueprint?
    public let overrides: AppRegistrationOverrides
    public let environment: [String: String]

    public init(
        projectRoot: URL,
        profile: Profile,
        blueprint: Blueprint? = nil,
        overrides: AppRegistrationOverrides = .init(),
        environment: [String: String]
    ) {
        self.projectRoot = projectRoot
        self.profile = profile
        self.blueprint = blueprint
        self.overrides = overrides
        self.environment = environment
    }
}

public enum AppRegistrationResourceStatus: String, Codable, Sendable, Equatable {
    case created
    case existing
}

public struct AppRegistrationResolvedMetadata: Sendable, Equatable, Codable {
    public let companyName: String?
    public let appName: String
    public let appIdentifier: String
    public let appleTeamId: String
    public let primaryLanguage: String
    public let sku: String
    public let matchGitURL: String?
}

public struct AppRegistrationResult: Sendable {
    public let summary: String
    public let artifacts: [String]
    public let metadata: AppRegistrationResolvedMetadata
    public let bundleIdStatus: AppRegistrationResourceStatus
    public let appStatus: AppRegistrationResourceStatus
    public let syncedProfile: Profile
}

public enum AppRegistrationEngineError: Error, Equatable {
    case missingRequiredFields(fields: [String])
    case invalidValue(field: String, reason: String)
    case invalidEnvironment(missingKeys: [String], invalidIssues: [String])
    case providerFailure(summary: String, artifacts: [String])
}

public protocol AppRegistrationProviding: Sendable {
    func register(metadata: AppRegistrationResolvedMetadata, environment: [String: String]) throws -> AppRegistrationProviderResult
}

protocol AppStoreConnectClienting: Sendable {
    func hasBundleId(identifier: String) throws -> Bool
    func createBundleId(identifier: String, name: String) throws
    func hasApp(bundleIdentifier: String) throws -> Bool
    func createApp(metadata: AppRegistrationResolvedMetadata) throws
}

public struct AppRegistrationProviderResult: Sendable, Equatable {
    public let bundleIdStatus: AppRegistrationResourceStatus
    public let appStatus: AppRegistrationResourceStatus

    public init(bundleIdStatus: AppRegistrationResourceStatus, appStatus: AppRegistrationResourceStatus) {
        self.bundleIdStatus = bundleIdStatus
        self.appStatus = appStatus
    }
}

public enum AppRegistrationSupport {
    public static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    public static func normalizedPrimaryLanguage(_ value: String?) -> String? {
        guard let value = normalized(value)?.lowercased() else { return nil }
        switch value {
        case "en", "en-us", "english":
            return "en-US"
        case "ko", "ko-kr", "korean", "한국어":
            return "ko-KR"
        default:
            return nil
        }
    }

    public static func deterministicSKU(
        companyName: String?,
        appName: String,
        appIdentifier: String
    ) -> String {
        let companySeed = normalized(companyName) ?? organizationSeed(from: appIdentifier)
        let companySlug = slug(companySeed, fallback: "company")
        let appSlug = slug(appName, fallback: "app")
        let hashData = SHA256.hash(data: Data(appIdentifier.utf8))
        let hash = hashData.compactMap { String(format: "%02x", $0) }.joined().prefix(8)
        return "\(companySlug).\(appSlug).\(hash)"
    }

    public static func deriveAppName(
        appIdentifier: String,
        fallback: String? = nil
    ) -> String {
        if let fallback = normalized(fallback) {
            return fallback
        }

        let terminal = appIdentifier.split(separator: ".").last.map(String.init) ?? "App"
        let parts = terminal
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { !$0.isEmpty }
        if parts.isEmpty {
            return "App"
        }
        return parts.map(capitalizedToken).joined()
    }

    public static func validateAppIdentifier(_ value: String) -> Bool {
        value.wholeMatch(of: #/[A-Za-z0-9]+(?:\.[A-Za-z0-9_-]+)+/#) != nil
    }

    public static func validateAppleTeamId(_ value: String) -> Bool {
        value.wholeMatch(of: #/[A-Z0-9]{10}/#) != nil
    }

    public static func validateMatchGitURL(_ value: String) -> Bool {
        value.hasPrefix("https://") || value.hasPrefix("ssh://") || value.hasPrefix("git@")
    }

    public static func slug(_ raw: String, fallback: String) -> String {
        let transliterated = raw.applyingTransform(.toLatin, reverse: false)?
            .applyingTransform(.stripDiacritics, reverse: false) ?? raw
        let lowered = transliterated.lowercased()
        let mapped = lowered.map { character -> Character in
            if character.isLetter || character.isNumber {
                return character
            }
            return "-"
        }
        let pieces = String(mapped)
            .split(separator: "-")
            .map(String.init)
            .filter { !$0.isEmpty }
        return pieces.isEmpty ? fallback : pieces.joined(separator: "-")
    }

    public static func organizationSeed(from appIdentifier: String) -> String {
        var parts = appIdentifier.split(separator: ".").map(String.init)
        if !parts.isEmpty {
            parts.removeLast()
        }
        if let first = parts.first?.lowercased(),
           ["com", "net", "org", "io", "app", "dev"].contains(first),
           parts.count > 1 {
            parts.removeFirst()
        }
        let candidate = parts.joined(separator: ".")
        return normalized(candidate) ?? appIdentifier
    }

    public static func bundleIdentifierDisplayName(
        companyName: String?,
        appName: String,
        appIdentifier: String
    ) -> String {
        let base = [companyName, appName]
            .compactMap(normalized)
            .joined(separator: " ")
        let ascii = slug(base, fallback: slug(appIdentifier, fallback: "app"))
            .split(separator: "-")
            .map(String.init)
            .map(capitalizedToken)
            .joined(separator: " ")
        return ascii.isEmpty ? appIdentifier : ascii
    }

    static func capitalizedToken(_ token: String) -> String {
        let trimmed = normalized(token) ?? ""
        guard !trimmed.isEmpty else { return "" }
        return trimmed.prefix(1).uppercased() + trimmed.dropFirst()
    }
}

public struct AppRegistrationEngine: Sendable {
    private let provider: any AppRegistrationProviding

    public init(provider: any AppRegistrationProviding = NativeAppRegistrationProvider()) {
        self.provider = provider
    }

    public func register(request: AppRegistrationRequest) throws -> AppRegistrationResult {
        let root = request.projectRoot.standardizedFileURL
        let metadata = try resolveMetadata(
            profile: request.profile,
            blueprint: request.blueprint,
            overrides: request.overrides,
            environment: request.environment
        )

        let envCheck = SigningEnvironmentPolicy.validateAppStoreConnect(environment: request.environment)
        if !envCheck.missingKeys.isEmpty || !envCheck.invalidIssues.isEmpty {
            throw AppRegistrationEngineError.invalidEnvironment(
                missingKeys: envCheck.missingKeys,
                invalidIssues: envCheck.invalidIssues.map { "\($0.key)(\($0.rule))" }.sorted()
            )
        }

        let artifactsDir = try RuntimeArtifacts.makeDirectory(for: "app-register", projectRoot: root)
        let stamp = RuntimeSupport.timestamp()
        let jsonPath = artifactsDir.appending(path: "app-register-\(stamp).json")
        let logPath = artifactsDir.appending(path: "app-register-\(stamp).log")
        let artifacts = [jsonPath.path(percentEncoded: false), logPath.path(percentEncoded: false)]

        do {
            let providerResult = try provider.register(metadata: metadata, environment: request.environment)
            let syncedProfile = try request.profile.updating(
                onboarding: OnboardingMetadata(
                    companyName: metadata.companyName,
                    appName: metadata.appName,
                    appIdentifier: metadata.appIdentifier,
                    appleTeamId: metadata.appleTeamId,
                    primaryLanguage: metadata.primaryLanguage,
                    sku: metadata.sku,
                    matchGitURL: metadata.matchGitURL
                )
            )
            let summary = "App registration completed (bundleId=\(providerResult.bundleIdStatus.rawValue), app=\(providerResult.appStatus.rawValue))"
            try writeArtifacts(
                jsonPath: jsonPath,
                logPath: logPath,
                summary: summary,
                metadata: metadata,
                providerResult: providerResult,
                artifacts: artifacts
            )
            return AppRegistrationResult(
                summary: summary,
                artifacts: artifacts,
                metadata: metadata,
                bundleIdStatus: providerResult.bundleIdStatus,
                appStatus: providerResult.appStatus,
                syncedProfile: syncedProfile
            )
        } catch let error as AppRegistrationEngineError {
            try writeFailureArtifacts(
                jsonPath: jsonPath,
                logPath: logPath,
                error: error,
                metadata: metadata,
                artifacts: artifacts
            )
            throw error
        } catch {
            let wrapped = AppRegistrationEngineError.providerFailure(
                summary: String(describing: error),
                artifacts: artifacts
            )
            try writeFailureArtifacts(
                jsonPath: jsonPath,
                logPath: logPath,
                error: wrapped,
                metadata: metadata,
                artifacts: artifacts
            )
            throw wrapped
        }
    }
}

private extension AppRegistrationEngine {
    struct ArtifactPayload: Codable {
        let command: String
        let status: String
        let exitCode: Int
        let summary: String
        let appIdentifier: String
        let appName: String
        let sku: String
        let primaryLanguage: String
        let bundleIdStatus: String?
        let appStatus: String?
        let artifacts: [String]
    }

    func resolveMetadata(
        profile: Profile,
        blueprint: Blueprint?,
        overrides: AppRegistrationOverrides,
        environment: [String: String]
    ) throws -> AppRegistrationResolvedMetadata {
        let appIdentifier = firstNonEmpty(
            overrides.appIdentifier,
            profile.configuredAppIdentifier,
            blueprint?.release.fastlane.appIdentifier
        )
        let appleTeamId = firstNonEmpty(
            overrides.appleTeamId,
            profile.configuredAppleTeamId,
            blueprint?.release.fastlane.appleTeamId
        )

        let missing = [
            appIdentifier == nil ? "appIdentifier" : nil,
            appleTeamId == nil ? "appleTeamId" : nil
        ].compactMap { $0 }
        if !missing.isEmpty {
            throw AppRegistrationEngineError.missingRequiredFields(fields: missing)
        }

        let resolvedAppIdentifier = appIdentifier!
        let resolvedAppleTeamId = appleTeamId!

        if !AppRegistrationSupport.validateAppIdentifier(resolvedAppIdentifier) {
            throw AppRegistrationEngineError.invalidValue(field: "appIdentifier", reason: "must look like com.example.app")
        }
        if !AppRegistrationSupport.validateAppleTeamId(resolvedAppleTeamId) {
            throw AppRegistrationEngineError.invalidValue(field: "appleTeamId", reason: "must be 10 uppercase letters/digits")
        }

        let appName = firstNonEmpty(
            overrides.appName,
            profile.configuredAppName,
            blueprint?.release.fastlane.appName,
            blueprint?.project.name
        ) ?? AppRegistrationSupport.deriveAppName(appIdentifier: resolvedAppIdentifier)

        let companyName = firstNonEmpty(
            overrides.companyName,
            profile.configuredCompanyName,
            blueprint?.release.fastlane.companyName
        )

        let rawPrimaryLanguage = firstNonEmpty(
            overrides.primaryLanguage,
            profile.configuredPrimaryLanguage,
            blueprint?.release.fastlane.primaryLanguage,
            "en-US"
        )
        guard let primaryLanguage = AppRegistrationSupport.normalizedPrimaryLanguage(rawPrimaryLanguage) else {
            throw AppRegistrationEngineError.invalidValue(field: "primaryLanguage", reason: "must be en-US or ko-KR")
        }

        let sku = firstNonEmpty(
            overrides.sku,
            profile.configuredSKU,
            blueprint?.release.fastlane.sku
        ) ?? AppRegistrationSupport.deterministicSKU(
            companyName: companyName,
            appName: appName,
            appIdentifier: resolvedAppIdentifier
        )

        let matchGitURL = firstNonEmpty(
            overrides.matchGitURL,
            profile.configuredMatchGitURL,
            OnboardingMetadata.normalized(environment["MATCH_GIT_URL"])
        )
        if let matchGitURL, !AppRegistrationSupport.validateMatchGitURL(matchGitURL) {
            throw AppRegistrationEngineError.invalidValue(
                field: "matchGitURL",
                reason: "must start with https://, ssh://, or git@"
            )
        }

        return AppRegistrationResolvedMetadata(
            companyName: companyName,
            appName: appName,
            appIdentifier: resolvedAppIdentifier,
            appleTeamId: resolvedAppleTeamId,
            primaryLanguage: primaryLanguage,
            sku: sku,
            matchGitURL: matchGitURL
        )
    }

    func firstNonEmpty(_ values: String?...) -> String? {
        values.first { value in
            guard let value else { return false }
            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } ?? nil
    }

    func writeArtifacts(
        jsonPath: URL,
        logPath: URL,
        summary: String,
        metadata: AppRegistrationResolvedMetadata,
        providerResult: AppRegistrationProviderResult,
        artifacts: [String]
    ) throws {
        let payload = ArtifactPayload(
            command: "app-register",
            status: "success",
            exitCode: 0,
            summary: summary,
            appIdentifier: metadata.appIdentifier,
            appName: metadata.appName,
            sku: metadata.sku,
            primaryLanguage: metadata.primaryLanguage,
            bundleIdStatus: providerResult.bundleIdStatus.rawValue,
            appStatus: providerResult.appStatus.rawValue,
            artifacts: artifacts
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try RuntimeSupport.writeFile(to: jsonPath, data: try encoder.encode(payload))

        let lines: [String] = [
            "# bos app-register",
            "appIdentifier=\(metadata.appIdentifier)",
            "appName=\(metadata.appName)",
            "appleTeamId=\(metadata.appleTeamId)",
            "primaryLanguage=\(metadata.primaryLanguage)",
            "sku=\(metadata.sku)",
            "companyName=\(metadata.companyName ?? "-")",
            "matchGitURL=\(metadata.matchGitURL ?? "-")",
            "bundleIdStatus=\(providerResult.bundleIdStatus.rawValue)",
            "appStatus=\(providerResult.appStatus.rawValue)",
            "summary=\(summary)",
            ""
        ]
        try RuntimeSupport.writeFile(to: logPath, content: lines.joined(separator: "\n"))
    }

    func writeFailureArtifacts(
        jsonPath: URL,
        logPath: URL,
        error: AppRegistrationEngineError,
        metadata: AppRegistrationResolvedMetadata?,
        artifacts: [String]
    ) throws {
        let summary: String
        switch error {
        case .missingRequiredFields(let fields):
            summary = "missing required fields: \(fields.joined(separator: ", "))"
        case .invalidValue(let field, let reason):
            summary = "\(field): \(reason)"
        case .invalidEnvironment(let missingKeys, let invalidIssues):
            let parts = [
                missingKeys.isEmpty ? nil : "missing=\(missingKeys.joined(separator: ","))",
                invalidIssues.isEmpty ? nil : "invalid=\(invalidIssues.joined(separator: ","))"
            ].compactMap { $0 }
            summary = "invalid App Store Connect environment: \(parts.joined(separator: " "))"
        case .providerFailure(let providerSummary, _):
            summary = providerSummary
        }

        let payload = ArtifactPayload(
            command: "app-register",
            status: "failed",
            exitCode: 8,
            summary: summary,
            appIdentifier: metadata?.appIdentifier ?? "",
            appName: metadata?.appName ?? "",
            sku: metadata?.sku ?? "",
            primaryLanguage: metadata?.primaryLanguage ?? "",
            bundleIdStatus: nil,
            appStatus: nil,
            artifacts: artifacts
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try RuntimeSupport.writeFile(to: jsonPath, data: try encoder.encode(payload))

        let lines: [String] = [
            "# bos app-register",
            "status=failed",
            "summary=\(summary)",
            metadata.map { "appIdentifier=\($0.appIdentifier)" } ?? "appIdentifier=-",
            metadata.map { "appName=\($0.appName)" } ?? "appName=-",
            metadata.map { "appleTeamId=\($0.appleTeamId)" } ?? "appleTeamId=-",
            metadata.map { "primaryLanguage=\($0.primaryLanguage)" } ?? "primaryLanguage=-",
            metadata.map { "sku=\($0.sku)" } ?? "sku=-",
            ""
        ]
        try RuntimeSupport.writeFile(to: logPath, content: lines.joined(separator: "\n"))
    }
}

public struct NativeAppRegistrationProvider: AppRegistrationProviding {
    private let clientFactory: @Sendable ([String: String]) throws -> any AppStoreConnectClienting

    public init() {
        self.clientFactory = { try AppStoreConnectAPIClient(environment: $0) }
    }

    init(clientFactory: @escaping @Sendable ([String: String]) throws -> any AppStoreConnectClienting) {
        self.clientFactory = clientFactory
    }

    public func register(
        metadata: AppRegistrationResolvedMetadata,
        environment: [String: String]
    ) throws -> AppRegistrationProviderResult {
        let client = try clientFactory(environment)

        let bundleIdStatus: AppRegistrationResourceStatus
        if try !client.hasBundleId(identifier: metadata.appIdentifier) {
            do {
                try client.createBundleId(
                    identifier: metadata.appIdentifier,
                    name: AppRegistrationSupport.bundleIdentifierDisplayName(
                        companyName: metadata.companyName,
                        appName: metadata.appName,
                        appIdentifier: metadata.appIdentifier
                    )
                )
                bundleIdStatus = .created
            } catch {
                if try client.hasBundleId(identifier: metadata.appIdentifier) {
                    bundleIdStatus = .existing
                } else {
                    throw error
                }
            }
        } else {
            bundleIdStatus = .existing
        }

        let appStatus: AppRegistrationResourceStatus
        if try !client.hasApp(bundleIdentifier: metadata.appIdentifier) {
            do {
                try client.createApp(metadata: metadata)
                appStatus = .created
            } catch {
                if try client.hasApp(bundleIdentifier: metadata.appIdentifier) {
                    appStatus = .existing
                } else {
                    throw error
                }
            }
        } else {
            appStatus = .existing
        }

        return AppRegistrationProviderResult(
            bundleIdStatus: bundleIdStatus,
            appStatus: appStatus
        )
    }
}

private struct AppStoreConnectAPIClient: AppStoreConnectClienting {
    private let session: URLSession
    private let token: String

    init(environment: [String: String], session: URLSession = .shared) throws {
        self.session = session
        self.token = try AppStoreConnectTokenFactory().makeBearerToken(environment: environment)
    }

    func hasBundleId(identifier: String) throws -> Bool {
        try fetchBundleId(identifier: identifier) != nil
    }

    fileprivate func fetchBundleId(identifier: String) throws -> BundleIdRecord? {
        let response: CollectionResponse<BundleIdRecord> = try request(
            method: "GET",
            path: "/v1/bundleIds",
            queryItems: [
                URLQueryItem(name: "filter[identifier]", value: identifier),
                URLQueryItem(name: "limit", value: "1")
            ],
            body: nil
        )
        return response.data.first
    }

    func createBundleId(identifier: String, name: String) throws {
        _ = try createBundleIdRecord(identifier: identifier, name: name)
    }

    fileprivate func createBundleIdRecord(identifier: String, name: String) throws -> BundleIdRecord {
        let payload: [String: Any] = [
            "data": [
                "type": "bundleIds",
                "attributes": [
                    "identifier": identifier,
                    "name": name,
                    "platform": "IOS"
                ]
            ]
        ]
        let response: ResourceResponse<BundleIdRecord> = try request(
            method: "POST",
            path: "/v1/bundleIds",
            queryItems: [],
            body: try JSONSerialization.data(withJSONObject: payload, options: [])
        )
        return response.data
    }

    func hasApp(bundleIdentifier: String) throws -> Bool {
        try fetchApp(bundleIdentifier: bundleIdentifier) != nil
    }

    fileprivate func fetchApp(bundleIdentifier: String) throws -> AppRecord? {
        let response: CollectionResponse<AppRecord> = try request(
            method: "GET",
            path: "/v1/apps",
            queryItems: [
                URLQueryItem(name: "filter[bundleId]", value: bundleIdentifier),
                URLQueryItem(name: "limit", value: "1")
            ],
            body: nil
        )
        return response.data.first
    }

    func createApp(metadata: AppRegistrationResolvedMetadata) throws {
        _ = try createAppRecord(metadata: metadata)
    }

    fileprivate func createAppRecord(metadata: AppRegistrationResolvedMetadata) throws -> AppRecord {
        let payload = appPayload(metadata: metadata)
        let response: ResourceResponse<AppRecord> = try request(
            method: "POST",
            path: "/v1/apps",
            queryItems: [],
            body: try JSONSerialization.data(withJSONObject: payload, options: [])
        )
        return response.data
    }

    private func appPayload(metadata: AppRegistrationResolvedMetadata) -> [String: Any] {
        var attributes: [String: Any] = [
            "sku": metadata.sku,
            "primaryLocale": metadata.primaryLanguage,
            "bundleId": metadata.appIdentifier
        ]
        if let companyName = metadata.companyName {
            attributes["companyName"] = companyName
        }

        return [
            "data": [
                "type": "apps",
                "attributes": attributes,
                "relationships": [
                    "appInfos": [
                        "data": [
                            ["type": "appInfos", "id": "${new-appInfo-id}"]
                        ]
                    ],
                    "appStoreVersions": [
                        "data": [
                            ["type": "appStoreVersions", "id": "${store-version-IOS}"]
                        ]
                    ]
                ]
            ],
            "included": [
                [
                    "type": "appInfos",
                    "id": "${new-appInfo-id}",
                    "relationships": [
                        "appInfoLocalizations": [
                            "data": [
                                ["type": "appInfoLocalizations", "id": "${new-appInfoLocalization-id}"]
                            ]
                        ]
                    ]
                ],
                [
                    "type": "appInfoLocalizations",
                    "id": "${new-appInfoLocalization-id}",
                    "attributes": [
                        "locale": metadata.primaryLanguage,
                        "name": metadata.appName
                    ]
                ],
                [
                    "type": "appStoreVersions",
                    "id": "${store-version-IOS}",
                    "attributes": [
                        "platform": "IOS",
                        "versionString": "1.0"
                    ],
                    "relationships": [
                        "appStoreVersionLocalizations": [
                            "data": [
                                ["type": "appStoreVersionLocalizations", "id": "${new-IOSVersionLocalization-id}"]
                            ]
                        ]
                    ]
                ],
                [
                    "type": "appStoreVersionLocalizations",
                    "id": "${new-IOSVersionLocalization-id}",
                    "attributes": [
                        "locale": metadata.primaryLanguage
                    ]
                ]
            ]
        ]
    }

    private func request<Response: Decodable>(
        method: String,
        path: String,
        queryItems: [URLQueryItem],
        body: Data?
    ) throws -> Response {
        var components = URLComponents(string: "https://api.appstoreconnect.apple.com")!
        components.path = path
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else {
            throw AppRegistrationEngineError.providerFailure(summary: "invalid App Store Connect URL", artifacts: [])
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let semaphore = DispatchSemaphore(value: 0)
        let resultLock = OSAllocatedUnfairLock<Result<(Data, HTTPURLResponse), Error>?>(initialState: nil)

        session.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            if let error {
                resultLock.withLock { $0 = .failure(error) }
                return
            }
            guard let response = response as? HTTPURLResponse else {
                resultLock.withLock { $0 = .failure(
                    AppRegistrationEngineError.providerFailure(summary: "missing HTTP response from App Store Connect", artifacts: [])
                ) }
                return
            }
            resultLock.withLock { $0 = .success((data ?? Data(), response)) }
        }.resume()

        if semaphore.wait(timeout: .now() + 30) == .timedOut {
            throw AppRegistrationEngineError.providerFailure(summary: "timed out waiting for App Store Connect response", artifacts: [])
        }

        let result = resultLock.withLock { $0 }

        switch result {
        case .success(let (data, response)):
            guard (200..<300).contains(response.statusCode) else {
                let details = (try? JSONDecoder().decode(ErrorResponse.self, from: data).summary)
                    ?? String(decoding: data, as: UTF8.self)
                throw AppRegistrationEngineError.providerFailure(
                    summary: "App Store Connect returned HTTP \(response.statusCode): \(details)",
                    artifacts: []
                )
            }
            return try JSONDecoder().decode(Response.self, from: data)
        case .failure(let error):
            throw error
        case .none:
            throw AppRegistrationEngineError.providerFailure(summary: "App Store Connect request finished without a result", artifacts: [])
        }
    }

    fileprivate struct CollectionResponse<Resource: Decodable>: Decodable {
        let data: [Resource]
    }

    fileprivate struct ResourceResponse<Resource: Decodable>: Decodable {
        let data: Resource
    }

    fileprivate struct ErrorResponse: Decodable {
        struct ErrorItem: Decodable {
            let code: String?
            let title: String?
            let detail: String?
        }

        let errors: [ErrorItem]

        var summary: String {
            errors
                .map { [ $0.code, $0.title, $0.detail ].compactMap { $0 }.joined(separator: ": ") }
                .filter { !$0.isEmpty }
                .joined(separator: " | ")
        }
    }

    fileprivate struct BundleIdRecord: Decodable {
        let id: String
    }

    fileprivate struct AppRecord: Decodable {
        let id: String
    }
}

struct AppStoreConnectTokenFactory {
    func makeBearerToken(environment: [String: String]) throws -> String {
        guard let issuerID = environment["ASC_ISSUER_ID"], !issuerID.isEmpty,
              let keyID = environment["ASC_KEY_ID"], !keyID.isEmpty,
              let keyBase64 = environment["ASC_KEY_P8_BASE64"], !keyBase64.isEmpty else {
            let missing = SigningEnvironmentPolicy.appStoreConnectRequiredKeys.filter {
                AppRegistrationSupport.normalized(environment[$0]) == nil
            }
            throw AppRegistrationEngineError.invalidEnvironment(
                missingKeys: missing,
                invalidIssues: []
            )
        }

        guard let keyData = Data(base64Encoded: keyBase64, options: [.ignoreUnknownCharacters]),
              let pem = String(data: keyData, encoding: .utf8) else {
            throw AppRegistrationEngineError.providerFailure(
                summary: "failed to decode ASC_KEY_P8_BASE64 into PEM text",
                artifacts: []
            )
        }

        let privateKey: P256.Signing.PrivateKey
        do {
            privateKey = try P256.Signing.PrivateKey(pemRepresentation: pem)
        } catch {
            throw AppRegistrationEngineError.providerFailure(
                summary: "failed to parse App Store Connect private key: \(error.localizedDescription)",
                artifacts: []
            )
        }

        let header = try base64URLJSON([
            "alg": "ES256",
            "kid": keyID,
            "typ": "JWT"
        ])
        let now = Int(Date().timeIntervalSince1970)
        let claims = try base64URLJSON([
            "iss": issuerID,
            "iat": now,
            "exp": now + 20 * 60,
            "aud": "appstoreconnect-v1"
        ])

        let signingInput = "\(header).\(claims)"
        let signature = try privateKey.signature(for: Data(signingInput.utf8))
        return "\(signingInput).\(base64URL(signature.rawRepresentation))"
    }

    private func base64URLJSON(_ jsonObject: [String: Any]) throws -> String {
        try base64URL(JSONSerialization.data(withJSONObject: jsonObject, options: []))
    }

    private func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
