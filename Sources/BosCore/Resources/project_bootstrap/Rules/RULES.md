# Development Rules (L1 Index)

> **Layer**: L1 (프로젝트 비종속 핵심 원칙)
> **Priority**: L0 [AGENTS.md](../AGENTS.md) > L1 (이 문서) > L2 [CLAUDE.md](../CLAUDE.md)

## 핵심 원칙 요약

| 원칙             | 한 줄 설명                        |
| ---------------- | --------------------------------- |
| Production-Grade | 모든 코드는 배포 가능한 완성 상태 |
| Root Cause       | 증상 마스킹 금지, 근본 원인 해결  |
| Evidence-Based   | 측정과 증거 기반 의사결정         |
| KISS / YAGNI     | 최소 복잡도, 필요한 것만 구현     |
| Quality First    | 일정보다 품질 우선                |

상세 규칙은 아래 문서를 참조한다.

---

## L1 Document Map (MECE)

### Engineering

- [L1_universal/Engineering.md](L1_universal/Engineering.md)
- 책임: Production-grade, SOLID, 테스트 전략, Anti-patterns, Conflict Resolution

### Swift

- [L1_universal/Swift.md](L1_universal/Swift.md)
- 책임: Swift 6 Strict Concurrency, 함수형/선언형, 네이밍, Lint

### SwiftUI

- [L1_universal/SwiftUI.md](L1_universal/SwiftUI.md)
- 책임: View 순수성, 상태/바인딩, 컴포지션, 접근성, 성능

### TCA

- [L1_universal/TCA.md](L1_universal/TCA.md)
- 책임: Reducer/State/Action/Effect/Dependencies/Navigation/Testing

### Tuist

- [L1_universal/Tuist.md](L1_universal/Tuist.md)
- 책임: 프로젝트 생성/빌드/테스트 워크플로우, 다중 스킴 순차 실행

---

## 중복 방지 원칙

- 엔지니어링 원칙은 `Engineering.md`만 수정한다.
- Swift 언어 규칙은 `Swift.md`만 수정한다.
- TCA/Dependencies/SQLiteData 운영 규칙은 `TCA.md`만 수정한다.
- 프로젝트 전용 규칙은 [L2_project/](L2_project/) 문서만 수정한다.
- 문서 간 중복 규칙은 허용하지 않고 링크로 참조한다.
