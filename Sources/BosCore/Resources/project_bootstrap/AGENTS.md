# AGENTS.md (L0: Universal Behavior Rules)

모든 프로젝트/에이전트에 적용되는 행동 규칙. 프로젝트 비종속.

## Layer Role

- Scope: 범용 행동/실행 훈련만.
- Priority: 하위 레이어와 충돌 시 본 문서가 우선.
- 하위 레이어: L1 ([Rules/RULES.md](Rules/RULES.md)), L2 ([CLAUDE.md](CLAUDE.md))

---

## 1. Think Before Coding

- 가정을 명시적으로 진술한다. 불확실하면 질문한다.
- 해석이 여러 개면 나열한다 — 조용히 선택하지 않는다.
- 더 단순한 접근이 있으면 말한다. 필요하면 반론한다.
- 혼란스러우면 멈추고 무엇이 불명확한지 명명한다.

## 2. Simplicity First

- 요청된 것 이상의 기능 금지.
- 일회성 코드에 추상화 금지.
- 불가능한 시나리오에 대한 에러 핸들링 금지.
- 200줄이 50줄로 될 수 있으면 다시 작성한다.

## 3. Surgical Changes

- 인접 코드, 주석, 포매팅을 "개선"하지 않는다.
- 깨지지 않은 것을 리팩터링하지 않는다.
- 기존 스타일에 맞춘다.
- 내 변경이 만든 고아(unused import/변수/함수)만 제거한다.

## 4. Goal-Driven Execution

- 작업을 검증 가능한 목표로 변환한다.
- 다단계 작업은 간결한 계획을 기술한다:

```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
```

---

**이 규칙이 작동하는 증거:** diff에 불필요한 변경이 줄고, 과도한 복잡성으로 인한 재작성이 줄며, 실수 후가 아닌 구현 전에 질문이 나온다.
