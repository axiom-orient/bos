# SwiftUI Guide

> **Layer**: L1 (프로젝트 비종속)
> **Scope**: SwiftUI View 계층 구현 규칙
> **Out of Scope**: 모듈 경계/파일 배치 (→ L2 `Architecture.md`), TCA reducer/effect 규칙 (→ `TCA.md`)

---

## 1. View 책임

- View는 표시와 사용자 입력 전달만 담당한다.
- 비즈니스 규칙은 Reducer/UseCase로 이동한다.
- 공개 View는 `#Preview`를 제공한다.

---

## 2. 상태/바인딩 사용

| 도구           | 용도                 |
| -------------- | -------------------- |
| `@State`       | View 로컬 일시 상태  |
| `@Binding`     | 부모 소유 상태 투영  |
| `@Environment` | 시스템 전역 값       |
| `@Bindable`    | TCA Store projection |

규칙:

- TCA 화면은 `@Bindable var store` 기준.
- `@StateObject`로 앱 상태를 새로 소유하지 않는다.

---

## 3. 컴포지션

- 큰 View는 섹션/행 단위로 분리한다.
- 조건 분기가 길어지면 `@ViewBuilder` 보조 함수로 분해한다.
- 반복 리스트는 기본적으로 `List` 사용.

---

## 4. 접근성

- 의미 있는 텍스트/버튼에는 접근성 라벨을 제공한다.
- 색상만으로 상태를 표현하지 않는다.
- Dynamic Type에서 레이아웃이 깨지지 않도록 기본 검증한다.

---

## 5. 성능

- `body` 재계산 범위를 줄이기 위해 작은 View로 분리한다.
- 무거운 계산은 View 바깥(Reducer/UseCase)에서 완료한다.
- 이미지/리소스 로딩은 캐시 전략을 명시한다.

---

## 6. 금지 목록

- View 내부에서 DB/네트워크 직접 호출
- View 내부에서 도메인 정책 계산
- 전역 상태를 임의 singleton으로 직접 접근
