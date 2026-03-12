import Foundation
import BosCore

enum ExitCode: Int32 {
    case success = 0
    case contractValidationError = 2
    case driftDetected = 3
    case verifyFailed = 4
    case releaseInitFailed = 5
    case doctorFailed = 6
    case releaseCheckFailed = 7
    case appRegisterFailed = 8
    case releaseRunFailed = 9
}

enum OutputFormat: String {
    case human
    case json
}

enum DoctorScope: String {
    case core
    case all
    case plan
    case apply
    case verify
    case appRegister = "app-register"
    case releaseInit = "release-init"
    case releaseCheck = "release-check"
    case releaseRun = "release-run"

    var commands: [String] {
        switch self {
        case .core:
            return ToolchainLock.coreCommands
        case .all:
            return ToolchainLock.allCommands
        case .plan:
            return [ToolchainLock.commandPlan]
        case .apply:
            return [ToolchainLock.commandApply]
        case .verify:
            return [ToolchainLock.commandVerify]
        case .appRegister:
            return [ToolchainLock.commandAppRegister]
        case .releaseInit:
            return [ToolchainLock.commandReleaseInit]
        case .releaseCheck:
            return [ToolchainLock.commandReleaseCheck]
        case .releaseRun:
            return [ToolchainLock.commandReleaseRun]
        }
    }
}

struct DoctorInstallAttempt: Codable {
    let tool: String
    let command: String
    let status: String
    let exitCode: Int32
    let stderr: String
}

struct DoctorCommandOutput: Codable {
    let command: String
    let status: String
    let exitCode: Int
    let summary: String
    let scope: String
    let findings: [DoctorFinding]
    let installAttempts: [DoctorInstallAttempt]
    let artifacts: [String]
}

struct ReleaseCheckCommandOutput: Codable {
    let command: String
    let status: String
    let exitCode: Int
    let summary: String
    let mode: String
    let failureCode: String?
    let failedStep: String?
    let artifacts: [String]
}

struct ReleaseRunCommandOutput: Codable {
    let command: String
    let status: String
    let exitCode: Int
    let summary: String
    let stage: String
    let failureCode: String?
    let failedStep: String?
    let ipaPath: String?
    let artifacts: [String]
}

struct AppRegisterCommandOutput: Codable {
    let command: String
    let status: String
    let exitCode: Int
    let summary: String
    let appIdentifier: String?
    let appName: String?
    let sku: String?
    let primaryLanguage: String?
    let bundleIdStatus: String?
    let appStatus: String?
    let artifacts: [String]
}

enum BosCommand: String, CaseIterable {
    case doctor
    case plan
    case apply
    case verify
    case appRegister = "app-register"
    case releaseInit = "release-init"
    case releaseCheck = "release-check"
    case releaseRun = "release-run"

    var summary: String {
        switch self {
        case .doctor:
            return "환경/버전/필수 도구 체크"
        case .plan:
            return "PRD -> blueprint 변환"
        case .apply:
            return "scaffold 생성 + 정책 패치 적용"
        case .verify:
            return "tuist/xcodebuild 검증 게이트 실행"
        case .appRegister:
            return "App Store Connect 앱/Bundle ID 등록 + profile SSOT 동기화"
        case .releaseInit:
            return "fastlane 파일/기본 lane 생성"
        case .releaseCheck:
            return "App Store Connect/match live signing 준비 검증"
        case .releaseRun:
            return "IPA build/upload/submit를 한 번에 실행"
        }
    }

    var usage: String {
        switch self {
        case .doctor:
            return "bos doctor [--for core|all|plan|apply|verify|app-register|release-init|release-check|release-run] [--project-root <path>] [--format human|json]"
        case .plan:
            return "bos plan (--prd <path> | --plan-dir <path>) [--profile <path>] [--out <blueprint.yaml>] [--project-root <path>] [--company-name <name>] [--app-name <name>] [--app-identifier <id>] [--apple-team-id <team>] [--primary-language en-US|ko-KR] [--sku <value>] [--format human|json]"
        case .apply:
            return "bos apply [--blueprint <path>] [--app-identifier <id>] [--apple-team-id <team>] [--profile <path>] [--mode init|incremental] [--fix] [--dry-run] [--project-root <path>] [--format human|json]"
        case .verify:
            return "bos verify [--profile <path>] [--project-root <path>] [--format human|json]"
        case .appRegister:
            return "bos app-register [--blueprint <path>] [--profile <path>] [--project-root <path>] [--company-name <name>] [--app-name <name>] [--app-identifier <id>] [--apple-team-id <team>] [--primary-language en-US|ko-KR] [--sku <value>] [--match-git-url <url>] [--format human|json]"
        case .releaseInit:
            return "bos release-init [--blueprint <path>] [--profile <path>] [--project-root <path>] [--format human|json]"
        case .releaseCheck:
            return "bos release-check [--profile <path>] [--project-root <path>] [--mode connectivity|readonly-certs|sync-certs] [--allow-write] [--format human|json]"
        case .releaseRun:
            return "bos release-run [--blueprint <path>] [--profile <path>] [--project-root <path>] [--stage build|beta|release|submit] [--allow-signing-write] [--format human|json]"
        }
    }
}
