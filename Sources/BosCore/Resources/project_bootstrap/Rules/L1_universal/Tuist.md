# Tuist Build Workflow

> **Layer**: L1 (프로젝트 비종속)
> **Scope**: Tuist 프로젝트 생성, xcodebuild 기반 빌드/테스트, CI 로컬 공통 실행 패턴
> **Out of Scope**: 아키텍처 규칙, TCA/SwiftUI 코딩 규칙

---

## 1. 기본 절차

```bash
# Tuist 실행 파일이 없으면 mise로 실행
mise x tuist@latest -- tuist install
mise x tuist@latest -- tuist generate

# Workspace 기준 빌드
xcodebuild -workspace <Workspace>.xcworkspace -scheme <Scheme> -destination 'generic/platform=iOS Simulator' build
```

---

## 2. 테스트 절차

```bash
# 테스트 빌드
xcodebuild -workspace <Workspace>.xcworkspace -scheme <Scheme> -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build-for-testing

# 테스트 실행
xcodebuild -workspace <Workspace>.xcworkspace -scheme <Scheme> -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test
```

---

## 3. 모듈 스캐폴드 표준 템플릿

```bash
# A. Tuist scaffold 템플릿 확인
mise x tuist@latest -- tuist scaffold list

# B. Tuist scaffold로 모듈 골격 생성
mise x tuist@latest -- tuist scaffold <TemplateName> --path Projects/<Layer>/<ModuleName>

# C. 팀 tma scaffold 사용(설치 환경 기준)
tma --help
tma scaffold <TemplateName> --path Projects/<Layer>/<ModuleName>
```

운영 원칙:

- 수동 폴더/파일 생성보다 `tma` 또는 `tuist scaffold`를 우선한다.
- `tma`를 사용할 수 없는 환경에서는 `tuist scaffold`를 기본 fallback으로 사용한다.

---

## 4. 운영 규칙

- `Project.swift` 변경 후에는 반드시 `tuist generate`를 재실행한다.
- `Tuist.swift`의 `generationOptions.staticSideEffectsWarningTargets`에서 `Sharing`, `Sharing1`, `Sharing2` 제외 설정을 제거하지 않는다.
- 모듈 검증은 가능하면 workspace 기준으로 수행한다.
- 빌드 실패 원인이 환경(예: Metal toolchain)인지 코드 회귀인지 분리해 기록한다.
- 동일 workspace/DerivedData를 공유하는 다중 스킴 빌드/테스트는 기본적으로 순차 실행한다.
- `xargs -P`, 백그라운드 `&` 등 병렬 `xcodebuild` 실행은 `build.db locked`를 유발할 수 있으므로 표준 경로에서 금지한다.

---

## 5. 빌드/테스트 실행 빈도 정책 (Mandatory)

목표: 개발 시간에서 컴파일 대기 시간을 과도하게 소비하지 않도록, 검증을 "단계 게이트"로 제한한다.

- 코딩 중(파일 단위 수정 단계)에는 빌드/테스트를 실행하지 않는다.
- Compose 매크로를 사용할 때 구현 단계는 `execution-mode: final-only`를 기본값으로 둔다.
- 논리 배치 1개 완료 시에만 "영향 스킴 1회 빌드"를 수행한다.
- 작업 완료 직전(또는 커밋 직전)에만 "영향 테스트 1회 + 앱 통합 빌드 1회"를 수행한다.
- 동일 원인/동일 명령 반복은 최대 2회로 제한한다.
- 명령어 자체 문제(경로, destination, 병렬 실행)로 실패한 경우 코드를 바꾸기 전에 명령/환경을 먼저 수정한다.
- CI가 있는 저장소에서는 로컬에서 전체 스킴 반복 검증을 금지하고, 로컬은 스모크 검증만 수행한다.

권장 게이트:

1. `Gate A (Batch)`:
   - 영향 모듈 `build` 1회
2. `Gate B (Final)`:
   - 영향 모듈 `test` 1회
   - 앱 통합 `build` 1회

---

## 6. 프로젝트 표준 명령어

```bash
# 0) 그래프 재생성 (Project.swift 변경 시에만)
tuist generate

# 1) 영향 모듈 스모크 빌드 (Gate A)
xcodebuild -workspace <Workspace>.xcworkspace -scheme <Scheme> -destination 'generic/platform=iOS Simulator' build

# 2) 테스트 대상 확인 (최초 1회 또는 시뮬레이터 변경 시)
xcodebuild -workspace <Workspace>.xcworkspace -scheme <Scheme> -showdestinations

# 3) 영향 모듈 테스트 (Gate B)
xcodebuild -workspace <Workspace>.xcworkspace -scheme <Scheme> -destination 'id=<SIMULATOR_ID>' test

# 4) 앱 통합 빌드 (Gate B)
xcodebuild -workspace <Workspace>.xcworkspace -scheme <AppScheme> -destination 'generic/platform=iOS Simulator' build
```

---

## 7. 다중 스킴 순차 실행 템플릿

```bash
# build-for-testing (순차)
for scheme in <Scheme1> <Scheme2> <Scheme3>; do
  xcodebuild \
    -workspace <Workspace>.xcworkspace \
    -scheme "$scheme" \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
    build-for-testing || break
done

# test (순차)
for scheme in <Scheme1> <Scheme2> <Scheme3>; do
  xcodebuild \
    -workspace <Workspace>.xcworkspace \
    -scheme "$scheme" \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
    test || break
done
```
