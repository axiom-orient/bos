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
              "appleTeamId": "A1B2C3D4E5"
            }
          }
        }
        """
        let model = try decoder.decode(BlueprintV1.self, from: Data(json.utf8))
        #expect(model.schemaVersion == 1)
        #expect(model.release.fastlane.appleTeamId == "A1B2C3D4E5")
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
            _ = try decoder.decode(BlueprintV1.self, from: Data(json.utf8))
            Issue.record("expected SchemaValidationError.unknownKeys to be thrown")
        } catch let error as SchemaValidationError {
            if case .unknownKeys(let schema, let keys) = error {
                #expect(schema == "BlueprintV1")
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
        let model = try decoder.decode(ProfileV1.self, from: Data(json.utf8))
        #expect(model.name == "daycraft")
        #expect(model.defaults.appTargets.controlsExtension == true)
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
            _ = try decoder.decode(ProfileV1.self, from: Data(json.utf8))
            Issue.record("expected SchemaValidationError.unknownKeys to be thrown")
        } catch let error as SchemaValidationError {
            if case .unknownKeys(let schema, let keys) = error {
                #expect(schema == "ProfileV1.defaults.appTargets")
                #expect(keys == ["extra"])
            } else {
                Issue.record("unexpected SchemaValidationError: \(error)")
            }
        }
    }

    @Test func toolchainLockV1DecodesValidPayload() throws {
        let json = """
        {
          "schemaVersion": 1,
          "swift": "6.0",
          "tuist": "4.153.1",
          "fastlane": "2.228.0",
          "tmaPluginRef": {
            "type": "git-sha",
            "value": "7c00394f304f966f4ce621a7b72f2b3b19789509"
          }
        }
        """
        let model = try decoder.decode(ToolchainLockV1.self, from: Data(json.utf8))
        #expect(model.tuist == "4.153.1")
    }

    @Test func toolchainLockV1FailsOnUnknownNestedKey() throws {
        let json = """
        {
          "schemaVersion": 1,
          "swift": "6.0",
          "tuist": "4.153.1",
          "fastlane": "2.228.0",
          "tmaPluginRef": {
            "type": "git-sha",
            "value": "abc",
            "revision": "main"
          }
        }
        """

        do {
            _ = try decoder.decode(ToolchainLockV1.self, from: Data(json.utf8))
            Issue.record("expected SchemaValidationError.unknownKeys to be thrown")
        } catch let error as SchemaValidationError {
            if case .unknownKeys(let schema, let keys) = error {
                #expect(schema == "ToolchainLockV1.tmaPluginRef")
                #expect(keys == ["revision"])
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
              "requiredFor": ["plan", "apply", "verify", "release-init"],
              "installHints": ["xcode-select --install", "brew install swift"]
            },
            "tuist": {
              "versionRule": { "kind": "semver-range", "value": ">=4.0 <5.0" },
              "requiredFor": ["apply", "verify"],
              "installHints": ["brew install tuist"]
            },
            "fastlane": {
              "versionRule": { "kind": "semver-range", "value": ">=2.0 <3.0" },
              "requiredFor": ["release-init"],
              "installHints": ["brew install fastlane", "gem install fastlane -NV"]
            }
          },
          "tmaPluginRef": {
            "type": "git-sha",
            "value": "7c00394f304f966f4ce621a7b72f2b3b19789509"
          }
        }
        """
        let model = try decoder.decode(ToolchainLockV2.self, from: Data(json.utf8))
        #expect(model.schemaVersion == 2)
        #expect(model.tools.tuist.requiredFor == ["apply", "verify"])
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
            _ = try decoder.decode(ToolchainLockV2.self, from: Data(json.utf8))
            Issue.record("expected SchemaValidationError.unknownKeys to be thrown")
        } catch let error as SchemaValidationError {
            if case .unknownKeys(let schema, let keys) = error {
                #expect(schema == "ToolchainLockV2.tools")
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
        let model = try decoder.decode(BootstrapLockV1.self, from: Data(json.utf8))
        #expect(model.verifySummary.status == "passed")
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
            _ = try decoder.decode(BootstrapLockV1.self, from: Data(json.utf8))
            Issue.record("expected SchemaValidationError.unknownKeys to be thrown")
        } catch let error as SchemaValidationError {
            if case .unknownKeys(let schema, let keys) = error {
                #expect(schema == "BootstrapLockV1")
                #expect(keys == ["extra"])
            } else {
                Issue.record("unexpected SchemaValidationError: \(error)")
            }
        }
    }
}
