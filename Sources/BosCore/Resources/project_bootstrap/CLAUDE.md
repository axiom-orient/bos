# CLAUDE.md (L2: Project Absolute Rules)

## Layer Priority

충돌 시 우선순위는 다음 순서로 적용한다.

1. L0: [AGENTS.md](AGENTS.md)
2. L1: [Rules/RULES.md](Rules/RULES.md)
3. L2: `CLAUDE.md` (이 문서)

---

## Absolute Rules

아래 항목은 Project 전 영역에 강제 적용한다.

1. Swift 6 strict concurrency를 준수한다.
   - `@unchecked Sendable` 금지
   - mutable shared state는 `actor`로 격리

2. Interface-first 의존성 규칙을 준수한다.
   - Feature는 Domain/Service의 `Interface`에만 의존
   - App에서만 Domain/Service `Sources`를 조합

3. 외부 세계 접근은 Dependencies를 통해서만 수행한다.
   - `Date()`, `UUID()`, 파일/네트워크/DB 직접 접근 금지
   - Reducer/UseCase는 `@Dependency` 경로만 사용

4. 임시 구현을 금지한다.
   - `TODO`/`FIXME`/stub/임시 분기 금지
   - 기능은 배포 가능한 완성 상태로 제출

5. 테스트는 기본적으로 Swift Testing을 사용한다.
   - 새 테스트는 `@Test`, `#expect` 기준
   - 기존 XCTest는 점진 마이그레이션 대상으로 관리

6. 문서 단일 진실 공급원을 유지한다.
   - 아키텍처 규칙: [Rules/L2_project/Architecture.md](Rules/L2_project/Architecture.md)
   - 기술 스택: [Rules/L2_project/TechStack.md](Rules/L2_project/TechStack.md)
   - 범용 규칙: [Rules/RULES.md](Rules/RULES.md) (L1 인덱스)

7. 파일/모듈 생성은 아키텍처 템플릿 기반으로 수행한다.
   - 새 파일 생성/이동 전 [Architecture.md](Rules/L2_project/Architecture.md) 기준으로 레이어 책임/배치 경계를 먼저 확정한다.
   - 신규 모듈은 수동 디렉터리 생성 대신 `tma` 또는 `tuist scaffold`로 골격을 생성한다.
   - 생성된 모듈은 L1 [TCA.md](Rules/L1_universal/TCA.md) 규칙에 맞춰 reducer/dependency/test 구조를 완성한다.

8. 테스트 모듈 정책을 준수한다.
   - App, Domain, Shared 모듈은 별도 테스트 모듈(`*Tests`)을 생성하지 않는다.
   - 테스트는 Feature/Service 또는 통합 검증 레이어에서 수행한다.

9. 빌드/테스트는 단계 게이트로 실행한다.
   - 파일 단위 수정마다 빌드하지 않는다.
   - `$compose + $implement + $self-verify` 흐름은 기본적으로 `final-only` 모드로 운용한다.
   - 논리 배치 완료 시 영향 스킴 `build` 1회만 수행한다.
   - 작업/커밋 직전 영향 스킴 `test` 1회 + 통합 `build` 1회만 수행한다.
   - 동일 실패 명령 반복은 최대 2회로 제한하고, 경로/destination/병렬 실행 문제를 먼저 제거한다.

---

## Document Map

### L1 범용 규칙 (전체 인덱스: [Rules/RULES.md](Rules/RULES.md))

- [Engineering.md](Rules/L1_universal/Engineering.md): SOLID, 테스트 전략, Anti-patterns
- [Swift.md](Rules/L1_universal/Swift.md): Swift 6 Concurrency, 함수형, 네이밍
- [SwiftUI.md](Rules/L1_universal/SwiftUI.md): View 순수성, 상태/바인딩
- [TCA.md](Rules/L1_universal/TCA.md): Reducer/Effect/Dependencies/Navigation
- [Tuist.md](Rules/L1_universal/Tuist.md): 빌드/테스트 워크플로우

### L2 Project 전용 규칙

- [Architecture.md](Rules/L2_project/Architecture.md): 모듈/레이어 경계, 파일 배치, Record-Mapper 규약
- [TechStack.md](Rules/L2_project/TechStack.md): 패키지 버전, API 사용 주의사항

### Operations

- [KNOWHOW.md](Rules/KNOWHOW.md): 운영 중 발견된 트러블슈팅/의사결정 로그
