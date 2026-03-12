import Foundation

func currentWorkingDirectoryURL() -> URL {
    URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
}

func resolvePath(_ raw: String, base: URL) -> URL {
    let expanded = NSString(string: raw).expandingTildeInPath
    if expanded.hasPrefix("/") {
        return URL(fileURLWithPath: expanded)
    }
    return base.appending(path: expanded)
}

func defaultProfilePath(projectRoot: URL) -> URL {
    projectRoot.appending(path: ".bos/config/profile.yaml")
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

    let fallback = defaultProfilePath(projectRoot: projectRoot)
    if FileManager.default.fileExists(atPath: fallback.path(percentEncoded: false)) {
        return fallback
    }

    do {
        try writeTextFile(defaultProfileTemplate(), to: fallback)
        fputs("note: profile not found — created default at \(fallback.path(percentEncoded: false))\n", stderr)
    } catch {
        fail(message: "could not create default profile: \(error)", command: command, format: format)
    }
    return fallback
}

func defaultBlueprintPath(projectRoot: URL) -> URL {
    projectRoot.appending(path: ".bos/plan/blueprint.yaml")
}

func resolveOptionalBlueprintPath(raw: String?, projectRoot: URL) -> URL? {
    if let raw {
        return resolvePath(raw, base: projectRoot)
    }

    let path = defaultBlueprintPath(projectRoot: projectRoot)
    guard FileManager.default.fileExists(atPath: path.path(percentEncoded: false)) else {
        return nil
    }
    return path
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

func preferredToolchainLockPath(projectRoot: URL) -> URL {
    projectRoot.appending(path: "config/toolchain.lock.yaml")
}
