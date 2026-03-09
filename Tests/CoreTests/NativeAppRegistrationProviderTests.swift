import Foundation
import os
import Testing
@testable import BosCore

@Suite
struct NativeAppRegistrationProviderTests {
    @Test func providerCreatesBundleIDAndAppWhenResourcesDoNotExist() throws {
        let provider = NativeAppRegistrationProvider { _ in
            StubASCClient(bundleLookups: [false], appLookups: [false])
        }

        let result = try provider.register(
            metadata: metadata(),
            environment: [:]
        )

        #expect(result.bundleIdStatus == .created)
        #expect(result.appStatus == .created)
    }

    @Test func providerTreatsCreateRaceAsExistingWhenResourceAppearsAfterFailure() throws {
        let provider = NativeAppRegistrationProvider { _ in
            StubASCClient(
                bundleLookups: [false, true],
                appLookups: [false, true],
                bundleCreateFailure: .bundleCreate,
                appCreateFailure: .appCreate
            )
        }

        let result = try provider.register(
            metadata: metadata(),
            environment: [:]
        )

        #expect(result.bundleIdStatus == .existing)
        #expect(result.appStatus == .existing)
    }

    @Test func providerPropagatesCreateFailureWhenResourceStillMissing() throws {
        let provider = NativeAppRegistrationProvider { _ in
            StubASCClient(
                bundleLookups: [false, false],
                appLookups: [false],
                bundleCreateFailure: .bundleCreate
            )
        }

        do {
            _ = try provider.register(
                metadata: metadata(),
                environment: [:]
            )
            Issue.record("expected create failure")
        } catch let error as StubFailure {
            #expect(error == .bundleCreate)
        }
    }
}

private extension NativeAppRegistrationProviderTests {
    enum StubFailure: Error, Equatable, Sendable {
        case bundleCreate
        case appCreate
    }

    struct StubASCClient: AppStoreConnectClienting {
        struct State {
            var bundleLookups: [Bool]
            var appLookups: [Bool]
            var bundleCreateFailure: StubFailure?
            var appCreateFailure: StubFailure?
        }

        private let state: OSAllocatedUnfairLock<State>

        init(
            bundleLookups: [Bool],
            appLookups: [Bool],
            bundleCreateFailure: StubFailure? = nil,
            appCreateFailure: StubFailure? = nil
        ) {
            self.state = OSAllocatedUnfairLock(initialState: State(
                bundleLookups: bundleLookups,
                appLookups: appLookups,
                bundleCreateFailure: bundleCreateFailure,
                appCreateFailure: appCreateFailure
            ))
        }

        func hasBundleId(identifier: String) throws -> Bool {
            state.withLock { state in
                if state.bundleLookups.isEmpty {
                    return false
                }
                return state.bundleLookups.removeFirst()
            }
        }

        func createBundleId(identifier: String, name: String) throws {
            try state.withLock { state in
                if let failure = state.bundleCreateFailure {
                    throw failure
                }
            }
        }

        func hasApp(bundleIdentifier: String) throws -> Bool {
            state.withLock { state in
                if state.appLookups.isEmpty {
                    return false
                }
                return state.appLookups.removeFirst()
            }
        }

        func createApp(metadata: AppRegistrationResolvedMetadata) throws {
            try state.withLock { state in
                if let failure = state.appCreateFailure {
                    throw failure
                }
            }
        }
    }

    func metadata() -> AppRegistrationResolvedMetadata {
        .init(
            companyName: "Axiom Orient",
            appName: "Daycraft",
            appIdentifier: "com.axiomorient.daycraft",
            appleTeamId: "A1B2C3D4E5",
            primaryLanguage: "en-US",
            sku: "axiom-orient.daycraft.04805b02",
            matchGitURL: "git@github.com:org/certs.git"
        )
    }
}
