# Implementation Plan

## Goal
사용자 환경 차이(도구 버전/설치 유무)를 허용하면서도 `bos`의 동작 결과를 단순하고 예측 가능하게 유지한다.  
핵심은 `doctor`를 "정확한 실패 이유 + 즉시 실행 가능한 조치" 중심으로 재설계하는 것이다.

## Scope
- `toolchain.lock` 정책 개편 (exact pin -> 호환 범위 + 명령별 요구사항)
- `doctor` 판정 모델 개편 (필수/권장/정보 레벨)
- 미설치 도구 설치 권유 메시지 표준화
- 선택적 자동 설치 진입점(`--install`) 설계
- lock 부재 초기화 경로(`--init-lock`) 설계
- `apply(init)` bootstrap 문서(`AGENTS.md`, `CLAUDE.md`, `Rules/`) 기본 복사
- `Tuist/Package.swift` 기본 의존성 세트 표준화

## Constraints
- 기존 `.bos/{config|plan|state}` 경로 정책 유지
- 기존 명령 계약(`plan/apply/verify/release-init`)은 후방 호환 우선
- 자동 설치는 명시적 opt-in 플래그 없이는 절대 수행하지 않음
- 네트워크/패키지 매니저 실패 시에도 오류 원인과 수동 명령을 반드시 출력
- macOS 우선 지원, 타 OS는 "가이드 출력만"부터 시작

## Data Model
- `ToolchainPolicyV2`
  - `tools`: `swift`, `tuist`, `fastlane`
  - `versionRule`: exact 또는 semver-range
  - `requiredFor`: `[doctor, plan, apply, verify, release-init]`
  - `installHints`: 패키지 매니저별 권장 명령 목록
- `DoctorFinding`
  - `tool`, `status(installed|missing|incompatible)`, `severity(required|recommended|info)`, `action`
- `DoctorReportV2`
  - `summary`, `blockingItems`, `recommendedItems`, `installCommands`

## Approach Options (3-way)
1. Option A - Exact Lock 고수 (현재 방식 유지)
- 장점: 재현성 최고, 판정 단순
- 단점: 사용자 환경 다양성에 취약, 실제로 동작 가능한 환경도 불필요하게 실패

2. Option B - Lock 제거, 설치 여부만 검사
- 장점: 온보딩 마찰 최소
- 단점: 호환성 경계가 사라져 실패가 뒤 단계(`verify/release`)로 지연

3. Option C - 호환 범위 Lock + 명령별 요구사항 (권고)
- 장점: 단순/명확/정확성 균형.  
  `plan/apply`는 완화, `verify/release-init`는 필요한 항목만 엄격 적용 가능
- 단점: 정책 모델/출력 포맷이 약간 복잡해짐

## Decision
`Option C`를 채택한다.  
`lock`은 유지하되 "기계 고정값"이 아니라 "호환 정책"으로 바꾸고, `doctor`는 블로킹 조건을 명령 단위로 분리한다.

## Priority Matrix
- Urgent + Important:
  - `doctor` 블로킹 조건 재정의 (`requiredFor`)
  - lock schema v2 + v1 호환 파서
- Important + Not Urgent:
  - 설치 가이드 메시지 표준화
  - 자동 설치(`--install`) 안전장치
- Urgent + Less Important:
  - lock 미존재 시 초기화 UX (`--init-lock`)
- Less Important:
  - 다중 패키지 매니저 고급 지원(asdf/mise 세부 옵션)

## Critical Path
1. lock 정책 모델(v2) 정의 및 역호환 파서 도입
2. `doctor` 판정 엔진을 명령별 필수 도구 매트릭스로 전환
3. 설치 권유 메시지/명령 자동 제시
4. 선택적 자동 설치 + lock 초기화 흐름 도입
5. Aether 실검증으로 회귀 확인

## Decision Gates
1. Gate-A (정책 모델): v1 lock 입력도 동일하게 해석되며 기존 프로젝트 깨지지 않음
2. Gate-B (판정 정확도): `swift 6.2` + `fastlane 미설치` 환경에서 `verify` 가능/`release-init` 준비 필요를 분리 표시
3. Gate-C (조치 가능성): 누락 도구마다 설치 명령이 OS/매니저 기준으로 자동 제시
4. Gate-D (운영 안정성): Aether E2E에서 `plan -> apply -> verify` 성공, `doctor` 메시지 일관성 확보

## Execution Phases
1. Phase 1 - Policy Model Migration (`ENV-001`, `ENV-002`)
2. Phase 2 - Doctor UX and Guidance (`ENV-003`, `ENV-004`)
3. Phase 3 - Assisted Setup (`ENV-005`, `ENV-006`)
4. Phase 4 - Compatibility and Re-validation (`ENV-007`)

## Verification Strategy
1. `ENV-001`: v1/v2 lock 파싱 단위 테스트 추가 (역호환 보장)
2. `ENV-002`: 명령별 필수 도구 매트릭스 테스트 (`plan/apply/verify/release-init`)
3. `ENV-003`: doctor 출력 스냅샷 테스트 (severity/action 필드 검증)
4. `ENV-004`: 도구 누락 케이스별 설치 명령 제안 테스트
5. `ENV-005`: `--install` 플래그 미사용 시 설치 동작 없음 검증
6. `ENV-006`: `--init-lock`가 `.bos/config/toolchain.lock.yaml` 생성 검증
7. `ENV-007`: Aether 재실행 검증 (`doctor`, `plan`, `apply`, `verify`) + 문서 계약 검증

## Risk/Rollback
- Risk: 호환 범위 규칙이 과도하게 느슨해져 실제 실패를 놓칠 수 있음
  - Rollback: `--strict` 모드로 exact 매칭 강제, 기본 정책을 점진 완화 방식으로 제한
- Risk: 자동 설치 기능이 사용자 환경에 부작용을 줄 수 있음
  - Rollback: 기본값 비활성 유지 + `--install --yes` 이중 확인 유지
- Risk: lock v2 전환 시 기존 lock 해석 불일치
  - Rollback: v1 디코더 유지, 저장은 v2 선택 플래그 기반으로 점진 전환
