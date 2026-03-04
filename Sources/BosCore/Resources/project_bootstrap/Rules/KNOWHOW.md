# Project Know-how (Ops Notes)

버전: 2026-03
대상: 구현/빌드 과정에서 반복된 실무 이슈와 해결 팁, 의사결정 로그

## Scope

- 트러블슈팅 메모
- 도구/환경 이슈 대응
- 의사결정 배경 및 시행착오 기록

## Out of Scope

- 강제 아키텍처 규칙 (→ [Architecture.md](L2_project/Architecture.md))
- TCA 표준 규칙 (→ [TCA.md](L1_universal/TCA.md))
- 라이브러리/플랫폼 API 주의사항 (→ [TechStack.md](L2_project/TechStack.md))

---

## 1. Dependencies 초기화

- 대규모 의존성 조합은 `prepareDependencies` 시점에 수행한다.
- Store 생성 시 `withDependencies`는 테스트/미세 override 용도로만 사용한다.

---

## 2. SQLiteData 쿼리 실수 패턴

- 비교는 `.eq(...)` 형태를 우선 사용한다.
- 정렬/필터 체인은 쿼리 객체를 분리해 가독성을 확보한다.
- Swift 6 Sendable 경고가 나면 캡처되는 쿼리/모델 타입을 점검한다.

---

## 3. Tuist/빌드 환경

- `tuist` 미설치 환경에서는 `mise x tuist@latest -- tuist ...`로 실행 가능.
- `Project.swift` 수정 후 빌드 이상 시 먼저 `tuist generate`로 재생성한다.
- 개별 `.xcodeproj` 빌드 실패 시 루트 workspace 빌드로 검증한다.

---

## 4. 알려진 환경 이슈

- Metal toolchain 누락 시 `.metal` 컴파일 실패:
- `xcodebuild -downloadComponent MetalToolchain`
- 일부 시뮬레이터에서 `xctest` 부트스트랩 크래시가 재현될 수 있으므로,
  `build-for-testing` 통과 여부와 런타임 로그를 분리해 기록한다.

---

## 5. `build.db locked` 대응

- 증상: `xcodebuild: error: unable to attach DB: error: accessing build database ".../XCBuildData/build.db": database is locked`
- 1차 조치: 동일 시점 병렬 `xcodebuild`를 중단하고 스킴 검증을 순차 실행으로 전환한다.
- 2차 조치: 남아 있는 `xcodebuild`/`XCTest` 프로세스 종료 후 재시도한다.
- 3차 조치: 잠금이 지속되면 `DerivedData`를 정리하고 `tuist generate` 후 재빌드한다.
- 재발 방지: 다중 스킴 검증 자동화는 `xargs -P` 대신 순차 loop 템플릿을 사용한다. 표준 템플릿은 L1 [Tuist.md](L1_universal/Tuist.md) 참조.

---

## 6. TCA Alert API 마이그레이션 노트

- `.alert(store:)` deprecated → `.alert($store.scope(state:action:))` binding 기반으로 전환.
- View의 store 프로퍼티를 `let` → `@Bindable var`로 변경 필요.
- 적용 파일: 앱 루트 Feature View 파일 (프로젝트 구조에 맞게 경로 확인)

---

## 7. 빌드 실패 원인 분류

증상이 동일해도 원인이 다를 수 있으므로, 아래 순서로 먼저 분류한다.

1. 명령어/경로 오류
- 예: workspace 경로 오타 (`Projects/App/<App>.xcworkspace` 등)
- 조치: 실제 루트 workspace(`<App>.xcworkspace`) 기준으로 재실행

2. destination 지정 오류
- 예: `name=iPhone 16`만 지정해 OS 최신 버전으로 매칭되며 실패
- 조치: `-showdestinations`로 ID 확인 후 `-destination 'id=<...>'` 사용

3. 병렬 실행으로 인한 잠금
- 예: `build.db locked`
- 조치: 병렬 `xcodebuild` 중단, 순차 재실행

4. 테스트 의존성 override 누락
- 예: `@Dependency(\.date)` / `@Dependency(\.uuid)` test context 미설정
- 조치: 테스트에서 dependency override 추가 또는 reducer의 의존성 평가 시점 지연

핵심 원칙:
- 같은 실패 명령을 원인 수정 없이 반복하지 않는다.
- 코드 회귀와 실행 환경 오류를 분리 기록한다.
