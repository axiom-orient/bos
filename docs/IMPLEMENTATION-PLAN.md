# Implementation Plan: 실구현 우선 프로젝트 완성 (2026-03-05)

## Why-How-What
- Why: 사용자가 최소 명령으로 예측 가능한 결과를 얻고, 테스트가 실제 동작을 정확히 증명해야 한다.
- How: 명령 계약을 먼저 고정하고, 테스트를 계약/행동/통합으로 분리한 뒤, 레거시 코드와 문서를 최소화한다.
- What: `verify` 계약 회귀 정리, 테스트 의도 재정렬, 레거시 제거, 최종 출시 게이트 확정.

## StoryBrand 7 (요약)
| 항목 | 내용 |
|---|---|
| Character | `bos`를 처음 쓰는 iOS 개발자 |
| Problem | 명령 계약이 불명확하면 테스트가 환경 의존으로 흔들리고 출시 판단이 모호해짐 |
| Guide | `bos` 코어팀(명령 계약 + 테스트 기준 제공) |
| Plan | 계약 고정 → 테스트 분리/정밀화 → 레거시 제거 → 출시 게이트 통과 |
| CTA | 로컬에서 재현 가능한 증거 기반으로 출시 여부 결정 |
| Success | “무엇이 실패했고 왜 실패했는지”가 즉시 보이는 최소 인터페이스 |
| Failure | 테스트가 실제 의도와 어긋나 장시간 대기/오판정 발생 |

## Goal
- 구현을 우선으로 유지하면서 테스트 의도와 검증 대상을 1:1로 맞춘다.
- CI 확장은 당분간 제외하고, 로컬/통합 테스트만으로 출시 판정을 가능하게 한다.
- 불필요한 문서/레거시 코드를 정리해 운영 기준 문서를 최소 세트로 축소한다.

## Done (완료 정의)
- `verify` 계약이 명시되고 관련 테스트가 deterministic하게 종료된다.
- 테스트가 `계약 검증`과 `실동작 검증`으로 분리되어 각 실패 원인이 즉시 식별된다.
- 레거시 플래그/문서/중복 계획서가 정리되어 기준 문서가 `README`, `docs/PRODUCT_GUIDE.md`, `docs/IMPLEMENTATION-PLAN.md`, `docs/TASKS.md`로 수렴된다.
- `docs/UX_REDESIGN.md`의 유효 내용을 기준 문서로 이관한 뒤 파일을 제거한다.
- 출시 게이트 체크리스트를 모두 만족하는 증거(명령 출력/테스트 로그/파일)가 남는다.
- 출시 직전 `P0/P1`의 `TODO/DOING/BLOCKED`가 0개다.

## Scope
- 포함:
  - CLI 계약 정리(`doctor/plan/apply/verify/release-init`)
  - 테스트 의도 정밀화 및 회귀 방지
  - 문서/레거시 정리 계획 수립 및 실행 큐 정의
  - 출시 게이트 정의
- 제외:
  - 신규 CI 파이프라인 구축/확장
  - 대규모 신기능(`bos init` interactive, `--smoke`, `--run-certs`) 즉시 구현
  - 외부 리포지토리(Aether 등) 동시 리팩터링

## Constraints
- 구현 우선: 문서 변경은 구현/검증 기준을 설명할 때만 수행
- 테스트 정확성 우선: flaky/환경 의존 테스트는 통과보다 원인 제거를 우선
- 호환성: 출시 전 단계에서는 레거시 경로를 유지하지 않고 단일 경로로 정리
- 실행 환경: 현재는 로컬 검증만 요구, CI 확장 금지

## Acceptance Checklist
- [x] 계약 테스트가 외부 툴(`tuist`, `xcodebuild`) 실행 없이 완료된다.
- [x] 행동/통합 테스트는 외부 툴 호출을 허용하되 타임아웃/실패 분류 기준이 있다.
- [x] `docs/IMPLEMENTATION-PLAN.md`와 `docs/TASKS.md`가 실제 코드 상태와 일치한다.
- [x] `docs/UX_REDESIGN.md`가 기준 문서로 병합된 뒤 삭제된다.
- [x] 출시 판단에 필요한 필수 테스트 세트와 명령 로그가 정의된다.

## Out of Scope
- GitHub Actions, 원격 캐시, 병렬 CI 매트릭스 최적화
- 릴리즈 자동화 신기능(`release-init --run-certs`) 구현 자체
- UX 카피/브랜딩 문구 고도화

## Data Model
1. `CommandContractSpec`
- `command`: doctor|plan|apply|verify|release-init
- `intent`: contract|behavior
- `requiredFlags`, `defaultPaths`, `failureExitCode`, `sideEffectsAllowed`

2. `TestIntentMatrix`
- `testCase`: 테스트명
- `intentType`: contract|behavior|integration
- `externalDependency`: none|tuist|xcodebuild|fastlane
- `timeoutBudgetSec`

3. `LegacyInventory`
- `path`: 파일/문서 경로
- `kind`: doc|code|flag|task
- `status`: keep|remove|migrate
- `rationale`, `evidence`

4. `ReleaseGateChecklist`
- `gateId`, `condition`, `evidenceCommand`, `pass/fail`

## Approach Options (3)
1. Option A — 테스트만 패치(최소 수정)
- 장점: 빠름
- 단점: 계약/행동 경계가 계속 불명확하고 재발 가능성 큼

2. Option B — 현재 구현을 유지하고 계약 테스트를 행동 테스트로 전환
- 장점: 코드 변경 최소
- 단점: 계약 검증이 사라져 실패 원인 분리가 약해짐

3. Option C — 계약 명세 고정 + 테스트 계층 분리 + 레거시 정리(권장)
- 장점: 구현과 검증의 대응관계가 명확해지고 출시 판단이 단순해짐
- 단점: 초기 정리 비용이 필요

## Decision
- Option C 채택.
- 이유: “실제 구현이 중요하고 정확히 테스트해야 한다”는 요구를 충족하려면 테스트 의도 분리가 선행되어야 한다.
- `verify`는 실행형 계약을 유지한다(무인자 실행 허용). 대신 계약 테스트에서 `verify`를 제외하고, `verify`는 행동/통합 테스트에서만 검증한다.

## Priority Matrix (Urgent/Important)
- Urgent + Important
  - `verify` 계약 회귀 수정
  - CLI 계약 테스트 deterministic 보장
- Important + Not Urgent
  - 레거시 문서/코드 정리
  - 중기 신기능 백로그 정리(`--smoke`, `--run-certs`)
- Urgent + Less Important
  - 테스트 로그 포맷 미세 개선
- Less Important
  - 문구/표현 리라이팅

## Critical Path
1. `verify` 계약(실패 코드/사이드이펙트 허용 여부) 확정
2. 계약 테스트와 행동 테스트 분리
3. 레거시 항목 제거 목록 확정 및 반영
4. 최소 출시 게이트 실행(핵심 테스트 세트 + 명령 증거)

## Decision Gates
- Gate-1 Contract Freeze
  - `CommandContractSpec`가 문서/테스트에 반영됨
- Gate-2 Test Determinism
  - 계약 테스트가 100% 외부툴 비의존으로 종료됨
- Gate-3 Legacy Cleanup
  - 제거 대상 문서/코드가 반영되고 기준 문서가 일치함
- Gate-4 Release Readiness
  - 필수 테스트 세트 통과 + 실패 시 원인 분류 가능

## Release Gate Checklist (REL-001)
| Gate ID | Condition | Evidence Command | Result |
|---|---|---|---|
| RG-1 | CLI 계약 실패는 parseable JSON + 빠른 종료 | `swift test --filter CoreTests.CLIJsonOutputIntegrationTests` | PASS |
| RG-2 | signing env 누락/형식 오류는 preflight에서 사전 차단 | `swift test --filter 'CoreTests\\.(DoctorEngineIntegrationTests|ReleaseInitEngineIntegrationTests|CLIJsonOutputIntegrationTests)'` | PASS |
| RG-3 | 핵심 엔진 경로(`plan/apply/verify/release-init/doctor`) 무회귀 | `swift test --filter 'CoreTests\\.(ApplyEngineIntegrationTests|PlanEngineIntegrationTests|VerifyEngineIntegrationTests|ReleaseInitEngineIntegrationTests|DoctorEngineIntegrationTests|SchemaValidationTests|ProfilePolicyE2ETests)'` | PASS |
| RG-4 | 동일 P0 테스트 세트 3회 연속 동일 결과 | `swift test --filter 'CoreTests\\.(CLIJsonOutputIntegrationTests|DoctorEngineIntegrationTests|ReleaseInitEngineIntegrationTests|ApplyEngineIntegrationTests|PlanEngineIntegrationTests|VerifyEngineIntegrationTests|SchemaValidationTests|ProfilePolicyE2ETests)'` x3 | PASS |
| RG-5 | 전체 회귀 1회 확인 | `swift test` | PASS |

## Execution Phases
### Phase 1 — 계약 확정 (P0)
- 대상 TASK-ID: `QA-001`, `QA-002`
- 산출물: 명령별 계약표, 테스트 의도 매핑표
- 검증: 계약 테스트 단독 실행 시 외부 툴 프로세스 미생성

### Phase 2 — 테스트 정확도 강화 (P0)
- 대상 TASK-ID: `QA-003`, `QA-004`
- 산출물: 계약/행동/통합 테스트 경계 확정, timeout 정책
- 검증: flaky 없이 로컬 반복 3회 동일 결과

### Phase 3 — 레거시/노이즈 제거 (P1)
- 대상 TASK-ID: `LEG-001`, `LEG-002`, `LEG-003`, `DOC-002`
- 산출물: 제거 목록 반영, 문서 최소화
- 검증: 기준 문서와 코드 상태 불일치 0건

### Phase 4 — 출시 게이트 (P0)
- 대상 TASK-ID: `REL-001`, `REL-002`, `REL-003`
- 산출물: 출시 체크리스트와 증거 로그
- 검증: 게이트 항목 모두 pass, 그리고 `P0/P1` 오픈 태스크 0개

## Verification Strategy
1. 계약 검증
- `doctor/plan/apply/release-init`의 인자 계약 오류가 즉시 `exitCode=2`로 귀결되는지 확인
- `verify`의 계약 실패/행동 실패 분기 기준을 명시하고 테스트로 고정

2. 행동 검증
- 외부 툴 호출이 필요한 테스트는 명시적 timeout과 실패 분류 코드를 검증

3. 통합 검증
- 핵심 시나리오: `doctor -> plan -> apply(init) -> verify -> release-init`에서 산출물 경로와 상태 파일 동기화 확인

4. 반복 검증
- P0 관련 테스트 세트를 연속 3회 실행해 동일 결과 확인

## Risk/Rollback
- Risk: 계약 변경으로 기존 사용자 스크립트가 깨질 수 있음
  - Rollback: 플래그 계약을 이전 동작으로 임시 복원하고 deprecation 경고 추가
- Risk: 테스트 분리 중 중복/누락 발생
  - Rollback: 기존 테스트를 quarantine 태그로 잠시 유지 후 단계적 대체
- Risk: 문서 축소 시 운영 지식 유실
  - Rollback: 제거 전 핵심 정보를 `PRODUCT_GUIDE`로 병합 후 삭제

## Evidence Snapshot (현재 기준)
- 코드 상태: `Sources/BosCLI/main.swift`, `Sources/BosCore/*.swift`
- 테스트 상태:
  - `swift test --filter CoreTests.CLIJsonOutputIntegrationTests` 통과(17 tests, 0 failures)
  - P0 테스트 세트 3회 반복 통과(각 64 tests, 0 failures; 2026-03-05 19:30:59 / 19:32:18 / 19:33:36 KST)
  - `swift test` 전체 통과(65 tests, 0 failures; 2026-03-05 19:38:13 KST 시작)
- 이번 사이클 해결:
  - 런타임 아티팩트 경로의 하드코딩을 제거하고 `<project-root>/.bos/artifacts/<command>/` 단일 경로로 통일
  - signing env 문법 오류를 `doctor`(6) / `release-init`(5) 실패 코드로 분리하고 raw `NSError` 노출을 사용자 메시지로 치환
  - signing env 템플릿 파일 권한을 owner-only(`0600`)로 생성/보정하고 회귀 테스트로 고정
  - signing env 파서가 빈 줄/주석을 포함한 원본 줄번호를 그대로 보고하도록 보정
  - 실행 아티팩트 폴더를 매 실행 초기화하지 않고 최근 N개 보존 정책으로 전환
  - 보존 정책 상한(최근 120개 유지)이 초과 상황에서 정상 prune되는지 단위 테스트로 고정
  - `.gitignore`/README/PRODUCT_GUIDE를 새 아티팩트 정책과 권한 정책에 동기화

## Completed Next Slice (Option-2 정밀화)
- 목표:
  - signing env 파서가 빈 줄/주석을 포함한 원본 줄번호를 정확히 보고하도록 수정
  - `.bos/artifacts/<command>/`에 대해 최근 N개 보존(무제한 증가/즉시 삭제 모두 방지)
- 대상 TASK-ID:
  - `UX-005`, `OPS-001` (DONE)
