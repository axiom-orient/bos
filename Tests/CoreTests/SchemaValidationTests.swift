import Foundation
import Testing
@testable import BosCore

@Suite
struct SchemaValidationTests {
    private let decoder = JSONDecoder()

    @Test func blueprintV1DecodesValidPayload() throws {
        let json = """
        {
          "schemaVersion": 1,
          "project": {
            "name": "Daycraft",
            "bundleIdPrefix": "com.axiomorient",
            "deploymentTarget": "18.0"
          },
          "requirements": {
            "reqIds": ["REQ-001"],
            "screens": ["SCR_HOME"]
          },
          "modules": {
            "app": { "name": "Daycraft" },
            "features": ["Root"],
            "domains": ["User"],
            "services": ["Auth"],
            "shared": ["Core"]
          },
          "wiring": {
            "rootFeature": "Root"
          },
          "release": {
            "fastlane": {
              "appIdentifier": "com.axiomorient.daycraft",
              "appleTeamId": "A1B2C3D4E5",
              "appName": "Daycraft",
              "sku": "axiom-orient.daycraft.04805b02",
              "primaryLanguage": "ko-KR",
              "companyName": "Axiom Orient"
            }
          }
        }
        """
        let model = try decoder.decode(Blueprint.self, from: Data(json.utf8))
        #expect(model.schemaVersion == 1)
        #expect(model.release.fastlane.appleTeamId == "A1B2C3D4E5")
        #expect(model.release.fastlane.appName == "Daycraft")
        #expect(model.release.fastlane.primaryLanguage == "ko-KR")
    }

    @Test func blueprintV1FailsOnUnknownTopLevelKey() throws {
        let json = """
        {
          "schemaVersion": 1,
          "project": {
            "name": "Daycraft",
            "bundleIdPrefix": "com.axiomorient",
            "deploymentTarget": "18.0"
          },
          "requirements": {
            "reqIds": ["REQ-001"],
            "screens": ["SCR_HOME"]
          },
          "modules": {
            "app": { "name": "Daycraft" },
            "features": ["Root"],
            "domains": ["User"],
            "services": ["Auth"],
            "shared": ["Core"]
          },
          "wiring": {
            "rootFeature": "Root"
          },
          "release": {
            "fastlane": {
              "appIdentifier": "com.axiomorient.daycraft",
              "appleTeamId": "A1B2C3D4E5"
            }
          },
          "unexpected": true
        }
        """

        do {
            _ = try decoder.decode(Blueprint.self, from: Data(json.utf8))
            Issue.record("expected SchemaValidationError.unknownKeys to be thrown")
        } catch let error as SchemaValidationError {
            if case .unknownKeys(let schema, let keys) = error {
                #expect(schema == "Blueprint")
                #expect(keys == ["unexpected"])
            } else {
                Issue.record("unexpected SchemaValidationError: \(error)")
            }
        }
    }

    @Test func profileV1DecodesValidPayload() throws {
        let json = """
        {
          "schemaVersion": 1,
          "name": "daycraft",
          "defaults": {
            "deploymentTarget": "18.0",
            "appTargets": {
              "controlsExtension": true,
              "uiTests": true
            }
          },
          "identity": {
            "companyName": "Axiom Orient",
            "appName": "Daycraft",
            "appIdentifier": "com.axiomorient.daycraft",
            "appleTeamId": "A1B2C3D4E5"
          },
          "release": {
            "primaryLanguage": "ko-KR",
            "sku": "axiom-orient.daycraft.04805b02",
            "appStoreAppId": "1234567890",
            "matchGitURL": "https://github.com/axiom-orient/AppStoreConnect"
          },
          "featurePattern": {
            "sourcesInterface": true,
            "designFolder": true
          },
          "rules": {
            "testingStyle": "swift-testing",
            "forbidPatterns": ["@unchecked Sendable", "Date()", "UUID()"]
          }
        }
        """
        let model = try decoder.decode(Profile.self, from: Data(json.utf8))
        #expect(model.name == "daycraft")
        #expect(model.defaults.appTargets.controlsExtension == true)
        #expect(model.identity.companyName == "Axiom Orient")
        #expect(model.release.primaryLanguage == "ko-KR")
        #expect(model.release.appStoreAppId == "1234567890")
    }

    @Test func profileV1RejectsNonNumericAppStoreAppId() throws {
        let json = """
        {
          "schemaVersion": 1,
          "name": "daycraft",
          "defaults": {
            "deploymentTarget": "18.0",
            "appTargets": {
              "controlsExtension": true,
              "uiTests": true
            }
          },
          "release": {
            "primaryLanguage": "ko-KR",
            "appStoreAppId": "abc123"
          },
          "featurePattern": {
            "sourcesInterface": true,
            "designFolder": true
          },
          "rules": {
            "testingStyle": "swift-testing",
            "forbidPatterns": ["Date()"]
          }
        }
        """

        do {
            _ = try decoder.decode(Profile.self, from: Data(json.utf8))
            Issue.record("expected SchemaValidationError.invalidValue to be thrown")
        } catch let error as SchemaValidationError {
            if case .invalidValue(let schema, let field, _) = error {
                #expect(schema == "Profile.release")
                #expect(field == "appStoreAppId")
            } else {
                Issue.record("unexpected SchemaValidationError: \(error)")
            }
        }
    }

    @Test func profileReleaseSettingsRoundTripPreservesAppStoreAppId() throws {
        let profile = try Profile(
            schemaVersion: 1,
            name: "daycraft",
            defaults: .init(
                deploymentTarget: "18.0",
                appTargets: .init(controlsExtension: false, uiTests: true)
            ),
            identity: .init(
                companyName: "Axiom Orient",
                appName: "Daycraft",
                appIdentifier: "com.axiomorient.daycraft",
                appleTeamId: "A1B2C3D4E5"
            ),
            release: .init(
                primaryLanguage: "ko-KR",
                sku: "axiom-orient.daycraft.04805b02",
                appStoreAppId: "1234567890",
                matchGitURL: "https://github.com/axiom-orient/AppStoreConnect"
            ),
            featurePattern: .init(sourcesInterface: true, designFolder: false),
            rules: try .init(
                testingStyle: "swift-testing",
                forbidPatterns: ["@unchecked Sendable", "Date()", "UUID()"]
            )
        )

        let encoded = try JSONEncoder().encode(profile)
        let decoded = try decoder.decode(Profile.self, from: encoded)

        #expect(decoded.release.appStoreAppId == "1234567890")
        #expect(decoded.release.sku == "axiom-orient.daycraft.04805b02")
    }

    @Test func profileV1FailsOnUnknownNestedKey() throws {
        let json = """
        {
          "schemaVersion": 1,
          "name": "daycraft",
          "defaults": {
            "deploymentTarget": "18.0",
            "appTargets": {
              "controlsExtension": true,
              "uiTests": true,
              "extra": false
            }
          },
          "featurePattern": {
            "sourcesInterface": true,
            "designFolder": true
          },
          "rules": {
            "testingStyle": "swift-testing",
            "forbidPatterns": ["Date()"]
          }
        }
        """

        do {
            _ = try decoder.decode(Profile.self, from: Data(json.utf8))
            Issue.record("expected SchemaValidationError.unknownKeys to be thrown")
        } catch let error as SchemaValidationError {
            if case .unknownKeys(let schema, let keys) = error {
                #expect(schema == "Profile.defaults.appTargets")
                #expect(keys == ["extra"])
            } else {
                Issue.record("unexpected SchemaValidationError: \(error)")
            }
        }
    }

    @Test func toolchainLockV2DecodesValidPayload() throws {
        let json = """
        {
          "schemaVersion": 2,
          "tools": {
            "swift": {
              "versionRule": { "kind": "semver-range", "value": ">=6.0 <7.0" },
              "requiredFor": ["plan", "apply", "verify", "release-init", "release-run"],
              "installHints": ["xcode-select --install", "brew install swift"]
            },
            "tuist": {
              "versionRule": { "kind": "semver-range", "value": ">=4.0 <5.0" },
              "requiredFor": ["apply", "verify", "release-run"],
              "installHints": ["brew install tuist"]
            },
            "fastlane": {
              "versionRule": { "kind": "semver-range", "value": ">=2.0 <3.0" },
              "requiredFor": ["release-init", "release-check", "release-run"],
              "installHints": ["brew install fastlane", "gem install fastlane -NV"]
            },
            "asc": {
              "versionRule": { "kind": "semver-range", "value": ">=0.1.0" },
              "requiredFor": ["app-register", "release-check", "release-run"],
              "installHints": ["brew install asc", "curl -fsSL https://asccli.sh/install | bash"]
            }
          },
          "tmaPluginRef": {
            "type": "git-sha",
            "value": "7c00394f304f966f4ce621a7b72f2b3b19789509"
          }
        }
        """
        let model = try decoder.decode(ToolchainLock.self, from: Data(json.utf8))
        #expect(model.schemaVersion == 2)
        #expect(model.tools.tuist.requiredFor == ["apply", "verify", "release-run"])
        #expect(model.tools.fastlane.requiredFor == ["release-init", "release-check", "release-run"])
        #expect(model.tools.asc.requiredFor == ["app-register", "release-check", "release-run"])
    }

    @Test func toolchainLockV2FailsOnUnknownToolKey() throws {
        let json = """
        {
          "schemaVersion": 2,
          "tools": {
            "swift": {
              "versionRule": { "kind": "semver-range", "value": ">=6.0 <7.0" },
              "requiredFor": ["plan"],
              "installHints": ["xcode-select --install"]
            },
            "tuist": {
              "versionRule": { "kind": "semver-range", "value": ">=4.0 <5.0" },
              "requiredFor": ["apply"],
              "installHints": ["brew install tuist"]
            },
            "fastlane": {
              "versionRule": { "kind": "semver-range", "value": ">=2.0 <3.0" },
              "requiredFor": ["release-init"],
              "installHints": ["brew install fastlane"]
            },
            "ruby": {
              "versionRule": { "kind": "semver-range", "value": ">=3.0 <4.0" },
              "requiredFor": ["release-init"],
              "installHints": ["brew install ruby"]
            }
          },
          "tmaPluginRef": {
            "type": "git-sha",
            "value": "abc"
          }
        }
        """

        do {
            _ = try decoder.decode(ToolchainLock.self, from: Data(json.utf8))
            Issue.record("expected SchemaValidationError.unknownKeys to be thrown")
        } catch let error as SchemaValidationError {
            if case .unknownKeys(let schema, let keys) = error {
                #expect(schema == "ToolchainLock.tools")
                #expect(keys == ["ruby"])
            } else {
                Issue.record("unexpected SchemaValidationError: \(error)")
            }
        }
    }

    @Test func bootstrapLockV1DecodesValidPayload() throws {
        let json = """
        {
          "appliedAt": "2026-03-04T10:00:00Z",
          "blueprintHash": "abc123",
          "profileHash": "def456",
          "managedFiles": ["Projects/App/Project.swift"],
          "verifySummary": {
            "status": "passed",
            "message": "tuist/xcodebuild ok"
          },
          "releaseSummary": {
            "status": "skipped",
            "message": "release-init not requested"
          }
        }
        """
        let model = try decoder.decode(BootstrapLock.self, from: Data(json.utf8))
        #expect(model.verifySummary.status == "passed")
        #expect(model.releaseCheckSummary == nil)
        #expect(model.releaseRunSummary == nil)
    }

    @Test func bootstrapLockV1DecodesOptionalReleaseCheckSummary() throws {
        let json = """
        {
          "appliedAt": "2026-03-04T10:00:00Z",
          "blueprintHash": "abc123",
          "profileHash": "def456",
          "managedFiles": ["Projects/App/Project.swift"],
          "verifySummary": {
            "status": "passed",
            "message": "tuist/xcodebuild ok"
          },
          "releaseSummary": {
            "status": "skipped",
            "message": "release-init not requested"
          },
          "releaseCheckSummary": {
            "status": "passed",
            "message": "release-check ok"
          }
        }
        """
        let model = try decoder.decode(BootstrapLock.self, from: Data(json.utf8))
        #expect(model.releaseCheckSummary?.status == "passed")
        #expect(model.releaseRunSummary == nil)
    }

    @Test func bootstrapLockV1DecodesOptionalReleaseRunSummary() throws {
        let json = """
        {
          "appliedAt": "2026-03-04T10:00:00Z",
          "blueprintHash": "abc123",
          "profileHash": "def456",
          "managedFiles": ["Projects/App/Project.swift"],
          "verifySummary": {
            "status": "passed",
            "message": "tuist/xcodebuild ok"
          },
          "releaseSummary": {
            "status": "skipped",
            "message": "release-init not requested"
          },
          "releaseCheckSummary": {
            "status": "passed",
            "message": "release-check ok"
          },
          "releaseRunSummary": {
            "status": "passed",
            "message": "release-run ok"
          }
        }
        """
        let model = try decoder.decode(BootstrapLock.self, from: Data(json.utf8))
        #expect(model.releaseRunSummary?.status == "passed")
    }

    @Test func bootstrapLockV1FailsOnUnknownTopLevelKey() throws {
        let json = """
        {
          "appliedAt": "2026-03-04T10:00:00Z",
          "blueprintHash": "abc123",
          "profileHash": "def456",
          "managedFiles": ["Projects/App/Project.swift"],
          "verifySummary": { "status": "passed" },
          "releaseSummary": { "status": "skipped" },
          "extra": "x"
        }
        """

        do {
            _ = try decoder.decode(BootstrapLock.self, from: Data(json.utf8))
            Issue.record("expected SchemaValidationError.unknownKeys to be thrown")
        } catch let error as SchemaValidationError {
            if case .unknownKeys(let schema, let keys) = error {
                #expect(schema == "BootstrapLock")
                #expect(keys == ["extra"])
            } else {
                Issue.record("unexpected SchemaValidationError: \(error)")
            }
        }
    }
}
