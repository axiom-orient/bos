# Engineering Principles

> **Layer**: L1 (프로젝트 비종속 범용 원칙)
> **Scope**: 모든 코드, 모든 설계/구현 의사결정
> **Out of Scope**: 프로젝트별 아키텍처/빌드/테스트 타깃 규칙 (→ `L2_project/*`)

---

## TIER 0: Absolute Imperatives

> 모든 코드, 모든 상황, 예외 없음

### 1. Production-Grade Enforcement

- ✅ 완전한 구현, 적절한 에러 처리, 테스트 커버리지
- ❌ `TODO`, `FIXME`, `temporary`, 미완성 기능, 하드코딩

| Metric               | Target |
| -------------------- | ------ |
| TODO/FIXME count     | 0      |
| Test coverage        | ≥ 80%  |
| Lint errors/warnings | 0      |

### 2. Root Cause Resolution

- ✅ RCA(Root Cause Analysis) → 구조적 해결 → 예방 테스트
- ❌ 증상 마스킹, 임시 패치, 우회 처리

### 3. Evidence-Based Decisions

- ✅ 성능 측정, 코드 메트릭, 구체적 증거
- ❌ 가정, 선호, "보통", "대부분", 미검증 주장

### 4. Completeness and Precision

- ✅ "Needs verification", "Unverified", "Estimate" 명시
- ❌ 모호한 표현, 불확실한 단정, 불명확한 범위

---

## TIER 1: Core Values

> 모든 설계/구현 의사결정

### 1. Single Source of Truth

- ✅ DRY 원칙, 중앙 집중 설정, 공유 유틸리티
- ❌ 중복 로직, 분산 설정, 복붙 코드

### 2. Quality First

- ✅ 필수 코드 리뷰, 자동 테스트, 정적 분석 통과
- ❌ 임시 솔루션, 기술 부채 축적

### 3. Minimal Complexity (KISS / YAGNI)

- ✅ 명확한 요구사항만 구현, 단순한 솔루션 선택
- ❌ 오버엔지니어링, 미래 추정, 불필요한 추상화

| Metric                | Target          |
| --------------------- | --------------- |
| Cyclomatic complexity | < 10 / function |
| Abstraction levels    | ≤ 3 levels      |

### 4. Transparent Communication

- ✅ ADR(Architecture Decision Records), 상세 커밋 메시지
- ❌ 암묵적 가정, 구두만의 소통

---

## TIER 2: Execution Principles

> 일상적 코딩 및 설계 작업

### 1. SOLID Design

- **S**: 클래스/함수는 단일 책임만
- **O**: 확장에 열림, 수정에 닫힘
- **L**: 파생 타입은 기반 타입으로 완전 대체 가능
- **I**: 클라이언트는 사용하지 않는 인터페이스에 의존하지 않음
- **D**: 구체가 아닌 추상에 의존

### 2. Dependency Management

- ✅ 의존성 주입, 인터페이스 기반, 느슨한 결합
- ❌ 하드 의존성, 전역 상태, 강한 결합
- 순환 의존성: 0

### 3. Immutability and State Management

- ✅ 불변 객체, 순수 함수, 명시적 상태 변경
- ❌ 가변 전역 상태, 부수효과 함수
- Domain entity는 불변; factory/builder 메서드로 새 상태 파생

### 4. Security-First Design

- ✅ 입력 검증, 최소 권한, 민감 데이터 분리
- ❌ 미검증 입력, 과도한 권한, 하드코딩된 시크릿

### 5. Explicit Error Handling

- ✅ Result 타입, 명시적 에러 전파, 풍부한 컨텍스트
- ❌ 예외 무시, 암묵적 실패, 불명확한 에러 메시지

---

## TIER 3: Quality Assurance

> 모든 코드 변경

### 1. Test Strategy (Pyramid)

| Level             | Ratio | Target            |
| ----------------- | ----- | ----------------- |
| Unit Tests        | 70%   | 개별 함수/클래스  |
| Integration Tests | 20%   | 모듈 간 상호작용  |
| E2E Tests         | 10%   | 완전한 워크플로우 |

### 2. Test Writing Rules (AAA Pattern)

- **Arrange**: 테스트 데이터/환경 준비
- **Act**: 테스트 대상 동작 실행
- **Assert**: 결과 검증

네이밍: `testTarget_situation_expectedResult`

```swift
func userService_whenValidInput_returnsUser() { }
func userService_whenInvalidInput_throwsValidationError() { }
```

### 3. Continuous Quality Management

- ✅ 모든 PR에 자동 테스트, 코드 품질 게이트
- ❌ 수동 테스트에만 의존, 품질 검증 건너뛰기

---

## TIER 4: Prohibited Practices

| Anti-Pattern          | Alternative                |
| --------------------- | -------------------------- |
| **God Object**        | 단일 책임, 모듈화          |
| **Magic Numbers**     | Named constants, 설정 파일 |
| **Dead Code**         | 정기적 코드 정리           |
| **Arrowhead Code**    | Early return, guard        |
| **Leaky Abstraction** | 적절한 캡슐화              |
| **Shotgun Surgery**   | 높은 응집, 낮은 결합       |

---

## TIER 5: Conflict Resolution

1. **Quality vs Schedule** → **Quality First** — 일정 부족 시 범위를 줄이고 품질을 낮추지 않는다.
2. **Performance vs Readability** → **Readability First** — 측정으로 병목이 확인된 경우에만 최적화.
3. **Simplicity vs Extensibility** → **Simplicity First (YAGNI)** — 검증된 미래 요구가 없으면 현재에 집중.
