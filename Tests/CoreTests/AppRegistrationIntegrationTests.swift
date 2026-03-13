import Foundation
import Testing
@testable import BosCore

@Suite
struct AppRegistrationIntegrationTests {
    @Test func registerDerivesMetadataAndBackfillsProfile() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let provider = StubProvider(result: .init(bundleIdStatus: .created, appStatus: .existing))
        let engine = AppRegistrationEngine(
            provider: provider,
            appStoreAppIDResolver: StubResolver(
                result: .init(
                    appStoreAppId: "1234567890",
                    source: .lookup,
                    updatedProfile: try makeProfile(
                        identity: .init(
                            companyName: "Axiom Orient",
                            appName: "Blueprint Name",
                            appIdentifier: "com.axiomorient.daycraft",
                            appleTeamId: "A1B2C3D4E5"
                        ),
                        release: .init(
                            primaryLanguage: "ko-KR",
                            sku: "blueprint.sku",
                            appStoreAppId: "1234567890",
                            matchGitURL: "https://github.com/axiom-orient/AppStoreConnect"
                        )
                    )
                )
            )
        )

        let result = try engine.register(
            request: AppRegistrationRequest(
                projectRoot: root,
                profile: try makeProfile(
                    identity: .init(
                        companyName: "Axiom Orient",
                        appIdentifier: "com.axiomorient.daycraft",
                        appleTeamId: "A1B2C3D4E5"
                    ),
                    release: .init(primaryLanguage: "ko-KR")
                ),
                blueprint: try makeBlueprint(),
                environment: requiredEnvironment(matchGitURL: "https://github.com/axiom-orient/AppStoreConnect")
            )
        )

        #expect(result.metadata.appName == "Blueprint Name")
        #expect(result.metadata.appIdentifier == "com.axiomorient.daycraft")
        #expect(result.metadata.appleTeamId == "A1B2C3D4E5")
        #expect(result.metadata.primaryLanguage == "ko-KR")
        #expect(result.metadata.sku == "blueprint.sku")
        #expect(result.metadata.matchGitURL == "https://github.com/axiom-orient/AppStoreConnect")
        #expect(result.bundleIdStatus == .created)
        #expect(result.appStatus == .existing)
        #expect(result.appStoreAppId == "1234567890")
        #expect(result.syncedProfile.identity.appName == "Blueprint Name")
        #expect(result.syncedProfile.release.sku == "blueprint.sku")
        #expect(result.syncedProfile.release.appStoreAppId == "1234567890")
        #expect(result.syncedProfile.release.matchGitURL == "https://github.com/axiom-orient/AppStoreConnect")

        let logPath = try #require(result.artifacts.first(where: { $0.hasSuffix(".log") }))
        let log = try String(contentsOfFile: logPath, encoding: .utf8)
        #expect(log.contains("bundleIdStatus=created"))
        #expect(log.contains("appStatus=existing"))
    }

    @Test func registerPrefersExplicitOverrides() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let engine = AppRegistrationEngine(
            provider: StubProvider(result: .init(bundleIdStatus: .existing, appStatus: .created)),
            appStoreAppIDResolver: StubResolver(
                result: .init(
                    appStoreAppId: "2222222222",
                    source: .lookup,
                    updatedProfile: try makeProfile(
                        identity: .init(
                            companyName: "Axient",
                            appName: "Aether",
                            appIdentifier: "com.axient.aether",
                            appleTeamId: "8GT6LT258Y"
                        ),
                        release: .init(
                            primaryLanguage: "ko-KR",
                            sku: "axient.aether.manual",
                            appStoreAppId: "2222222222",
                            matchGitURL: "git@github.com:axiom-orient/AppStoreConnect.git"
                        )
                    )
                )
            )
        )
        let result = try engine.register(
            request: AppRegistrationRequest(
                projectRoot: root,
                profile: try makeProfile(
                    identity: .init(
                        companyName: "Axiom Orient",
                        appName: "Daycraft",
                        appIdentifier: "com.axiomorient.daycraft",
                        appleTeamId: "A1B2C3D4E5"
                    ),
                    release: .init(primaryLanguage: "en-US", sku: "old.sku")
                ),
                blueprint: try makeBlueprint(),
                overrides: .init(
                    companyName: "Axient",
                    appName: "Aether",
                    appIdentifier: "com.axient.aether",
                    appleTeamId: "8GT6LT258Y",
                    primaryLanguage: "ko",
                    sku: "axient.aether.manual",
                    matchGitURL: "git@github.com:axiom-orient/AppStoreConnect.git"
                ),
                environment: requiredEnvironment()
            )
        )

        #expect(result.metadata.companyName == "Axient")
        #expect(result.metadata.appName == "Aether")
        #expect(result.metadata.appIdentifier == "com.axient.aether")
        #expect(result.metadata.appleTeamId == "8GT6LT258Y")
        #expect(result.metadata.primaryLanguage == "ko-KR")
        #expect(result.metadata.sku == "axient.aether.manual")
        #expect(result.metadata.matchGitURL == "git@github.com:axiom-orient/AppStoreConnect.git")
        #expect(result.appStoreAppId == "2222222222")
    }

    @Test func registerGeneratesDeterministicSKUFromBundlePrefixWhenCompanyNameMissing() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let engine = AppRegistrationEngine(
            provider: StubProvider(result: .init(bundleIdStatus: .existing, appStatus: .existing)),
            appStoreAppIDResolver: StubResolver(
                result: .init(
                    appStoreAppId: "3333333333",
                    source: .lookup,
                    updatedProfile: try makeProfile(
                        identity: .init(
                            appIdentifier: "com.axiomorient.daycraft",
                            appleTeamId: "A1B2C3D4E5"
                        ),
                        release: .init(
                            primaryLanguage: "en-US",
                            sku: "axiomorient.daycraft.04805b02",
                            appStoreAppId: "3333333333"
                        )
                    )
                )
            )
        )
        let result = try engine.register(
            request: AppRegistrationRequest(
                projectRoot: root,
                profile: try makeProfile(
                    identity: .init(
                        appIdentifier: "com.axiomorient.daycraft",
                        appleTeamId: "A1B2C3D4E5"
                    ),
                    release: .init(primaryLanguage: "en-US")
                ),
                environment: requiredEnvironment()
            )
        )

        #expect(result.metadata.appName == "Daycraft")
        #expect(result.metadata.sku == "axiomorient.daycraft.04805b02")
        #expect(result.appStoreAppId == "3333333333")
        #expect(result.syncedProfile.release.appStoreAppId == "3333333333")
        #expect(result.syncedProfile.release.sku == "axiomorient.daycraft.04805b02")
    }

    @Test func registerGeneratesDeterministicSKUWhenOnlyCompanyNameIsAvailable() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let engine = AppRegistrationEngine(
            provider: StubProvider(result: .init(bundleIdStatus: .existing, appStatus: .existing)),
            appStoreAppIDResolver: StubResolver(
                result: .init(
                    appStoreAppId: "4444444444",
                    source: .lookup,
                    updatedProfile: try makeProfile(
                        identity: .init(
                            companyName: "Axiom Orient",
                            appIdentifier: "com.axiomorient.daycraft",
                            appleTeamId: "A1B2C3D4E5"
                        ),
                        release: .init(
                            primaryLanguage: "en-US",
                            sku: "axiom-orient.daycraft.04805b02",
                            appStoreAppId: "4444444444"
                        )
                    )
                )
            )
        )
        let result = try engine.register(
            request: AppRegistrationRequest(
                projectRoot: root,
                profile: try makeProfile(
                    identity: .init(
                        companyName: "Axiom Orient",
                        appIdentifier: "com.axiomorient.daycraft",
                        appleTeamId: "A1B2C3D4E5"
                    ),
                    release: .init(primaryLanguage: "en-US")
                ),
                environment: requiredEnvironment()
            )
        )

        #expect(result.metadata.appName == "Daycraft")
        #expect(result.metadata.sku == "axiom-orient.daycraft.04805b02")
        #expect(result.appStoreAppId == "4444444444")
        #expect(result.syncedProfile.release.appStoreAppId == "4444444444")
        #expect(result.syncedProfile.release.sku == "axiom-orient.daycraft.04805b02")
    }

    @Test func registerKeepsProfileAppStoreAppIdWhenResolverUsesProfileSource() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let existingProfile = try makeProfile(
            identity: .init(
                companyName: "Axiom Orient",
                appIdentifier: "com.axiomorient.daycraft",
                appleTeamId: "A1B2C3D4E5"
            ),
            release: .init(primaryLanguage: "en-US", sku: "manual.sku", appStoreAppId: "5555555555")
        )
        let engine = AppRegistrationEngine(
            provider: StubProvider(result: .init(bundleIdStatus: .existing, appStatus: .existing)),
            appStoreAppIDResolver: StubResolver(
                result: .init(
                    appStoreAppId: "5555555555",
                    source: .profile,
                    updatedProfile: existingProfile
                )
            )
        )

        let result = try engine.register(
            request: AppRegistrationRequest(
                projectRoot: root,
                profile: existingProfile,
                environment: requiredEnvironment()
            )
        )

        #expect(result.appStoreAppId == "5555555555")
        #expect(result.syncedProfile.release.appStoreAppId == "5555555555")
    }

    @Test func registerFailsWhenAppStoreConnectEnvironmentIsMissing() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let engine = AppRegistrationEngine(provider: StubProvider(result: .init(bundleIdStatus: .existing, appStatus: .existing)))

        do {
            _ = try engine.register(
                request: AppRegistrationRequest(
                    projectRoot: root,
                    profile: try makeProfile(
                        identity: .init(
                            companyName: "Axiom Orient",
                            appIdentifier: "com.axiomorient.daycraft",
                            appleTeamId: "A1B2C3D4E5"
                        ),
                        release: .init(primaryLanguage: "en-US", sku: "manual.sku")
                    ),
                    environment: ["ASC_KEY_ID": "AB12CD34EF"]
                )
            )
            Issue.record("expected invalidEnvironment")
        } catch AppRegistrationEngineError.invalidEnvironment(let missingKeys, _) {
            #expect(missingKeys == ["ASC_ISSUER_ID", "ASC_KEY_P8_BASE64"])
        }
    }
}

private extension AppRegistrationIntegrationTests {
    struct StubProvider: AppRegistrationProviding {
        let result: AppRegistrationProviderResult

        func register(metadata: AppRegistrationResolvedMetadata, environment: [String : String]) throws -> AppRegistrationProviderResult {
            result
        }
    }

    struct StubResolver: AppStoreAppIDResolving {
        let result: ASCAppStoreAppResolution

        func resolve(
            profile: Profile,
            projectRoot: URL,
            environment: [String : String],
            bundleIdentifierOverride: String?
        ) throws -> ASCAppStoreAppResolution {
            result
        }
    }

    func makeTempDir() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("bos-app-register-\(ProcessInfo.processInfo.globallyUniqueString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    func makeProfile(
        identity: Profile.Identity,
        release: Profile.ReleaseSettings
    ) throws -> Profile {
        let defaults = Profile.Defaults(
            deploymentTarget: "18.0",
            appTargets: .init(controlsExtension: false, uiTests: true)
        )
        let rules = try Profile.Rules(
            testingStyle: "swift-testing",
            forbidPatterns: ["@unchecked Sendable", "Date()", "UUID()"]
        )
        return try Profile(
            schemaVersion: 1,
            name: "default",
            defaults: defaults,
            identity: identity,
            release: release,
            featurePattern: .init(sourcesInterface: true, designFolder: false),
            rules: rules
        )
    }

    func makeBlueprint() throws -> Blueprint {
        try Blueprint(
            schemaVersion: 1,
            project: .init(name: "Daycraft", bundleIdPrefix: "com.axiomorient", deploymentTarget: "18.0"),
            requirements: .init(reqIds: ["REQ-001"], screens: ["SCR_TODAY_HOME"]),
            modules: .init(
                app: .init(name: "Daycraft"),
                features: ["Root", "TodayHome"],
                domains: ["User"],
                services: ["UserService"],
                shared: ["Core", "DesignSystem"]
            ),
            wiring: .init(rootFeature: "Root"),
            release: .init(
                fastlane: try .init(
                    appIdentifier: "com.axiomorient.daycraft",
                    appleTeamId: "A1B2C3D4E5",
                    appName: "Blueprint Name",
                    sku: "blueprint.sku",
                    primaryLanguage: "en-US",
                    companyName: "Blueprint Co"
                )
            )
        )
    }

    func requiredEnvironment(matchGitURL: String? = nil) -> [String: String] {
        var env: [String: String] = [
            "ASC_ISSUER_ID": "123E4567-E89B-12D3-A456-426614174000",
            "ASC_KEY_ID": "AB12CD34EF",
            "ASC_KEY_P8_BASE64": "c3VwZXItc2VjcmV0"
        ]
        if let matchGitURL {
            env["MATCH_GIT_URL"] = matchGitURL
        }
        return env
    }
}
