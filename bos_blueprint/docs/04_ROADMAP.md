# Roadmap

## Phase 0 — Make current BOS internally consistent

Duration: 1–2 weeks

### Goals
- remove contradictions
- make contracts reviewable
- fix repo hygiene

### Deliverables
- relative markdown links fixed
- profile/blueprint path policy finalized
- Mint/release version source unified
- toolchain lock expanded
- root manifest introduced

## Phase 1 — Harden current narrow path

Duration: 2–4 weeks

### Goals
- split schemas
- stabilize adapters
- improve migrations and artifacts

### Deliverables
- domain-specific schema files
- migration layer old-path -> new-path
- artifact manifest standard
- compatibility matrix CI

## Phase 2 — App Store metadata and screenshots

Duration: 3–5 weeks

### Goals
- own metadata workflow
- own screenshot workflow without reimplementing everything

### Deliverables
- metadata directory contract
- metadata diff/push command family
- screenshot plan schema
- screenshot compose/validate pipeline

## Phase 3 — Device management

Duration: 2–4 weeks

### Goals
- physical device and simulator operations
- developer workflow support beyond release-only scope

### Deliverables
- device inventory model
- register/install/launch/logs commands
- simulator capture matrix support

## Phase 4 — Release system hardening

Duration: 2–4 weeks

### Goals
- resumable release runs
- richer failure taxonomy
- external adapter contract tests

### Deliverables
- resumable run manifests
- rollback/resume guidance
- staged release evidence package

## Phase 5 — Productization

Duration: ongoing

### Goals
- polished install path
- compatibility policy
- examples and demos
- stable public contract

### Deliverables
- versioned docs site
- template repository
- example generated app repo
- release checklist automation
