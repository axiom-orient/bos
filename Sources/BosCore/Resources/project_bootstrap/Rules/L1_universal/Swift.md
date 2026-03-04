# Swift Language Rules

> **Layer**: L1 (프로젝트 비종속)
> **Scope**: Swift 언어/코드 작성 범용 규칙
> **Target**: Swift 6, iOS 18+
> **Out of Scope**: 프로젝트 아키텍처 규칙, 특정 라이브러리 운영 규칙, 빌드 인프라 정책

---

## 1. Swift 6 Strict Concurrency

**원칙**: 데이터 레이스는 런타임이 아닌 컴파일러가 막는다.

### Actor / Sendable

- `@unchecked Sendable` 금지 — 컴파일러 경고 우회는 미래의 버그
- mutable state가 있으면 → `actor` | 없으면 → `struct`
- `class`는 Obj-C 상속, `@objc` 브리지 등 불가피한 경우만
- UI 타입은 `@MainActor` 명시

```swift
// ✅
actor DataStore {
    private var cache: [UUID: Item] = [:]
    func insert(_ item: Item) { cache[item.id] = item }
}

// ❌
class DataStore {
    var cache: [UUID: Item] = [:]  // 데이터 레이스 가능
}
```

### async / await

- 콜백 기반 API 대신 `async/await` 우선
- 구조적 동시성 우선: `async let`, `withTaskGroup`
- 장시간 작업은 `Task` 생성 + 명시적 취소 처리

---

## 2. 함수형 / 선언형

**원칙**: 사이드 이펙트는 경계로 밀어내고, 내부는 순수하게 유지한다.

- **값 타입 우선** — `struct` / `enum` > `class`
- **순수 함수** — 동일 입력 → 동일 출력, 외부 상태 변경 없음
- **`let` 기본값** — `var`는 진짜 필요할 때만
- **고차 함수** — `map / filter / reduce / compactMap` 활용
- **사이드 이펙트 분리** — 네트워크 / DB / 파일 접근은 프로토콜 뒤로

```swift
// ✅ 순수 변환
let activeNames = users.filter(\.isActive).map(\.name)

// ✅ 사이드 이펙트를 경계 프로토콜로 분리
protocol UserRepository: Sendable {
    func fetchActive() async throws -> [User]
}
```

---

## 3. 네이밍

| 대상              | 규칙                             | 예시                                       |
| ----------------- | -------------------------------- | ------------------------------------------ |
| 타입 / 프로토콜   | `UpperCamelCase`                 | `UserEntity`, `SessionUseCase`             |
| 함수 / 변수       | `lowerCamelCase`                 | `fetchActive()`, `isLoading`               |
| Boolean           | `is / has / should / can` 접두사 | `isActive`, `canSubmit`                    |
| 프로토콜 + 구현체 | Protocol / Default + Protocol    | `UserRepository` / `DefaultUserRepository` |

---

## 4. Lint

SwiftLint 설정: `.swiftlint.yml` (루트)

주요 opt-in 규칙:

- `force_unwrapping` — `!` 강제 언래핑 금지
- `implicitly_unwrapped_optional` — 암묵적 옵셔널 경고
- `empty_count` — `count == 0` 대신 `isEmpty` 사용
