# TCA Ecosystem Guide

> **Layer**: L1 (프로젝트 비종속)
> **Scope**: TCA / Dependencies / Sharing / SQLiteData 연동 운용 규칙
> **Out of Scope**: 모듈 경계/파일 배치 (→ L2 `Architecture.md`), 버전별 API 마이그레이션/주의사항 (→ L2 `TechStack.md`)

---

## 1. Reducer 기본 규칙

- 모든 기능은 `@Reducer`, 상태는 `@ObservableState`.
- `Reduce {}`를 첫 블록으로 두고, child reducer는 `.ifLet/.forEach`로 연결.
- View는 `@Bindable var store: StoreOf<Feature>` 사용.
- 레거시 컨테이너 스타일(`WithViewStore`, `IfLetStore`, `ForEachStore`) 신규 도입 금지.

---

## 2. State 설계

- State는 UI/워크플로우만 보유한다.
- 장기 영속 데이터의 정답 소스는 DB/Shared이며, State는 표현에 필요한 최소값만 가진다.
- 폼 입력/로딩/선택/오류/네비게이션 상태를 명시적으로 분리한다.

---

## 3. Action 분류

- `view`: 사용자 입력/생명주기 이벤트
- `internal`: async 결과/시스템 이벤트
- `delegate`: 상위 Feature 전달 이벤트

이 분류를 기본 템플릿으로 사용한다.

---

## 4. Effect 작성 규칙

- 모든 사이드 이펙트는 `.run` 내부에서 수행한다.
- 취소 가능한 long-running effect는 `CancelID`를 둔다.
- 시간 지연은 `continuousClock` 사용, `Task.sleep` 직접 호출 금지.
- 실패는 `internal(.failed(...))` 형태로 state 전환 경로를 명확히 한다.

---

## 5. Dependencies 규칙

- Reducer/UseCase에서 외부 접근은 `@Dependency`로만 수행.
- 앱 시작 시 `prepareDependencies`에서 live 조합.
- 테스트에서 `withDependencies`로 clock/network/db를 override한다.
- Feature Reducer가 사용하는 dependency 계약 타입은 Domain/Service `Interface` 타깃에 둔다.
- OS/SDK 런타임 구현은 Feature가 아니라 Service `Sources`에서 live로 제공한다.

---

## 6. Navigation 규칙

- sheet/alert/popover/fullScreen: `@Presents`
- push stack: `StackState` / `StackAction`
- 화면 이동 원인은 반드시 action이어야 한다.
- child가 parent navigation state를 직접 수정하지 않는다.

---

## 7. Sharing / SQLiteData 연동 원칙

- Shared: 사용자 설정/전역 런타임 조각 상태
- SQLiteData: 관계형 영속 데이터
- Feature는 DB를 직접 import하지 않고 use case query를 통해 데이터 소비
- 실시간 화면 갱신은 UseCase `observe*` 스트림을 effect로 구독하고 `internal` action으로 state를 갱신한다.
- Record/Mapper 구조 세부 규칙은 프로젝트별 아키텍처 문서를 따른다.
- Tuist `PackageSettings.productTypes`에서 `Sharing`(및 중복 해석 시 `Sharing1`, `Sharing2`)은 반드시 `.staticLibrary`로 고정한다.
- 이유: Apple private framework `Sharing.framework`와 이름 충돌 시 시뮬레이터 테스트가 dyld 단계에서 중단될 수 있다.
- Tuist `generationOptions.staticSideEffectsWarningTargets`에서 `Sharing`, `Sharing1`, `Sharing2`를 `.excluding`으로 유지한다.
- 이유: `ComposableArchitecture`/`SQLiteData`가 `Sharing`을 공통 링크하는 구조상 static side effects 경고는 구조적으로 반복되므로, 경고 노이즈만 제거하고 static 안전 정책은 유지한다.
- 설정 변경 직후에는 `tuist generate` 후 새 `DerivedData` 경로에서 1회 검증 실행한다.
- Apple `Sharing` API를 같은 파일에서 함께 다뤄야 하는 경우 모듈 alias(`import Sharing as SwiftSharing`)를 사용해 의미 충돌을 방지한다.

---

## 8. 테스트 규칙

- Feature 테스트: `TestStore` + dependency override
- Domain/Service 테스트: 테스트 전용 DB 또는 mock interface 사용
- 새 테스트 작성은 Swift Testing 기준(`@Test`, `#expect`)
- 정책상 App/Domain/Shared는 별도 테스트 모듈을 만들지 않는다. 테스트는 Feature/Service 또는 통합 검증 경로에서 수행한다.

---

## 9. 금지 목록

- Reducer에서 `Date()`, `UUID()`, 파일/DB 직접 호출
- View에서 비즈니스 로직 처리
- Legacy TCA view API 신규 도입
- 테스트에서 실서비스 DB/실시간 외부 SDK 접근

---

## 10. Quick Checklist

- 상태는 워크플로우 중심인가?
- effect 취소/실패 경로가 정의되어 있는가?
- 외부 접근이 모두 dependency로 추상화됐는가?
- navigation 변경이 action 기반인가?
- 테스트에서 dependencies override 가능한가?
