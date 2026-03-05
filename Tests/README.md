# Tests Overview

`bos` 테스트는 "iOS 초기 셋업 자동화 CLI가 안전하게 반복 실행 가능한가"를 검증한다.
핵심은 기능 개발이 아니라 `plan/apply/verify/release-init/doctor`의 계약(입력/출력/상태 동기화) 보장이다.

## User Scenario Matrix

| Scenario ID | 사용자 시나리오 | 핵심 유스케이스 | 검증 파일 |
|---|---|---|---|
| US-01 | 기획 문서에서 blueprint 생성 | `REQ/SCR/Entity` 추출, 누락 하드 실패 | [PlanEngineIntegrationTests.swift](./CoreTests/PlanEngineIntegrationTests.swift) |
| US-02 | 초기 프로젝트 생성 | Tuist/TMA 기반 생성물, 멱등성(기존 파일 보존), PascalCase 유지 | [ApplyEngineIntegrationTests.swift](./CoreTests/ApplyEngineIntegrationTests.swift) |
| US-03 | 재실행 시 드리프트 통제 | managed block만 복구, 외부 변경은 hard fail | [ApplyEngineIntegrationTests.swift](./CoreTests/ApplyEngineIntegrationTests.swift) |
| US-04 | 검증 파이프라인 수행 | 명령 순서, 실패 분류, 산출물 정리, state summary(success/failure) | [VerifyEngineIntegrationTests.swift](./CoreTests/VerifyEngineIntegrationTests.swift) |
| US-05 | 툴체인 사전 점검 | lock 파싱, mismatch 보고 형식 | [DoctorEngineIntegrationTests.swift](./CoreTests/DoctorEngineIntegrationTests.swift) |
| US-06 | 릴리즈 초기화 | fastlane 파일 생성, 환경값 검증, state summary(success/failure) | [ReleaseInitEngineIntegrationTests.swift](./CoreTests/ReleaseInitEngineIntegrationTests.swift) |
| US-07 | CLI 계약 안정성 | JSON 에러 포맷, Option2 입력 정책(`.bos/config/profile.yaml`) | [CLIJsonOutputIntegrationTests.swift](./CoreTests/CLIJsonOutputIntegrationTests.swift) |
| US-08 | 스키마 계약 강제 | unknown key 거부, 유효 payload 허용 | [SchemaValidationTests.swift](./CoreTests/SchemaValidationTests.swift) |
| US-09 | 기본 profile 정책 회귀 방지 | fixture profile로 apply+verify 경로 보장 | [ProfilePolicyE2ETests.swift](./CoreTests/ProfilePolicyE2ETests.swift), [daycraft.yaml](./Fixtures/daycraft.yaml) |

## File Intent (One-by-One)

| Test File | 의도 요약 | 필요한 이유 | 관련 구현 |
|---|---|---|---|
| [ApplyEngineIntegrationTests.swift](./CoreTests/ApplyEngineIntegrationTests.swift) | `apply init/incremental`의 생성/복구/보호 규칙 검증 | 프로젝트 생성기의 안정성 핵심. 재실행 시 파손 방지 | [ApplyEngine.swift](../Sources/BosCore/ApplyEngine.swift) |
| [CLIJsonOutputIntegrationTests.swift](./CoreTests/CLIJsonOutputIntegrationTests.swift) | CLI 경계 테스트를 `contract`(옵션 파싱 실패)와 `behavior`(실행 실패 JSON)로 분리하고 `release-init` env 형식 실패 JSON까지 검증 | 계약 실패와 실행 실패를 혼동하지 않고 원인 분리를 보장 | [main.swift](../Sources/BosCLI/main.swift) |
| [DoctorEngineIntegrationTests.swift](./CoreTests/DoctorEngineIntegrationTests.swift) | 툴체인 lock 비교 결과(success/fail) 검증 | 잘못된 로컬 환경에서 조기 실패 보장 | [DoctorEngine.swift](../Sources/BosCore/DoctorEngine.swift) |
| [PlanEngineIntegrationTests.swift](./CoreTests/PlanEngineIntegrationTests.swift) | 기획 문서 파싱과 blueprint 생성 규칙 검증 | 입력 품질이 전체 생성 결과를 결정 | [PlanEngine.swift](../Sources/BosCore/PlanEngine.swift) |
| [ProfilePolicyE2ETests.swift](./CoreTests/ProfilePolicyE2ETests.swift) | 기본 profile fixture 기반 apply+verify 흐름 회귀 검증 | 정책 파일 변경 시 즉시 회귀 탐지 | [VerifyEngine.swift](../Sources/BosCore/VerifyEngine.swift), [ApplyEngine.swift](../Sources/BosCore/ApplyEngine.swift) |
| [ReleaseInitEngineIntegrationTests.swift](./CoreTests/ReleaseInitEngineIntegrationTests.swift) | fastlane 생성/환경 검증/state 갱신 규칙 검증 | 릴리즈 초기화 실패를 state에 정확히 반영해야 함 | [ReleaseInitEngine.swift](../Sources/BosCore/ReleaseInitEngine.swift) |
| [SchemaValidationTests.swift](./CoreTests/SchemaValidationTests.swift) | 스키마 strict decode(unknown key 거부) 검증 | 입력 계약 drift를 조기 차단 | [Schemas.swift](../Sources/BosCore/Schemas.swift) |
| [VerifyEngineIntegrationTests.swift](./CoreTests/VerifyEngineIntegrationTests.swift) | verify 명령 파이프라인/실패 분류/정리/state 갱신 검증 | build/test 실패 원인 추적성과 후처리 일관성 보장 | [VerifyEngine.swift](../Sources/BosCore/VerifyEngine.swift) |

## Precision Review Result

- 불필요한 테스트 파일: 없음.
- 중복처럼 보이는 영역은 역할이 다르다:
  - `CLIJsonOutputIntegrationTests`는 CLI 경계 계약 검증.
  - `*EngineIntegrationTests`는 엔진 로직 검증.
- 이번 보강:
  - `VerifyEngineIntegrationTests`: 실패 시 `verifySummary`가 `failed`로 갱신되는지 추가 검증.
  - `ReleaseInitEngineIntegrationTests`: 필수 환경값 누락 실패 시 `releaseSummary`가 `failed`로 갱신되는지 추가 검증.
