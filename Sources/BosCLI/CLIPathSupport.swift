import Foundation
import BosCore

func currentWorkingDirectoryURL() -> URL {
    URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
}

private struct ProjectPathRegistry {
    let profilePath: URL
    let legacyProfilePath: URL
    let blueprintLockPath: URL
    let legacyBlueprintPath: URL
    let releasePolicyPath: URL
    let screenshotsPlanPath: URL
    let signingEnvPath: URL
    let legacySigningEnvPath: URL
    let statePath: URL
}

func resolvePath(_ raw: String, base: URL) -> URL {
    let expanded = NSString(string: raw).expandingTildeInPath
    if expanded.hasPrefix("/") {
        return URL(fileURLWithPath: expanded)
    }
    return base.appending(path: expanded)
}

private func pathRegistry(projectRoot: URL) -> ProjectPathRegistry {
    let root = projectRoot.standardizedFileURL
    let manifestPath = root.appending(path: "bos.project.yaml")
    if FileManager.default.fileExists(atPath: manifestPath.path(percentEncoded: false)),
       let manifest = try? decodeYAMLOrJSON(BosProjectManifest.self, at: manifestPath) {
        return ProjectPathRegistry(
            profilePath: resolvePath(manifest.paths.profile, base: root),
            legacyProfilePath: root.appending(path: ".bos/config/profile.yaml"),
            blueprintLockPath: resolvePath(manifest.paths.blueprintLock, base: root),
            legacyBlueprintPath: root.appending(path: ".bos/plan/blueprint.yaml"),
            releasePolicyPath: resolvePath(manifest.paths.releasePolicy, base: root),
            screenshotsPlanPath: resolvePath(manifest.paths.screenshotsPlan, base: root),
            signingEnvPath: resolvePath(manifest.paths.signingEnv, base: root),
            legacySigningEnvPath: root.appending(path: ".bos/config/signing.env"),
            statePath: resolvePath(manifest.paths.state, base: root)
        )
    }

    return ProjectPathRegistry(
        profilePath: root.appending(path: "config/bos.profile.yaml"),
        legacyProfilePath: root.appending(path: ".bos/config/profile.yaml"),
        blueprintLockPath: root.appending(path: "config/blueprint.lock.yaml"),
        legacyBlueprintPath: root.appending(path: ".bos/plan/blueprint.yaml"),
        releasePolicyPath: root.appending(path: "config/release.policy.yaml"),
        screenshotsPlanPath: root.appending(path: "config/screenshots.plan.yaml"),
        signingEnvPath: root.appending(path: ".bos/secrets/signing.env"),
        legacySigningEnvPath: root.appending(path: ".bos/config/signing.env"),
        statePath: root.appending(path: ".bos/state/bos.state.yaml")
    )
}

private func hasProjectRootMarker(at directory: URL) -> Bool {
    let fm = FileManager.default
    let candidates = [
        "bos.project.yaml",
        "config/bos.profile.yaml",
        ".bos/config/profile.yaml",
        "config/blueprint.lock.yaml",
        "config/screenshots.plan.yaml",
        ".bos/plan/blueprint.yaml",
        ".bos/secrets/signing.env",
        ".bos/config/signing.env",
        "config/toolchain.lock.yaml"
    ]

    return candidates.contains { candidate in
        fm.fileExists(atPath: directory.appending(path: candidate).path(percentEncoded: false))
    }
}

private func discoverProjectRoot(startingAt start: URL) -> URL {
    let fm = FileManager.default
    var current = start.standardizedFileURL
    var isDirectory: ObjCBool = false
    if fm.fileExists(atPath: current.path(percentEncoded: false), isDirectory: &isDirectory), !isDirectory.boolValue {
        current = current.deletingLastPathComponent()
    }

    while true {
        if hasProjectRootMarker(at: current) {
            return current
        }

        let parent = current.deletingLastPathComponent().standardizedFileURL
        if parent.path(percentEncoded: false) == current.path(percentEncoded: false) {
            return start.standardizedFileURL
        }
        current = parent
    }
}

func resolveProjectRoot(from parsed: ParsedOptions) -> URL {
    let requested = resolvePath(parsed.values["--project-root"] ?? ".", base: currentWorkingDirectoryURL())
    return discoverProjectRoot(startingAt: requested)
}

@discardableResult
private func migrateLegacyPathIfNeeded(
    canonical: URL,
    legacy: URL,
    label: String
) -> URL? {
    let fm = FileManager.default
    let canonicalPath = canonical.path(percentEncoded: false)
    let legacyPath = legacy.path(percentEncoded: false)
    let hasCanonical = fm.fileExists(atPath: canonicalPath)
    let hasLegacy = fm.fileExists(atPath: legacyPath)

    if hasCanonical {
        return canonical
    }
    guard hasLegacy else {
        return nil
    }

    do {
        try fm.createDirectory(at: canonical.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.copyItem(at: legacy, to: canonical)
        fputs("note: migrated legacy \(label) from \(legacyPath) to \(canonicalPath)\n", stderr)
        return canonical
    } catch {
        fputs("warning: failed to migrate legacy \(label) from \(legacyPath) to \(canonicalPath): \(error)\n", stderr)
        return legacy
    }
}

func defaultProfilePath(projectRoot: URL) -> URL {
    pathRegistry(projectRoot: projectRoot).profilePath
}

func legacyProfilePath(projectRoot: URL) -> URL {
    pathRegistry(projectRoot: projectRoot).legacyProfilePath
}

func resolveProfilePathOrFail(
    raw: String?,
    projectRoot: URL,
    command: BosCommand,
    format: OutputFormat
) -> URL {
    if let raw {
        return resolvePath(raw, base: projectRoot)
    }

    let registry = pathRegistry(projectRoot: projectRoot)
    if let migrated = migrateLegacyPathIfNeeded(
        canonical: registry.profilePath,
        legacy: registry.legacyProfilePath,
        label: "profile"
    ) {
        return migrated
    }
    if FileManager.default.fileExists(atPath: registry.profilePath.path(percentEncoded: false)) {
        return registry.profilePath
    }
    if FileManager.default.fileExists(atPath: registry.legacyProfilePath.path(percentEncoded: false)) {
        return registry.legacyProfilePath
    }

    do {
        try writeTextFile(defaultProfileTemplate(), to: registry.profilePath)
        fputs("note: profile not found — created default at \(registry.profilePath.path(percentEncoded: false))\n", stderr)
    } catch {
        fail(message: "could not create default profile: \(error)", command: command, format: format)
    }
    return registry.profilePath
}

func defaultBlueprintPath(projectRoot: URL) -> URL {
    pathRegistry(projectRoot: projectRoot).blueprintLockPath
}

func legacyBlueprintPath(projectRoot: URL) -> URL {
    pathRegistry(projectRoot: projectRoot).legacyBlueprintPath
}

func resolveOptionalBlueprintPath(raw: String?, projectRoot: URL) -> URL? {
    if let raw {
        return resolvePath(raw, base: projectRoot)
    }

    let registry = pathRegistry(projectRoot: projectRoot)
    if let migrated = migrateLegacyPathIfNeeded(
        canonical: registry.blueprintLockPath,
        legacy: registry.legacyBlueprintPath,
        label: "blueprint"
    ) {
        return migrated
    }
    if FileManager.default.fileExists(atPath: registry.blueprintLockPath.path(percentEncoded: false)) {
        return registry.blueprintLockPath
    }
    if FileManager.default.fileExists(atPath: registry.legacyBlueprintPath.path(percentEncoded: false)) {
        return registry.legacyBlueprintPath
    }
    return nil
}

func resolveBlueprintPathOrFail(
    raw: String?,
    projectRoot: URL,
    command: BosCommand,
    format: OutputFormat
) -> URL {
    if let path = resolveOptionalBlueprintPath(raw: raw, projectRoot: projectRoot) {
        return path
    }

    let expected = defaultBlueprintPath(projectRoot: projectRoot).path(percentEncoded: false)
    fail(
        message: "blueprint not found. pass `--blueprint` or create \(expected)",
        command: command,
        format: format
    )
}

func resolveToolchainLockPath(projectRoot: URL) -> URL? {
    let fm = FileManager.default
    let preferred = preferredToolchainLockPath(projectRoot: projectRoot)
    return fm.fileExists(atPath: preferred.path(percentEncoded: false)) ? preferred : nil
}

func defaultScreenshotsPlanPath(projectRoot: URL) -> URL {
    pathRegistry(projectRoot: projectRoot).screenshotsPlanPath
}

func defaultReleasePolicyPath(projectRoot: URL) -> URL {
    pathRegistry(projectRoot: projectRoot).releasePolicyPath
}

func resolveOptionalReleasePolicyPath(raw: String?, projectRoot: URL) -> URL? {
    if let raw {
        return resolvePath(raw, base: projectRoot)
    }

    let path = defaultReleasePolicyPath(projectRoot: projectRoot)
    if FileManager.default.fileExists(atPath: path.path(percentEncoded: false)) {
        return path
    }
    return nil
}

func resolveScreenshotsPlanPathOrFail(
    raw: String?,
    projectRoot: URL,
    command: BosCommand,
    format: OutputFormat
) -> URL {
    if let raw {
        return resolvePath(raw, base: projectRoot)
    }

    let path = defaultScreenshotsPlanPath(projectRoot: projectRoot)
    if FileManager.default.fileExists(atPath: path.path(percentEncoded: false)) {
        return path
    }

    fail(
        message: "screenshots plan not found. pass `--plan` or create \(path.path(percentEncoded: false))",
        command: command,
        format: format
    )
}

func preferredToolchainLockPath(projectRoot: URL) -> URL {
    projectRoot.appending(path: "config/toolchain.lock.yaml")
}

func defaultSigningEnvironmentPath(projectRoot: URL) -> URL {
    pathRegistry(projectRoot: projectRoot).signingEnvPath
}

func existingSigningEnvironmentPath(projectRoot: URL) -> URL? {
    let registry = pathRegistry(projectRoot: projectRoot)
    let fm = FileManager.default
    if let migrated = migrateLegacyPathIfNeeded(
        canonical: registry.signingEnvPath,
        legacy: registry.legacySigningEnvPath,
        label: "signing env"
    ) {
        return migrated
    }
    if fm.fileExists(atPath: registry.signingEnvPath.path(percentEncoded: false)) {
        return registry.signingEnvPath
    }
    if fm.fileExists(atPath: registry.legacySigningEnvPath.path(percentEncoded: false)) {
        return registry.legacySigningEnvPath
    }
    return nil
}
