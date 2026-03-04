import XCTest
@testable import BosCore

final class SchemaValidationTests: XCTestCase {
    private let decoder = JSONDecoder()

    func testBlueprintV1DecodesValidPayload() throws {
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
        XCTAssertEqual(model.schemaVersion, 1)
        XCTAssertEqual(model.release.fastlane.appleTeamId, "A1B2C3D4E5")
    }

    func testBlueprintV1FailsOnUnknownTopLevelKey() {
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

        XCTAssertThrowsError(try decoder.decode(BlueprintV1.self, from: Data(json.utf8))) { error in
            guard case SchemaValidationError.unknownKeys(let schema, let keys) = error else {
                return XCTFail("unexpected error: \(error)")
            }
            XCTAssertEqual(schema, "BlueprintV1")
            XCTAssertEqual(keys, ["unexpected"])
        }
    }

    func testProfileV1DecodesValidPayload() throws {
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
        XCTAssertEqual(model.name, "daycraft")
        XCTAssertEqual(model.defaults.appTargets.controlsExtension, true)
    }

    func testProfileV1FailsOnUnknownNestedKey() {
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

        XCTAssertThrowsError(try decoder.decode(ProfileV1.self, from: Data(json.utf8))) { error in
            guard case SchemaValidationError.unknownKeys(let schema, let keys) = error else {
                return XCTFail("unexpected error: \(error)")
            }
            XCTAssertEqual(schema, "ProfileV1.defaults.appTargets")
            XCTAssertEqual(keys, ["extra"])
        }
    }

    func testToolchainLockV1DecodesValidPayload() throws {
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
        XCTAssertEqual(model.tuist, "4.153.1")
    }

    func testToolchainLockV1FailsOnUnknownNestedKey() {
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

        XCTAssertThrowsError(try decoder.decode(ToolchainLockV1.self, from: Data(json.utf8))) { error in
            guard case SchemaValidationError.unknownKeys(let schema, let keys) = error else {
                return XCTFail("unexpected error: \(error)")
            }
            XCTAssertEqual(schema, "ToolchainLockV1.tmaPluginRef")
            XCTAssertEqual(keys, ["revision"])
        }
    }

    func testToolchainLockV2DecodesValidPayload() throws {
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
        XCTAssertEqual(model.schemaVersion, 2)
        XCTAssertEqual(model.tools.tuist.requiredFor, ["apply", "verify"])
    }

    func testToolchainLockV2FailsOnUnknownToolKey() {
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

        XCTAssertThrowsError(try decoder.decode(ToolchainLockV2.self, from: Data(json.utf8))) { error in
            guard case SchemaValidationError.unknownKeys(let schema, let keys) = error else {
                return XCTFail("unexpected error: \(error)")
            }
            XCTAssertEqual(schema, "ToolchainLockV2.tools")
            XCTAssertEqual(keys, ["ruby"])
        }
    }

    func testBootstrapLockV1DecodesValidPayload() throws {
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
        XCTAssertEqual(model.verifySummary.status, "passed")
    }

    func testBootstrapLockV1FailsOnUnknownTopLevelKey() {
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

        XCTAssertThrowsError(try decoder.decode(BootstrapLockV1.self, from: Data(json.utf8))) { error in
            guard case SchemaValidationError.unknownKeys(let schema, let keys) = error else {
                return XCTFail("unexpected error: \(error)")
            }
            XCTAssertEqual(schema, "BootstrapLockV1")
            XCTAssertEqual(keys, ["extra"])
        }
    }
}
