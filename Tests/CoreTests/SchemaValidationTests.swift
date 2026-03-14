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
            "xcode": {
              "versionRule": { "kind": "semver-range", "value": ">=16.0 <17.0" },
              "requiredFor": ["verify", "release-run"],
              "installHints": ["xcode-select --install", "sudo xcode-select -s /Applications/Xcode.app"]
            },
            "tuist": {
              "versionRule": { "kind": "semver-range", "value": ">=4.0 <5.0" },
              "requiredFor": ["apply", "verify", "release-run"],
              "installHints": ["brew install tuist"]
            },
            "ruby": {
              "versionRule": { "kind": "semver-range", "value": ">=3.0 <4.0" },
              "requiredFor": ["release-init", "release-check", "release-run"],
              "installHints": ["brew install ruby"]
            },
            "bundler": {
              "versionRule": { "kind": "semver-range", "value": ">=2.0 <3.0" },
              "requiredFor": ["release-init", "release-check", "release-run"],
              "installHints": ["gem install bundler"]
            },
            "node": {
              "versionRule": { "kind": "semver-range", "value": ">=20.0 <23.0" },
              "requiredFor": ["metadata", "screenshots"],
              "installHints": ["brew install node"]
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
            },
            "devicectl": {
              "versionRule": { "kind": "present", "value": "present" },
              "requiredFor": ["device", "screenshots"],
              "installHints": ["xcrun --find devicectl"]
            },
            "simctl": {
              "versionRule": { "kind": "present", "value": "present" },
              "requiredFor": ["screenshots", "verify"],
              "installHints": ["xcrun --find simctl"]
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
        #expect(model.tools.xcode?.requiredFor == ["verify", "release-run"])
        #expect(model.tools.tuist.requiredFor == ["apply", "verify", "release-run"])
        #expect(model.tools.ruby?.requiredFor == ["release-init", "release-check", "release-run"])
        #expect(model.tools.bundler?.requiredFor == ["release-init", "release-check", "release-run"])
        #expect(model.tools.node?.requiredFor == ["metadata", "screenshots"])
        #expect(model.tools.fastlane.requiredFor == ["release-init", "release-check", "release-run"])
        #expect(model.tools.asc.requiredFor == ["app-register", "release-check", "release-run"])
        #expect(model.tools.devicectl?.versionRule.kind == "present")
        #expect(model.tools.simctl?.versionRule.kind == "present")
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
            "go": {
              "versionRule": { "kind": "semver-range", "value": ">=3.0 <4.0" },
              "requiredFor": ["release-init"],
              "installHints": ["brew install go"]
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
                #expect(keys == ["go"])
            } else {
                Issue.record("unexpected SchemaValidationError: \(error)")
            }
        }
    }

    @Test func toolchainLockV2LegacyShapeDecodesWithoutExpandedToolKeys() throws {
        let json = """
        {
          "schemaVersion": 2,
          "tools": {
            "swift": {
              "versionRule": { "kind": "semver-range", "value": ">=6.0 <7.0" },
              "requiredFor": ["plan", "apply", "verify"],
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
              "installHints": ["brew install fastlane"]
            }
          },
          "tmaPluginRef": {
            "type": "git-sha",
            "value": "abc"
          }
        }
        """

        let model = try decoder.decode(ToolchainLock.self, from: Data(json.utf8))
        #expect(model.tools.xcode == nil)
        #expect(model.tools.ruby == nil)
        #expect(model.tools.bundler == nil)
        #expect(model.tools.node == nil)
        #expect(model.tools.devicectl == nil)
        #expect(model.tools.simctl == nil)
        #expect(model.tools.asc.requiredFor == [
            ToolchainLock.commandAppRegister,
            ToolchainLock.commandReleaseCheck,
            ToolchainLock.commandReleaseRun
        ])
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

    @Test func bootstrapLockV2DecodesDerivedReleaseState() throws {
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
            "status": "success",
            "message": "release-init completed"
          },
          "releaseCheckSummary": {
            "status": "success",
            "message": "Release check passed (readonly-certs)"
          },
          "releaseRunSummary": {
            "status": "failed",
            "message": "submit failed"
          },
          "derivedState": {
            "releaseInit": {
              "status": "success",
              "summary": "release-init completed",
              "updatedAt": "2026-03-04T10:10:00Z",
              "artifactDirectory": ".bos/artifacts/release-init/release-init-20260304T101000Z",
              "generatedFiles": ["fastlane/Fastfile"],
              "lanes": ["build", "submit"]
            },
            "releaseCheck": {
              "status": "success",
              "summary": "Release check passed (readonly-certs)",
              "updatedAt": "2026-03-04T10:12:00Z",
              "mode": "readonly-certs",
              "completedSteps": ["environment-validation", "fastlane-scaffold", "match-repo", "app-store-connect-auth", "cert-sync", "app-store-readiness"]
            },
            "releaseRun": {
              "status": "failed",
              "summary": "submit failed",
              "updatedAt": "2026-03-04T10:15:00Z",
              "stage": "submit",
              "signingMode": "readonly-certs",
              "completedSteps": ["release-init", "release-check", "tuist-install", "tuist-generate", "workspace-resolve", "fastlane-build"],
              "nextStep": "fastlane-submit",
              "failedStep": "fastlane-submit",
              "failureCode": "E-SUBMIT",
              "artifactDirectory": ".bos/artifacts/release-run/release-run-20260304T101500Z",
              "ipaPath": ".bos/artifacts/release-run/release-run-20260304T101500Z/artifacts/daycraftapp.ipa"
            }
          }
        }
        """

        let model = try decoder.decode(BootstrapLock.self, from: Data(json.utf8))
        #expect(model.derivedState?.releaseInit?.lanes == ["build", "submit"])
        #expect(model.derivedState?.releaseCheck?.mode == "readonly-certs")
        #expect(model.derivedState?.releaseRun?.nextStep == "fastlane-submit")
        #expect(model.derivedState?.releaseRun?.ipaPath?.hasSuffix("daycraftapp.ipa") == true)
    }

    @Test func bootstrapLockV2RejectsDuplicateCompletedStepsInReleaseRunState() throws {
        let json = """
        {
          "appliedAt": "2026-03-04T10:00:00Z",
          "blueprintHash": "abc123",
          "profileHash": "def456",
          "managedFiles": ["Projects/App/Project.swift"],
          "verifySummary": { "status": "passed" },
          "releaseSummary": { "status": "success" },
          "releaseRunSummary": { "status": "failed" },
          "derivedState": {
            "releaseRun": {
              "status": "failed",
              "summary": "submit failed",
              "updatedAt": "2026-03-04T10:15:00Z",
              "stage": "submit",
              "signingMode": "readonly-certs",
              "completedSteps": ["release-init", "release-init"]
            }
          }
        }
        """

        do {
            _ = try decoder.decode(BootstrapLock.self, from: Data(json.utf8))
            Issue.record("expected SchemaValidationError.invalidValue to be thrown")
        } catch let error as SchemaValidationError {
            if case .invalidValue(let schema, let field, _) = error {
                #expect(schema == "BootstrapLock.releaseRunState")
                #expect(field == "completedSteps")
            } else {
                Issue.record("unexpected SchemaValidationError: \(error)")
            }
        }
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

    @Test func bosProjectManifestV1DecodesValidPayload() throws {
        let json = """
        {
          "schemaVersion": 1,
          "product": {
            "mode": "single-app"
          },
          "paths": {
            "profile": "config/bos.profile.yaml",
            "blueprintLock": "config/blueprint.lock.yaml",
            "releasePolicy": "config/release.policy.yaml",
            "screenshotsPlan": "config/screenshots.plan.yaml",
            "signingEnv": ".bos/secrets/signing.env",
            "state": ".bos/state/bos.state.yaml"
          }
        }
        """

        let manifest = try decoder.decode(BosProjectManifest.self, from: Data(json.utf8))
        #expect(manifest.schemaVersion == 1)
        #expect(manifest.product.mode == "single-app")
        #expect(manifest.paths.profile == "config/bos.profile.yaml")
        #expect(manifest.paths.signingEnv == ".bos/secrets/signing.env")
    }

    @Test func bosProjectManifestFailsOnUnknownPathKey() throws {
        let json = """
        {
          "schemaVersion": 1,
          "product": {
            "mode": "single-app"
          },
          "paths": {
            "profile": "config/bos.profile.yaml",
            "blueprintLock": "config/blueprint.lock.yaml",
            "releasePolicy": "config/release.policy.yaml",
            "screenshotsPlan": "config/screenshots.plan.yaml",
            "signingEnv": ".bos/secrets/signing.env",
            "state": ".bos/state/bos.state.yaml",
            "extra": "ignored"
          }
        }
        """

        do {
            _ = try decoder.decode(BosProjectManifest.self, from: Data(json.utf8))
            Issue.record("expected SchemaValidationError.unknownKeys to be thrown")
        } catch let error as SchemaValidationError {
            if case .unknownKeys(let schema, let keys) = error {
                #expect(schema == "BosProjectManifest.paths")
                #expect(keys == ["extra"])
            } else {
                Issue.record("unexpected SchemaValidationError: \(error)")
            }
        }
    }

    @Test func metadataDirectoryContractV1DecodesValidPayload() throws {
        let json = """
        {
          "schemaVersion": 1,
          "rootDirectory": "metadata",
          "defaultLocale": "en-US",
          "localeDirectories": [
            { "locale": "en-US", "relativePath": "metadata/en-US" },
            { "locale": "ko-KR", "relativePath": "metadata/ko-KR" }
          ],
          "requiredFiles": [
            "name.txt",
            "subtitle.txt",
            "description.txt",
            "keywords.txt",
            "release_notes.txt"
          ],
          "optionalFiles": [
            "promotional_text.txt",
            "marketing_url.txt",
            "support_url.txt",
            "privacy_url.txt"
          ]
        }
        """

        let model = try decoder.decode(MetadataDirectoryContract.self, from: Data(json.utf8))
        #expect(model.defaultLocale == "en-US")
        #expect(model.localeDirectories.count == 2)
        #expect(model.requiredFiles.contains("release_notes.txt"))
    }

    @Test func metadataDirectoryContractV1RejectsDuplicateRequiredFiles() throws {
        let json = """
        {
          "schemaVersion": 1,
          "rootDirectory": "metadata",
          "defaultLocale": "en-US",
          "localeDirectories": [
            { "locale": "en-US", "relativePath": "metadata/en-US" }
          ],
          "requiredFiles": [
            "description.txt",
            "description.txt"
          ]
        }
        """

        do {
            _ = try decoder.decode(MetadataDirectoryContract.self, from: Data(json.utf8))
            Issue.record("expected SchemaValidationError.invalidValue to be thrown")
        } catch let error as SchemaValidationError {
            if case .invalidValue(let schema, let field, _) = error {
                #expect(schema == "MetadataDirectoryContract")
                #expect(field == "requiredFiles")
            } else {
                Issue.record("unexpected SchemaValidationError: \(error)")
            }
        }
    }

    @Test func metadataValidationReportDecodesValidPayload() throws {
        let json = """
        {
          "valid": false,
          "missingLocales": ["ko-KR"],
          "missingRequiredFiles": ["metadata/en-US/description.txt"],
          "emptyRequiredFiles": ["metadata/en-US/release_notes.txt"]
        }
        """

        let report = try decoder.decode(MetadataValidationReport.self, from: Data(json.utf8))
        #expect(report.valid == false)
        #expect(report.missingLocales == ["ko-KR"])
        #expect(report.emptyRequiredFiles == ["metadata/en-US/release_notes.txt"])
    }

    @Test func screenshotPlanV1DecodesValidPayload() throws {
        let json = """
        {
          "schemaVersion": 1,
          "defaultLocale": "en-US",
          "locales": [
            { "locale": "en-US", "displayName": "English (US)" },
            { "locale": "ko-KR", "displayName": "Korean" }
          ],
          "devices": [
            {
              "id": "iphone-69",
              "name": "iPhone 16 Pro Max",
              "family": "iphone",
              "platform": "simulator",
              "orientation": "portrait",
              "pixelSize": { "width": 1320, "height": 2868 }
            }
          ],
          "shots": [
            {
              "id": "today-home",
              "screenID": "SCR_TODAY_HOME",
              "locales": ["en-US", "ko-KR"],
              "devices": ["iphone-69"],
              "launchArguments": ["BOS_SCREENSHOT=SCR_TODAY_HOME"],
              "outputName": "today-home"
            }
          ],
          "export": {
            "rootDirectory": "screenshots/export",
            "format": "png",
            "includeFrame": false
          }
        }
        """

        let model = try decoder.decode(ScreenshotPlan.self, from: Data(json.utf8))
        #expect(model.defaultLocale == "en-US")
        #expect(model.devices.first?.pixelSize.width == 1320)
        #expect(model.shots.first?.devices == ["iphone-69"])
    }

    @Test func screenshotPlanV1RejectsUnknownShotDeviceReference() throws {
        let json = """
        {
          "schemaVersion": 1,
          "defaultLocale": "en-US",
          "locales": [
            { "locale": "en-US", "displayName": "English (US)" }
          ],
          "devices": [
            {
              "id": "iphone-69",
              "name": "iPhone 16 Pro Max",
              "family": "iphone",
              "platform": "simulator",
              "orientation": "portrait",
              "pixelSize": { "width": 1320, "height": 2868 }
            }
          ],
          "shots": [
            {
              "id": "today-home",
              "screenID": "SCR_TODAY_HOME",
              "locales": ["en-US"],
              "devices": ["ipad-13"],
              "outputName": "today-home"
            }
          ],
          "export": {
            "rootDirectory": "screenshots/export",
            "format": "png",
            "includeFrame": false
          }
        }
        """

        do {
            _ = try decoder.decode(ScreenshotPlan.self, from: Data(json.utf8))
            Issue.record("expected SchemaValidationError.invalidValue to be thrown")
        } catch let error as SchemaValidationError {
            if case .invalidValue(let schema, let field, _) = error {
                #expect(schema == "ScreenshotPlan")
                #expect(field == "shots.devices")
            } else {
                Issue.record("unexpected SchemaValidationError: \(error)")
            }
        }
    }

    @Test func screenshotPlanV1RejectsDuplicateLocaleDefinitions() throws {
        let json = """
        {
          "schemaVersion": 1,
          "defaultLocale": "en-US",
          "locales": [
            { "locale": "en-US", "displayName": "English (US)" },
            { "locale": "en-US", "displayName": "English Duplicate" }
          ],
          "devices": [
            {
              "id": "iphone-69",
              "name": "iPhone 16 Pro Max",
              "family": "iphone",
              "platform": "simulator",
              "orientation": "portrait",
              "pixelSize": { "width": 1320, "height": 2868 }
            }
          ],
          "shots": [
            {
              "id": "today-home",
              "screenID": "SCR_TODAY_HOME",
              "locales": ["en-US"],
              "devices": ["iphone-69"],
              "outputName": "today-home"
            }
          ],
          "export": {
            "rootDirectory": "screenshots/export",
            "format": "png",
            "includeFrame": false
          }
        }
        """

        do {
            _ = try decoder.decode(ScreenshotPlan.self, from: Data(json.utf8))
            Issue.record("expected SchemaValidationError.invalidValue to be thrown")
        } catch let error as SchemaValidationError {
            if case .invalidValue(let schema, let field, _) = error {
                #expect(schema == "ScreenshotPlan")
                #expect(field == "locales.locale")
            } else {
                Issue.record("unexpected SchemaValidationError: \(error)")
            }
        }
    }

    @Test func deviceInventoryV1DecodesValidPayload() throws {
        let json = """
        {
          "schemaVersion": 1,
          "devices": [
            {
              "id": "SIM-123",
              "name": "iPhone 16 Pro Max",
              "kind": "simulator",
              "platform": "iOS",
              "state": "booted",
              "runtime": "iOS 18.0",
              "isAvailable": true
            },
            {
              "id": "DEV-456",
              "name": "Axient iPhone",
              "kind": "physical",
              "platform": "iOS",
              "state": "connected",
              "isAvailable": true
            }
          ]
        }
        """

        let model = try decoder.decode(DeviceInventory.self, from: Data(json.utf8))
        #expect(model.devices.count == 2)
        #expect(model.devices[0].kind == "simulator")
        #expect(model.devices[1].kind == "physical")
    }

    @Test func deviceInventoryV1RejectsDuplicateIDs() throws {
        let json = """
        {
          "schemaVersion": 1,
          "devices": [
            {
              "id": "SIM-123",
              "name": "iPhone 16 Pro Max",
              "kind": "simulator",
              "platform": "iOS",
              "state": "booted",
              "isAvailable": true
            },
            {
              "id": "SIM-123",
              "name": "Duplicate",
              "kind": "physical",
              "platform": "iOS",
              "state": "connected",
              "isAvailable": true
            }
          ]
        }
        """

        do {
            _ = try decoder.decode(DeviceInventory.self, from: Data(json.utf8))
            Issue.record("expected SchemaValidationError.invalidValue to be thrown")
        } catch let error as SchemaValidationError {
            if case .invalidValue(let schema, let field, _) = error {
                #expect(schema == "DeviceInventory")
                #expect(field == "devices.id")
            } else {
                Issue.record("unexpected SchemaValidationError: \(error)")
            }
        }
    }

    @Test func deviceDoctorReportDecodesValidPayload() throws {
        let json = """
        {
          "healthy": false,
          "findings": ["devicectl not found", "no booted simulator"]
        }
        """

        let report = try decoder.decode(DeviceDoctorReport.self, from: Data(json.utf8))
        #expect(report.healthy == false)
        #expect(report.findings.count == 2)
    }
}
