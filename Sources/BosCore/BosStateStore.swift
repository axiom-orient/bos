import Foundation
import Yams

enum BootstrapStateSummaryKind: Sendable {
    case verify
    case release
    case releaseCheck
    case releaseRun
}

enum BosStateStore {
    private static let stateRelativePath = ".bos/state/bos.state.yaml"

    static func updateSummary(
        projectRoot: URL,
        kind: BootstrapStateSummaryKind,
        status: String,
        message: String
    ) {
        mutate(projectRoot: projectRoot) { state in
            let summary = try BootstrapLock.StepSummary(status: status, message: message)
            switch kind {
            case .verify:
                state = try BootstrapLock(
                    appliedAt: state.appliedAt,
                    blueprintHash: state.blueprintHash,
                    profileHash: state.profileHash,
                    managedFiles: state.managedFiles,
                    verifySummary: summary,
                    releaseSummary: state.releaseSummary,
                    releaseCheckSummary: state.releaseCheckSummary,
                    releaseRunSummary: state.releaseRunSummary,
                    derivedState: state.derivedState
                )
            case .release:
                state = try BootstrapLock(
                    appliedAt: state.appliedAt,
                    blueprintHash: state.blueprintHash,
                    profileHash: state.profileHash,
                    managedFiles: state.managedFiles,
                    verifySummary: state.verifySummary,
                    releaseSummary: summary,
                    releaseCheckSummary: state.releaseCheckSummary,
                    releaseRunSummary: state.releaseRunSummary,
                    derivedState: state.derivedState
                )
            case .releaseCheck:
                state = try BootstrapLock(
                    appliedAt: state.appliedAt,
                    blueprintHash: state.blueprintHash,
                    profileHash: state.profileHash,
                    managedFiles: state.managedFiles,
                    verifySummary: state.verifySummary,
                    releaseSummary: state.releaseSummary,
                    releaseCheckSummary: summary,
                    releaseRunSummary: state.releaseRunSummary,
                    derivedState: state.derivedState
                )
            case .releaseRun:
                state = try BootstrapLock(
                    appliedAt: state.appliedAt,
                    blueprintHash: state.blueprintHash,
                    profileHash: state.profileHash,
                    managedFiles: state.managedFiles,
                    verifySummary: state.verifySummary,
                    releaseSummary: state.releaseSummary,
                    releaseCheckSummary: state.releaseCheckSummary,
                    releaseRunSummary: summary,
                    derivedState: state.derivedState
                )
            }
        }
    }

    static func updateReleaseInitState(
        projectRoot: URL,
        status: String,
        summary: String,
        artifactDirectory: String?,
        generatedFiles: [String],
        lanes: [String]
    ) {
        mutate(projectRoot: projectRoot) { state in
            let nextState = try BootstrapLock.ReleaseInitState(
                status: status,
                summary: summary,
                updatedAt: RuntimeSupport.isoNow(),
                artifactDirectory: artifactDirectory,
                generatedFiles: generatedFiles,
                lanes: lanes
            )
            let derived = try BootstrapLock.DerivedState(
                releaseInit: nextState,
                releaseCheck: state.derivedState?.releaseCheck,
                releaseRun: state.derivedState?.releaseRun
            )
            let nextSummary = try BootstrapLock.StepSummary(status: status, message: summary)
            state = try BootstrapLock(
                appliedAt: state.appliedAt,
                blueprintHash: state.blueprintHash,
                profileHash: state.profileHash,
                managedFiles: state.managedFiles,
                verifySummary: state.verifySummary,
                releaseSummary: nextSummary,
                releaseCheckSummary: state.releaseCheckSummary,
                releaseRunSummary: state.releaseRunSummary,
                derivedState: derived
            )
        }
    }

    static func updateReleaseCheckState(
        projectRoot: URL,
        mode: String,
        status: String,
        summary: String,
        completedSteps: [String],
        nextStep: String?,
        failedStep: String?,
        failureCode: String?,
        artifactDirectory: String?
    ) {
        mutate(projectRoot: projectRoot) { state in
            let nextState = try BootstrapLock.ReleaseCheckState(
                status: status,
                summary: summary,
                updatedAt: RuntimeSupport.isoNow(),
                mode: mode,
                completedSteps: uniqueOrdered(completedSteps),
                nextStep: nextStep,
                failedStep: failedStep,
                failureCode: failureCode,
                artifactDirectory: artifactDirectory
            )
            let derived = try BootstrapLock.DerivedState(
                releaseInit: state.derivedState?.releaseInit,
                releaseCheck: nextState,
                releaseRun: state.derivedState?.releaseRun
            )
            let nextSummary = try BootstrapLock.StepSummary(status: status, message: summary)
            state = try BootstrapLock(
                appliedAt: state.appliedAt,
                blueprintHash: state.blueprintHash,
                profileHash: state.profileHash,
                managedFiles: state.managedFiles,
                verifySummary: state.verifySummary,
                releaseSummary: state.releaseSummary,
                releaseCheckSummary: nextSummary,
                releaseRunSummary: state.releaseRunSummary,
                derivedState: derived
            )
        }
    }

    static func updateReleaseRunState(
        projectRoot: URL,
        stage: String,
        signingMode: String,
        status: String,
        summary: String,
        completedSteps: [String],
        nextStep: String?,
        failedStep: String?,
        failureCode: String?,
        artifactDirectory: String?,
        ipaPath: String?
    ) {
        mutate(projectRoot: projectRoot) { state in
            let nextState = try BootstrapLock.ReleaseRunState(
                status: status,
                summary: summary,
                updatedAt: RuntimeSupport.isoNow(),
                stage: stage,
                signingMode: signingMode,
                completedSteps: uniqueOrdered(completedSteps),
                nextStep: nextStep,
                failedStep: failedStep,
                failureCode: failureCode,
                artifactDirectory: artifactDirectory,
                ipaPath: ipaPath
            )
            let derived = try BootstrapLock.DerivedState(
                releaseInit: state.derivedState?.releaseInit,
                releaseCheck: state.derivedState?.releaseCheck,
                releaseRun: nextState
            )
            let nextSummary = try BootstrapLock.StepSummary(status: status, message: summary)
            state = try BootstrapLock(
                appliedAt: state.appliedAt,
                blueprintHash: state.blueprintHash,
                profileHash: state.profileHash,
                managedFiles: state.managedFiles,
                verifySummary: state.verifySummary,
                releaseSummary: state.releaseSummary,
                releaseCheckSummary: state.releaseCheckSummary,
                releaseRunSummary: nextSummary,
                derivedState: derived
            )
        }
    }

    static func releaseRunState(projectRoot: URL) -> BootstrapLock.ReleaseRunState? {
        load(projectRoot: projectRoot)?.derivedState?.releaseRun
    }
}

private extension BosStateStore {
    static func load(projectRoot: URL) -> BootstrapLock? {
        let statePath = projectRoot.standardizedFileURL.appending(path: stateRelativePath)
        guard FileManager.default.fileExists(atPath: statePath.path(percentEncoded: false)) else {
            return nil
        }
        guard let text = try? String(contentsOf: statePath, encoding: .utf8) else {
            return nil
        }
        return try? YAMLDecoder().decode(BootstrapLock.self, from: text)
    }

    static func save(_ state: BootstrapLock, projectRoot: URL) throws {
        let statePath = projectRoot.standardizedFileURL.appending(path: stateRelativePath)
        let encoded = try YAMLEncoder().encode(state)
        try Data(encoded.utf8).write(to: statePath, options: .atomic)
    }

    static func mutate(
        projectRoot: URL,
        _ transform: (inout BootstrapLock) throws -> Void
    ) {
        guard var state = load(projectRoot: projectRoot.standardizedFileURL) else {
            return
        }
        do {
            try transform(&state)
            try save(state, projectRoot: projectRoot)
        } catch {
            return
        }
    }

    static func uniqueOrdered(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for value in values where !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if seen.insert(value).inserted {
                ordered.append(value)
            }
        }
        return ordered
    }
}
