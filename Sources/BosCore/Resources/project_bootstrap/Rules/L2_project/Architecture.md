# Modular Architecture

버전: 2026-03
대상: 모듈 구조/경계/파일 배치 규칙

## Scope

- 모듈 경계
- 레이어 의존성
- Domain-Feature-Service 책임 분리
- SQLiteData Record/Mapper 구조

## Out of Scope

- TCA API 사용법 세부 (→ L1 `TCA.md`)
- SwiftUI 컴포넌트 스타일 (→ L1 `SwiftUI.md`)
- Tuist CLI 사용법 (→ L1 `Tuist.md`)

---

## 1. 아키텍처 목표

다음 3가지를 동시에 만족해야 한다.

- 경계 명확성: 레이어 책임이 코드 구조에 그대로 반영된다.
- 교체 가능성: Domain 정책은 인프라 없이 테스트 가능하다.
- 운영 안정성: 저장소/SDK 변경이 Feature에 전파되지 않는다.

---

## 2. 레이어 구성 (MECE)

| Layer    | 책임                                           | 금지               |
| -------- | ---------------------------------------------- | ------------------ |
| App      | 앱 부트스트랩, live 의존성 조합                | 비즈니스 규칙 구현 |
| Features | 화면 상태, 사용자 입력, 내비게이션, 워크플로우 | DB/SDK 직접 접근   |
| Domains  | 엔티티, 값 객체, 정책, 유스케이스 계약/구현    | UI 타입 의존       |
| Services | DB 마이그레이션, 외부 SDK, 시스템 API 브리지   | 도메인 정책 소유   |
| Shared   | 공통 UI/유틸/코어 타입                         | 레이어 우회 의존   |

---

## 3. 의존성 방향

```text
App -> Features -> Domains -> Services -> Shared
```

추가 규칙:

- Feature -> Domain/Service **Interface only**
- Domain Interface -> Foundation/Dependencies only
- Domain Sources -> Domain Interface + SQLiteData/Services
- Service Sources -> Service Interface + 인프라 SDK

---

## 4. 타겟 구조 규약

### 4.1 Domain (2-target)

- `Interface`
- `*Models.swift`, `*UseCase.swift`, 도메인 에러/값 객체
- `Sources`
- `Default*UseCase.swift`, 영속 Record, Mapper

### 4.2 Service (2-target)

- `Interface`
- 외부 시스템 계약(프로토콜, 입력/출력 타입)
- `Sources`
- SDK/DB/OS API live 구현

Service 타깃 의존성 규칙:

- `Interface`는 계약 정의에 필요한 최소 의존만 선언한다(일반적으로 `Foundation`, `Dependencies`).
- `Interface`에 `Core`, `SQLiteData`, `GRDB` 등 인프라 의존을 기본값으로 두지 않는다.
- `Sources`는 실제 `import`한 모듈을 `Project.swift` 의존성에 명시한다(예: `Dependencies`, `GRDB`).
- `liveValue`는 `Sources`에서 제공하고, `Interface`는 `testValue/previewValue` 중심으로 유지한다.

### 4.3 Feature (1-target)

- Reducer, View, Feature Composition
- 읽기/쓰기 모두 `@Dependency` 경유
- `Sources/Dependencies`에 외부 시스템 런타임(예: AVAudioSession, UserDefaults, 네트워크/SDK 브리지) 구현을 두지 않는다.
- 위 런타임 의존성은 Service `Interface/Sources`로 분리하고, Feature는 Service Interface 타입만 소비한다.

### 4.4 Feature 의존성 최소화 (강제)

- 각 Feature `Project.swift`의 `dependencies`는 실제 `Sources/*.swift` import 기준으로 최소화한다.
- 사용하지 않는 Domain/Service/Shared 의존성은 제거한다.
- Feature 간 의존은 합성(예: RootFeature) 목적에 한해 명시한다.

### 4.5 Test Target 정책 (강제)

- App, Domain, Shared 모듈은 별도 `*Tests` 모듈/타겟을 생성하지 않는다.
- 테스트는 Feature/Service 또는 상위 통합 검증 레이어에서 수행한다.

### 4.6 Project.swift 의존성 위생 규칙 (강제)

- 각 타깃의 `dependencies`는 해당 타깃 `buildableFolders` 내부 `import`의 합집합을 기준으로 유지한다.
- 사용 중인 `import`가 없으면 의존성을 추가하지 않는다(선제적/예비 의존 금지).
- App 타깃은 `Sources/Controls`에서 실제로 사용하는 모듈만 직접 의존한다.
- Domain `Interface`는 `Core`/UI/인프라(`SQLiteData`, `GRDB`) 의존을 두지 않는다.
- Shared 모듈은 공통 기반 레이어이며, 실제 사용하지 않는 외부 패키지 의존을 두지 않는다.

---

## 5. SQLiteData 규약 (강제)

### 5.1 Entity vs Record 분리

- Domain Entity: Interface에 위치, 순수 Swift 타입
- Persistence Record: Sources에 위치, `@Table` 선언
- Mapper: Record 내부에 `init(entity:)`, `var entity` 제공

### 5.2 허용 예시

```swift
// Domain Interface
public struct SessionEntity: Identifiable, Equatable, Sendable { ... }

// Domain Sources
@Table("session")
struct SessionRecord { ... }

extension SessionRecord {
  init(entity: SessionEntity) { ... }
  var entity: SessionEntity { ... }
}
```

### 5.3 금지 예시

- Domain Interface에서 `@Table` 선언
- Feature View에서 `@FetchAll/@FetchOne` 직접 사용
- Domain 정책을 Service에 배치

---

## 6. 읽기/쓰기 경로

### 읽기

- Feature -> UseCase query (`list*`, `observe*`) -> Domain Sources -> DB
- Feature state에는 화면에 필요한 표현 데이터만 유지
- 화면에서 조회는 유지하되, Feature가 DB를 직접 조회하지 않는다.
- 실시간 화면은 UseCase의 `observe*` API(예: `AsyncStream`/`AsyncThrowingStream`) 결과를 소비하는 방식을 기본 원칙으로 한다.

### 쓰기

- View Action -> Reducer -> UseCase command -> Domain Sources -> DB
- View에서 DB write 직접 호출 금지

---

## 7. 파일 배치 체크리스트

다음 조건을 모두 만족해야 한다.

- Domain Interface에 `SQLiteData` import가 없다.
- `@Table` 타입은 Domain Sources/Service Sources에만 있다.
- Feature에서 DB query wrapper 사용이 없다.
- Feature에 외부 런타임 클라이언트 구현 파일(`Sources/Dependencies/*.swift`)이 없다.
- Feature `Project.swift` 의존성은 import 사용 범위를 초과하지 않는다.
- UseCase가 Entity를 반환하고 Record는 외부로 노출되지 않는다.
- AppComposition이 live 구현을 단일 지점에서 조합한다.

---

## 8. 리뷰 게이트

PR 승인 전 아래 항목을 확인한다.

- 경계 위반 import 여부 (`rg "import SQLiteData" Projects/Features Projects/Domains/*/Interface`)
- Feature 런타임 누수 여부 (`find Projects/Features -path '*/Sources/Dependencies/*' -type f`)
- Domain Entity/Record 분리 여부
- Feature가 Interface 의존만 유지하는지
- 테스트가 UseCase 단위에서 in-memory DB 주입으로 검증되는지

---

## 9. 경계 리팩터 불변조건

모듈 경계 리팩터 시 아래 조건은 항상 유지한다.

- 사용자 기능 플로우는 리팩터 전/후 동일하게 동작한다.
- 영속 데이터 SSOT는 SQLiteData이며 Feature는 DB를 직접 참조하지 않는다.
- 앱 부트스트랩의 `defaultDatabase` 주입 계약을 변경하지 않는다.

---

## 10. 경계 리팩터 실행 순서 (원자 단위)

대규모 정리 작업은 다음 순서로 수행한다.

1. Domain Interface 순수화

- `@Table`/`import SQLiteData` 제거

2. Domain Sources 영속 분리

- `*PersistenceModels.swift`에 `Record(@Table)+Mapper` 배치

3. Feature 경계 정리

- DB 직접 조회 제거, UseCase query/command 경유로 전환

4. DB 스키마 정합성 반영

- 필요한 migration 버전 추가

---

## 11. 검증 게이트

경계 리팩터 PR은 다음 증거를 함께 제공한다.

- 영향 모듈 workspace `build` 성공
- 영향 모듈 workspace `build-for-testing` 성공
- 런타임 `xctest` 환경 이슈와 코드 회귀를 분리 기록

---

## 12. 모듈 생성 규칙

- 신규 모듈은 수동 폴더/파일 생성보다 `tma` 또는 `tuist scaffold`를 우선 사용한다.
- 생성 직후 본 문서의 레이어 경계와 L1 `TCA.md` 규칙을 동시에 만족하도록 정리한다.
- 생성 후 최소 검증으로 `tuist generate`와 대상 스킴 `build`를 수행한다.

---

## 13. iOS 18 시스템 기능 배치 규칙

| 기능                               | 권장 모듈                             | 이유                                    |
| ---------------------------------- | ------------------------------------- | --------------------------------------- |
| App Intents / Siri / Shortcuts     | `Services/*Interface + *Sources`      | 시스템 API 브리지 책임은 Services       |
| ControlWidget / Widget Extension   | `App` (확장 타깃) + `Services` 의존   | App은 확장 배포/임베드, 로직은 Services |
| Writing Tools                      | `Features/*View`                      | 사용자 입력 UI 행위이므로 Feature 계층  |
| Image Playground UI                | `Features/*View`                      | 화면 기반 조건부 UX, 도메인 정책 아님   |
| Intent에서 사용하는 URL/Route 모델 | `Services/*Interface` 또는 `App Core` | UI 레이어 독립적인 라우팅 계약 데이터   |

규칙:

- Intent/Widget이 비즈니스 쓰기 로직을 직접 소유하지 않는다.
- Intent/Widget은 `deep link` 또는 `UseCase` 경유 호출만 수행한다.
- Feature는 시스템 프레임워크 구현체를 소유하지 않고, 화면 적용 범위만 갖는다.

---

## 14. 관련 문서

- [TCA.md](../L1_universal/TCA.md)
- [TechStack.md](TechStack.md)
- [SwiftUI.md](../L1_universal/SwiftUI.md)
- [Tuist.md](../L1_universal/Tuist.md)
- [KNOWHOW.md](../KNOWHOW.md)
