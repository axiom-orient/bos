# Implementation Plan: SSOT App Onboarding + Release Execution (`app-register`, `release-run`) (2026-03-09 KST)

## Goal
- 사용자가 `bundle id`와 최소 app metadata만 확정하면, `bos`가 App Store Connect app registration까지 일관된 계약으로 자동화할 수 있게 한다.
- 프로젝트별 non-secret 운영 정보의 SSOT를 `.bos/config/profile.yaml` 하나로 모은다.
- 기존 `plan -> apply -> verify -> release-init -> release-check` 경로는 유지하되, 앱 등록 책임을 `bos app-register`, 실제 빌드/업로드 책임을 `bos release-run`으로 분리한다.

## Scope
- 포함:
  - 신규 CLI 명령 `bos app-register`
  - 신규 CLI 명령 `bos release-run`
  - `.bos/config/profile.yaml` schema 확장
  - PlanEngine / Blueprint의 metadata source precedence 재정의
  - `appName`, `sku`, `primaryLanguage`, `companyName`, `appIdentifier`, `appleTeamId` 데이터 모델 추가
  - deterministic SKU 생성 규칙 추가
  - `MATCH_GIT_URL`를 secret 파일이 아니라 profile SSOT로 이동
  - `release-init` / `release-check`가 profile + signing env를 합쳐 읽도록 재정렬
  - `release-run`이 `release-init + release-check + tuist + fastlane` pipeline을 소유
  - 기존 repo를 위한 `config/blueprint.yaml` fallback
  - app registration regression tests / docs / disposable live run plan
- 제외:
  - provisioning policy 자체 재설계
  - CI secret distribution
  - multi-app workspace 관리

## Constraints
- 사용자-facing 계약은 `bos`가 소유해야 한다. `fastlane produce`를 public command로 직접 노출하지 않는다.
- secret은 계속 `.bos/config/signing.env`에 남긴다. SSOT 대상은 non-secret 관리 정보만이다.
- 기존 profile/blueprint/state 파일은 additive change로 읽기 호환성을 유지해야 한다.
- `release-init`와 `release-check`의 책임 경계는 유지해야 한다.
- 앱 등록과 signing seed는 같은 흐름에서 다뤄도 되지만, 숨은 write side effect는 허용하지 않는다.
- 기본 onboarding은 최소 입력을 목표로 하되, 법적/운영 식별자 성격의 값은 추측하지 않는다.

## Evidence Trail
- profile SSOT는 구현됐다.
  - 근거: `Sources/BosCore/Schemas.swift`, `Sources/BosCore/OnboardingConfiguration.swift`, `Sources/BosCLI/main.swift`
- PlanEngine은 onboarding metadata precedence를 profile 기준으로 해석한다.
  - 근거: `Sources/BosCore/PlanEngine.swift`, `Tests/CoreTests/PlanEngineIntegrationTests.swift`
- Blueprint release metadata는 `appName`, `sku`, `primaryLanguage`, `companyName`까지 additive 확장됐다.
  - 근거: `Sources/BosCore/Schemas.swift`, `Tests/CoreTests/SchemaValidationTests.swift`
- `app-register`는 App Store Connect native API backend로 구현됐다.
  - 근거: `Sources/BosCore/AppRegistrationEngine.swift`
- `release-run`은 fastlane lanes를 bos-owned CLI surface로 래핑한다.
  - 근거: `Sources/BosCore/ReleaseRunEngine.swift`, `Sources/BosCore/ReleaseInitEngine.swift`, `Tests/CoreTests/ReleaseRunEngineIntegrationTests.swift`
- 실제 live run에서 App Store Connect auth와 `match` repo reachability는 성공했지만, empty repo에서는 `readonly-certs`가 실패했다.
  - 근거: `/tmp/bos-live-release-check-NjEPZU/.bos/artifacts/release-check/release-check-20260309011343.log`
  - 근거: `/tmp/bos-live-release-check-NjEPZU/.bos/artifacts/release-check/release-check-20260309011352.log`
- 실제 live run에서 기존 앱 `com.axient.aether`에 대해 `app-register` idempotent existing-path를 검증했다.
  - 근거: `/tmp/bos-live-app-register-iVfLZ8/.bos/artifacts/app-register/app-register-20260309041242.log`
- fastlane 공식 문서 기준 `produce` / `create_app_online`는 app registration에 `app_identifier`, `app_name`, `sku`, `language`를 요구한다.
  - 근거: [fastlane `create_app_online`](https://docs.fastlane.tools/actions/create_app_online/)
- fastlane 공식 문서 기준 `produce`의 App Store Connect API key 지원은 partial이다.
  - 근거: [fastlane App Store Connect API support table](https://docs.fastlane.tools/app-store-connect-api/)
- Apple 공식 문서 기준 새 앱 생성에는 app name, primary language, bundle ID, SKU가 필요하다.
  - 근거: [Apple App Store Connect Help - Add a new app](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/)

## Approach Comparison
| Option | Summary | Pros | Cons | Decision |
|---|---|---|---|---|
| A | 현재처럼 PRD/CLI flag + 웹 수동 등록 유지 | 구현 범위가 가장 작다 | 사용자 onboarding이 끊기고, bundle id 이후 운영 흐름이 `bos` 밖으로 빠진다 | Reject |
| B | `fastlane produce`를 public command로 그대로 노출 | 빠르게 붙일 수 있다 | fastlane auth/partial API support가 그대로 user contract가 되고, 운영 원칙이 외부 도구에 종속된다 | Reject |
| C | `bos app-register`라는 bos-owned command를 추가하고 backend는 adapter로 숨긴다 | user contract를 단순하게 유지하면서 backend 교체가 가능하다. SSOT/profile 기반 운영 원칙과 가장 잘 맞는다 | 초기 설계 작업이 더 필요하고, backend feasibility spike가 선행돼야 한다 | Select |
| D | `release-init` 또는 `plan`에 app registration까지 섞는다 | 명령 수는 적다 | 문서 생성/코드 생성/외부 시스템 write가 한 명령에 섞여 책임 경계가 깨진다 | Reject |

## Decision Summary
1. user-facing onboarding command는 `bos app-register`로 고정한다.
   - 이유: `plan`/`apply`/`release-init`의 역할을 침범하지 않으면서, 앱 등록 책임을 가장 직관적으로 설명한다.
2. non-secret 운영 SSOT는 `.bos/config/profile.yaml` 하나로 모은다.
   - 포함: `companyName`, `appName`, `appIdentifier`, `appleTeamId`, `primaryLanguage`, `sku`, `matchGitURL`
   - 제외: `ASC_*`, `MATCH_PASSWORD`
3. metadata precedence는 `CLI override > profile.yaml > plan/prd marker > deterministic default`로 정한다.
4. deterministic default는 추측 가능한 값에만 적용한다.
   - `appName`: `projectName` fallback 허용
   - `sku`: `companyName` 우선, 없으면 bundle id prefix seed fallback으로 자동 생성
   - `primaryLanguage`: `en-US` 기본, `ko-KR` 선택 지원
   - `companyName`: 자동 추정 금지, profile 관리값으로 둔다
5. app registration backend는 adapter 뒤에 둔다.
   - 결정: Swift-native App Store Connect HTTP client를 `NativeAppRegistrationProvider`로 채택한다.
   - 이유: `fastlane produce`는 username/session 의존이 남아 있어 public contract와 맞지 않는다.

## Data Model
### Profile SSOT
- 기존 `.bos/config/profile.yaml`를 유지하되 optional section을 추가한다.
- 제안 구조:

```yaml
schemaVersion: 1
name: default
defaults:
  deploymentTarget: "18.0"
  appTargets:
    controlsExtension: false
    uiTests: true
identity:
  companyName: "Axiom Orient"
  appName: "Daycraft"
  appIdentifier: "com.axiomorient.daycraft"
  appleTeamId: "8GT6LT258Y"
release:
  primaryLanguage: "en-US"
  sku: "axiomorient.daycraft.3f1c8a2b"
  matchGitURL: "https://github.com/axiom-orient/AppStoreConnect"
featurePattern:
  sourcesInterface: true
  designFolder: false
rules:
  testingStyle: swift-testing
  forbidPatterns:
    - "@unchecked Sendable"
    - "Date()"
    - "UUID()"
```

### Secret Boundary
- `.bos/config/signing.env`는 아래만 유지한다.
  - `ASC_ISSUER_ID`
  - `ASC_KEY_ID`
  - `ASC_KEY_P8_BASE64`
  - `MATCH_PASSWORD`
- `MATCH_GIT_URL`는 profile의 `release.matchGitURL`로 이동하고, signing env에서는 backward-compatible fallback만 허용한다.

### Blueprint Extension
- `Blueprint.release.fastlane`에 다음 필드를 additive로 추가한다.
  - `appName`
  - `sku`
  - `primaryLanguage`
  - `companyName`
- 기존 `appIdentifier`, `appleTeamId`는 유지한다.
- schemaVersion은 1을 유지하고 optional/additive decode로 호환성을 지킨다.

### Derivation Rules
- `appName`
  - explicit 값 우선
  - 없으면 `project.name`
- `primaryLanguage`
  - explicit 값 우선
  - 없으면 `profile.release.primaryLanguage`
  - 둘 다 없으면 `en-US`
- `sku`
  - explicit 값 우선
  - 없으면 아래 규칙으로 deterministic 생성
    - `companySlug = slug(companyName)`
    - `appSlug = slug(appName)`
    - `hash = sha256(appIdentifier).prefix(8)`
    - 최종값: `companySlug.appSlug.hash`
  - `companyName`이 없으면 자동 생성하지 않고 contract error로 실패

### CLI Contract
- 신규 명령:
  - `bos app-register [--profile <path>] [--project-root <path>] [--app-name <name>] [--app-identifier <id>] [--apple-team-id <team>] [--company-name <name>] [--primary-language <code>] [--sku <value>] [--format human|json]`
- 최소 권장 사용:
  - profile에 team/company/language를 넣고
  - app별로 `appIdentifier`, `appName`만 채운 뒤
  - `bos app-register`
- 출력 payload:
  - `command`
  - `status`
  - `exitCode`
  - `summary`
  - `appIdentifier`
  - `appName`
  - `sku`
  - `primaryLanguage`
  - `artifacts`

### Backend Adapter
- 내부 protocol:
  - `AppRegistrationProviding`
- 후보 구현:
  - `NativeAppRegistrationProvider`
- user contract는 provider 종류를 노출하지 않는다.
- 현재 선택:
  - `NativeAppRegistrationProvider`를 기본 구현으로 채택
  - `fastlane produce` adapter는 구현하지 않음

## Priority Matrix
| Quadrant | Items |
|---|---|
| Urgent + Important | profile SSOT schema, PlanEngine precedence, `app-register` command contract, backend feasibility gate |
| Important + Not Urgent | `MATCH_GIT_URL` migration, docs refresh, live disposable bundle-id runbook |
| Urgent + Not Important | 없음. onboarding을 release-init에 억지로 섞는 우회는 배제 |
| Later | multi-language expansion beyond `en-US`/`ko-KR`, multi-app management, CI onboarding pipeline |

## Critical Path
1. SSOT schema와 precedence를 먼저 고정한다.
2. plan/blueprint 데이터 모델을 확장한다.
3. app registration backend feasibility를 결정한다.
4. `bos app-register` command를 구현한다.
5. release-init / release-check가 profile SSOT를 읽도록 연결한다.
6. regression tests와 disposable live registration으로 계약을 검증한다.

## Decision Gates
| Gate ID | Question | Decision Rule | Owner |
|---|---|---|---|
| DG-1 | non-secret SSOT를 어디에 둘 것인가? | `.bos/config/profile.yaml` 하나로 통일하고 secret은 signing env에 남긴다 | Maintainer |
| DG-2 | app registration backend를 무엇으로 시작할 것인가? | 결정 완료. Swift-native App Store Connect API backend를 채택 | Maintainer |
| DG-3 | 어떤 값까지 자동 생성할 것인가? | `appName`, `primaryLanguage`, `sku`만 deterministic/default 허용, `companyName`은 자동 추정 금지 | Maintainer |
| DG-4 | `MATCH_GIT_URL`를 어디에 둘 것인가? | profile SSOT로 이동하고 signing env fallback을 한 버전 유지 | Maintainer |

## Execution Phases
### Phase 1. SSOT Schema and Compatibility
- 대상 TASK-ID: `CFG-010`, `CFG-011`
- 산출물:
  - `Profile` optional section 추가
  - default profile template 확장
  - `MATCH_GIT_URL` migration rule 정의
- verification:
  - 기존 profile 없이도 default 생성
  - 기존 schemaVersion 1 profile이 그대로 decode
  - new optional fields가 없어도 동작

### Phase 2. Plan / Blueprint Metadata Expansion
- 대상 TASK-ID: `PLAN-010`, `PLAN-011`
- 산출물:
  - `PlanEngine` precedence 재정의
  - PRD marker 추가: `Company Name`, `App Name`, `Primary Language`, `SKU`
  - Blueprint release metadata additive 확장
- verification:
  - `App Identifier`, `Apple Team ID`가 profile에 있으면 PRD에서 빠져도 blueprint 생성
  - explicit PRD/CLI 값이 profile보다 우선

### Phase 3. App Registration Command
- 대상 TASK-ID: `APP-010`, `APP-011`
- 산출물:
  - `bos app-register`
  - metadata validation / deterministic SKU generation
  - backend adapter + one implementation
- verification:
  - command JSON contract
  - missing company/appIdentifier/appName contract errors
  - generated SKU determinism
  - safe live `existing/existing` run

### Phase 4. Release Flow Alignment
- 대상 TASK-ID: `REL-010`
- 산출물:
  - `release-init` / `release-check`가 profile.release metadata를 병합해서 사용
  - `Matchfile` generation이 profile `matchGitURL`를 사용
  - signing env는 secret-only로 축소
- verification:
  - existing signing flow regression 없음
  - profile only path와 legacy signing env fallback path 모두 테스트

### Phase 5. QA / Docs / Live Validation
- 대상 TASK-ID: `QA-010`, `DOC-010`, `REL-011`
- 산출물:
  - integration tests
  - README / PRODUCT_GUIDE / TESTING_GUIDE 갱신
  - disposable bundle id live run 기록
- verification:
  - `swift test`
  - `swift build -c release`
  - 실제 temp workspace에서 `plan -> apply -> app-register -> release-init -> release-check`

## Verification Strategy
1. Schema / precedence regression
- 목적: profile SSOT와 legacy inputs가 함께 유지되는지 확인
- 예상 명령:
  - `swift test --filter SchemaValidationTests`
  - `swift test --filter PlanEngineIntegrationTests`

2. Command contract regression
- 목적: `app-register` parse, JSON payload, derivation, error taxonomy 고정
- 예상 명령:
  - `swift test --filter CLIJsonOutputIntegrationTests`
  - `swift test --filter AppRegistrationIntegrationTests`

3. Release alignment regression
- 목적: `release-init` / `release-check`가 new SSOT를 읽고 legacy fallback도 깨지지 않는지 확인
- 예상 명령:
  - `swift test --filter ReleaseInitEngineIntegrationTests`
  - `swift test --filter ReleaseCheckEngineIntegrationTests`

4. Disposable live validation
- 목적: idempotent existing-path와 first writable seed를 분리해 검증한다.
- 실제로 완료한 시나리오:
  - temp workspace 준비
  - 기존 앱 `com.axient.aether`로 `bos app-register --format json`
  - 결과: `bundleIdStatus=existing`, `appStatus=existing`
- 남은 시나리오:
  - disposable or real target app 준비
  - `bos plan`
  - `bos apply --mode init`
  - `bos app-register`
  - `bos release-init`
  - `bos release-check --mode sync-certs --allow-write`

## Current Status
- `release-check` 기반 release readiness gate는 이미 구현 완료 상태다.
- onboarding SSOT, plan precedence, `app-register`, release alignment, docs, automated regression은 구현 완료 상태다.
- live evidence 기준으로는 App Store Connect auth, `match` repo reachability, `app-register` existing-path까지 확인됐다.
- 남은 external write gate는 first signing seed(`release-check --mode sync-certs --allow-write`)뿐이다.

## Risk/Rollback
- Risk: App Store Connect API role/권한 차이 때문에 live create path가 계정마다 다를 수 있다.
  - Mitigation: safe existing-path 검증과 writable seed 검증을 분리한다.
- Risk: profile에 onboarding metadata를 넣으면서 scope가 과도하게 커질 수 있다.
  - Mitigation: MVP는 app registration에 필요한 최소 필드만 추가한다.
- Risk: `MATCH_GIT_URL` 이동이 기존 release users를 깨뜨릴 수 있다.
  - Mitigation: 한 버전 동안 signing env fallback을 유지한다.
- Risk: deterministic SKU 규칙이 운영자가 기대한 naming과 다를 수 있다.
  - Mitigation: explicit `sku` override를 허용하고 auto-generated value를 profile에 backfill한다.
- Rollback:
  - `bos app-register`는 additive command이므로 문제가 생기면 command를 숨기거나 backend만 교체할 수 있다.
  - profile optional field는 제거하지 않고 무시해도 기존 `plan/apply/release-*` 경로는 유지된다.
