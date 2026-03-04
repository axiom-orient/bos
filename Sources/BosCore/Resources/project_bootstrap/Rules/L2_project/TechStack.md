# Technical Stack Guide

버전: 2026-03
대상: 기술 스택, 버전 기준, API 사용 주의사항

## Scope

- 플랫폼/언어 기준 버전
- 주요 라이브러리 목적/적용 범위
- 라이브러리별 API 사용 주의사항

## Out of Scope

- 모듈 경계/타깃 책임 분리 (→ [Architecture.md](Architecture.md))
- TCA 아키텍처 패턴 전체 규칙 (→ L1 [TCA.md](../L1_universal/TCA.md))
- 빌드/스캐폴드 실행 절차 (→ L1 [Tuist.md](../L1_universal/Tuist.md))

---

## 1. Baseline

- Deployment Target: iOS 18.0
- Language: Swift 6.0 (strict concurrency 강제)
- Project Generation: Tuist
- Architecture: TCA + Dependencies
- Persistence: SQLiteData (+ GRDB backend)
- Navigation: swift-navigation
- Collection State: swift-identified-collections

---

## 2. Package Matrix

| Stack                           | Source     | Version Policy (`Tuist/Package.swift`) | Primary Use                                     |
| ------------------------------- | ---------- | -------------------------------------- | ----------------------------------------------- |
| `swift-composable-architecture` | Point-Free | `from: 1.24.1`                         | Feature reducer, navigation, effect             |
| `swift-dependencies`            | Point-Free | `from: 1.11.0`                         | Dependency key/injection, live/test override    |
| `swift-identified-collections`  | Point-Free | `from: 1.1.0`                          |                                                 |
| `sqlite-data`                   | Point-Free | `from: 1.6.0`                          | 로컬 영속 모델(`@Table`)과 query                |
| `swift-navigation`              | Point-Free | `from: 2.4.0`                          | TCA 네비게이션 구성 보조                        |

---

## 3. API Usage Cautions

### 3.1 TCA (`swift-composable-architecture`)

주의사항:

- TCA 1.7+에서는 tree-based navigation 최적화로 `.alert(store:)` 패턴이 deprecated 되었다.
- `AlertState`는 binding 기반으로 연결해야 하며, View의 store는 `@Bindable`이어야 한다.

적용 패턴:

```swift
// Before (deprecated)
.alert(store: store.scope(state: \.$alert, action: \.alert))

// After (binding-based)
.alert($store.scope(state: \.alert, action: \.alert))
```

```swift
private struct RootView: View {
    @Bindable var store: StoreOf<AppReducer>
}
```

현 코드 기준:

- 앱 루트 Feature View에서 binding 기반 `.alert`와 `@Bindable` 적용을 기본으로 유지한다.

추가 규칙:

- 신규 코드에서 `WithViewStore`/`IfLetStore`/`ForEachStore` 레거시 스타일 도입 금지.
- `@Presents`/`StackState`를 우선 사용하고, navigation 변경 원인은 action으로만 발생시킨다.

### 3.2 Dependencies (`swift-dependencies`)

주의사항:

- 외부 세계 접근(시간/UUID/파일/네트워크/DB)은 직접 호출하지 않고 `@Dependency`를 사용한다.
- live 조합은 App bootstrap 단일 지점에서 수행한다.

적용 기준:

- 앱 시작 시 `prepareDependencies` + `AppComposition.configureAll(&values)`에서 live 주입.
- 테스트에서는 `withDependencies`로 override.

### 3.3 SQLiteData (`sqlite-data`)

주의사항:

- Domain Interface에 `@Table` 또는 `import SQLiteData`를 두지 않는다.
- `@Table` Record와 mapper(`init(entity:)`, `entity`)는 Domain/Service Sources에만 둔다.
- query 식에서 타입 추론이 흔들릴 때는 closure 파라미터를 명시한다.

예시:

```swift
// 권장: 명시적 파라미터
.where { cw in cw.id == CloverWallet.singletonID }
```

운영 기준:

- Feature는 DB를 직접 조회/쓰기하지 않고 UseCase query/command를 경유한다.

### 3.4 Navigation (`swift-navigation`)

주의사항:

- TCA navigation 변경은 `action`으로만 발생시킨다.
- 모달/stack 상태는 `@Presents`, `StackState`를 우선 사용한다.

운영 기준:

- View 계층에서 navigation path를 직접 mutate하지 않는다.
- reducer에서 navigation state 변경을 단일 진입점으로 관리한다.

### 3.5 Identified Collections (`swift-identified-collections`)

주의사항:

- 순서가 중요한 state collection은 `[Element]`보다 `IdentifiedArray`를 우선 사용한다.
- `id` 기반 조회/업데이트를 reducer 내부에서 반복할 때 인덱스 탐색 코드를 직접 작성하지 않는다.

운영 기준:

- Feature state에서 선택/삭제/이동이 빈번한 컬렉션은 `IdentifiedArray`를 기본값으로 선택한다.
- Domain entity는 `Identifiable & Sendable` 준수로 컬렉션 연산 안정성을 유지한다.

### 3.6 iOS 18 Runtime APIs

주의사항:

- 최소 타깃이 iOS 18.0이므로 RealityView fallback 분기를 추가하지 않는다.
- Tab 구성은 iOS 18 API(`Tab`, `tabViewCustomization`, `sidebarAdaptable`) 기준으로 유지한다.
- Writing Tools/Image Playground 등 시스템 기능은 화면 레이어에서 조건부 UX로만 적용하고 도메인 정책과 분리한다.

---

## 4. Adoption Checklist (New API/Library)

- `Tuist/Package.swift`에 버전 정책 추가/검증
- 모듈 경계 배치 결정(반드시 [Architecture.md](Architecture.md) 기준)
- TCA/Dependencies 연결 규칙 점검(L1 [TCA.md](../L1_universal/TCA.md))
- `Project.swift` 의존성은 실제 `import` 기준으로 최소 선언
- `tuist generate` + 영향 스킴 `build`로 회귀 확인

---

## 5. Related Documents

- [Architecture.md](Architecture.md)
- [TCA.md](../L1_universal/TCA.md)
- [Tuist.md](../L1_universal/Tuist.md)
- [KNOWHOW.md](../KNOWHOW.md)
