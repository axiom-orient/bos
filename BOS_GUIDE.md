# bos Guide — A to Z Project Setup Automation

> **bos** = iOS bootstrap CLI. 마크다운 PRD → scaffold → 검증 → 배포 준비까지 자동화.

---

## TL;DR

### 사람용 (Human) — 3단계

```bash
# 1. 환경 체크
bos doctor

# 2. 스캐폴드 생성
bos apply --mode init

# 3. Xcode 프로젝트 생성
tuist install && tuist generate
```

### AI Agent용 — 전체 플로우

```bash
# 1. 환경 체크 (core 도구: swift, tuist)
bos doctor --for core --project-root /path/to/project --format json

# 2. PRD 분석 → blueprint 생성 (plan-dir 방식)
bos plan --plan-dir /path/to/PLAN --project-root /path/to/project --format json

# 3. blueprint 검토 후 apply
bos apply \
  --blueprint /path/to/project/config/blueprint.yaml \
  --profile /path/to/project/.bos/config/profile.yaml \
  --mode init \
  --project-root /path/to/project \
  --format json

# 4. Xcode 프로젝트 생성
cd /path/to/project && tuist install && tuist generate

# 5. 코드 검증
bos verify --project-root /path/to/project --format json

# 6. 릴리즈 준비 (signing 환경 구성 후)
bos doctor --for release-init --project-root /path/to/project --format json
bos release-init --project-root /path/to/project --format json
```

---

## 1. Prerequisites

| 도구 | 최소 버전 | 설치 |
|------|-----------|------|
| Xcode.app | 16.0+ | App Store |
| xcode-select | Xcode.app 가리킴 | `sudo xcode-select -s /Applications/Xcode.app` |
| Swift | 6.0+ | Xcode 내장 |
| Tuist | 4.x | `brew install tuist` 또는 `mise use -g tuist@latest` |
| fastlane | 2.228+ | `brew install fastlane` (release-init만 필요) |

```bash
# xcode-select 확인
xcode-select -p
# → /Applications/Xcode.app/Contents/Developer 이어야 함
# CommandLineTools 가리키면: sudo xcode-select -s /Applications/Xcode.app
```

---

## 2. 새 프로젝트 설정 — 필요한 파일

최소 1개 파일만 있으면 된다:

```
project-root/
└── config/
    └── blueprint.yaml   ← 필수
```

선택:
```
project-root/
└── .bos/
    └── config/
        └── profile.yaml  ← 없으면 default 자동 생성
```

---

## 3. blueprint.yaml — 전체 스키마

```yaml
schemaVersion: 1   # 고정값. 반드시 1.

project:
  name: MyApp                        # PascalCase. App 타겟 이름으로 사용됨.
  bundleIdPrefix: com.myorg          # 역도메인 prefix. appIdentifier 없을 때 fallback 사용.
  deploymentTarget: '18.0'           # iOS 배포 타겟. 따옴표 필수.

requirements:
  reqIds:                            # PRD 요구사항 ID 목록 (REQ-NNN 또는 FR-NNN 형식)
    - REQ-001
    - REQ-002
  screens:                           # 화면 ID 목록 (SCR_NAME 형식)
    - SCR_HOME
    - SCR_SETTINGS

modules:
  app:
    name: MyApp                      # project.name과 동일하게 설정.
  features:                          # Feature 모듈. Root 포함 필수.
    - Root
    - Home
    - Settings
  domains:                           # Domain 모델 모듈 (순수 데이터 레이어)
    - Item
    - User
  services:                          # Service 모듈 (CRUD 조작 레이어)
    - ItemService
    - UserService
  shared:                            # 공유 유틸리티 모듈
    - Core
    - DesignSystem

wiring:
  rootFeature: Root                  # 진입 Feature. features 목록에 반드시 포함되어야 함.
  tabFeatures:                       # 탭바 구성 시 사용 (선택). features 목록에서 선택.
    - Home
    - Settings

release:
  fastlane:
    appIdentifier: com.myorg.myapp   # Apple App Bundle ID. 정확한 값 필수.
    appleTeamId: XXXXXXXXXX          # Apple Developer Team ID (10자 영숫자).
```

### 필드 규칙 요약

| 필드 | 형식 | 유효성 |
|------|------|--------|
| `project.name` | PascalCase | 비어있으면 오류 |
| `project.bundleIdPrefix` | reverse domain | 비어있으면 오류 |
| `project.deploymentTarget` | `'18.0'` 문자열 | 따옴표로 감싸야 함 |
| `modules.features` | PascalCase 목록 | 비어있으면 오류 |
| `wiring.rootFeature` | features 목록 중 하나 | 비어있으면 오류 |
| `release.fastlane.appIdentifier` | reverse domain | 비어있으면 오류 |
| `release.fastlane.appleTeamId` | 10자 영숫자 | 비어있으면 오류 |

---

## 4. profile.yaml — 전체 스키마

없으면 자동으로 `.bos/config/profile.yaml`에 default 생성.

```yaml
schemaVersion: 1
name: default

defaults:
  deploymentTarget: '18.0'          # blueprint.project.deploymentTarget과 일치 권장
  appTargets:
    controlsExtension: false        # WidgetKit Controls Extension 타겟 포함 여부
    uiTests: true                   # UI 테스트 타겟 포함 여부

featurePattern:
  sourcesInterface: true            # Feature 모듈에 Interface/ 서브디렉터리 생성 여부
  designFolder: false               # Feature 모듈에 Design/ 서브디렉터리 생성 여부

rules:
  testingStyle: swift-testing       # swift-testing | xctest
  forbidPatterns:                   # verify 단계에서 금지 패턴 (비어있으면 오류)
    - '@unchecked Sendable'
    - Date()
    - UUID()
```

---

## 5. A to Z 자동화 플로우

```
[Input]             [Command]                    [Output]
─────────────────────────────────────────────────────────
없음            →   bos doctor --for core     →  환경 상태 리포트
PLAN/ 디렉터리  →   bos plan --plan-dir       →  config/blueprint.yaml
blueprint.yaml  →   bos apply --mode init     →  프로젝트 스캐폴드
스캐폴드        →   tuist install && generate →  .xcodeproj + Packages
프로젝트        →   bos verify                →  검증 결과 (exit 0 or 3/4)
signing.env     →   bos release-init          →  Fastfile + lanes
```

### 상세 단계별 가이드

#### Step 1: 환경 체크

```bash
bos doctor --for core
```

- **합격 기준**: swift, tuist 설치됨 + xcode-select → Xcode.app
- **실패 시 조치**:
  - xcode-select CLT 문제: `sudo xcode-select -s /Applications/Xcode.app`
  - tuist 없음: `brew install tuist`
  - swift 없음: Xcode 재설치

#### Step 2: Blueprint 생성

**방법 A: 마크다운 PRD에서 자동 추출**
```bash
bos plan --plan-dir /path/to/PLAN --project-root /path/to/project
```
PlanEngine이 추출하는 패턴:
- 요구사항: `REQ-NNN`, `FR-NNN`
- 화면: `SCR_xxx` 또는 한국어 키워드 (오늘, 서랍, 집중 등)
- 엔티티: `Entity: Name`, `Domain: Name`
- App ID: `App Identifier: com.xxx`
- Team ID: `Apple Team ID: XXXXXXXXXX`

**방법 B: 직접 작성**
`config/blueprint.yaml`을 위 스키마 기준으로 수동 작성.

#### Step 3: 스캐폴드 생성

```bash
# 최초 생성 (idempotent — 이미 있는 파일은 건너뜀)
bos apply --mode init

# 기존 스캐폴드 drift 체크 (변경사항 감지)
bos apply --mode incremental

# drift 자동 수정
bos apply --mode incremental --fix
```

#### Step 4: Xcode 프로젝트 생성

```bash
cd /path/to/project
tuist install           # Package.resolved 설치
tuist generate          # .xcodeproj 생성
```

#### Step 5: 검증

```bash
bos verify
```
- exit 0: 통과
- exit 3: drift 감지 (apply --mode incremental --fix 실행)
- exit 4: verify 실패

#### Step 6: 릴리즈 준비 (선택)

```bash
# signing.env 작성 (자동 생성된 템플릿 확인)
cat .bos/config/signing.env
# ASC_ISSUER_ID=         ← App Store Connect Issuer ID
# ASC_KEY_ID=            ← API Key ID
# ASC_KEY_P8_BASE64=     ← .p8 파일을 base64 인코딩한 값
# MATCH_GIT_URL=         ← match 인증서 저장소 URL
# MATCH_PASSWORD=        ← match 암호화 패스워드

# 환경 체크
bos doctor --for release-init

# Fastlane 파일 생성
bos release-init
```

---

## 6. Command Reference

### bos doctor

```bash
# 기본 (core 범위)
bos doctor

# 특정 범위 체크
bos doctor --for core              # plan, apply, verify 용 (swift, tuist)
bos doctor --for apply             # apply 용만 체크
bos doctor --for release-init      # fastlane + signing-env 포함
bos doctor --for all               # 전체

# JSON 출력 (AI 파싱용)
bos doctor --for core --format json

# 다른 프로젝트 경로
bos doctor --project-root /path/to/project
```

**Exit codes**: 0 = 통과, 6 = 필수 도구 누락/호환 불가

### bos plan

```bash
# plan-dir 방식 (마크다운 디렉터리)
bos plan --plan-dir ./PLAN

# 단일 PRD 파일 방식
bos plan --prd ./PRD.md

# 오버라이드 옵션
bos plan --plan-dir ./PLAN \
  --app-identifier com.myorg.myapp \
  --apple-team-id XXXXXXXXXX

# 출력 경로 지정
bos plan --plan-dir ./PLAN --out ./config/blueprint.yaml

# 전체 옵션
bos plan \
  --plan-dir /path/to/PLAN \
  --app-identifier com.myorg.myapp \
  --apple-team-id XXXXXXXXXX \
  --profile .bos/config/profile.yaml \
  --out config/blueprint.yaml \
  --project-root /path/to/project \
  --format json
```

### bos apply

```bash
# 최초 설정 (기본)
bos apply --mode init

# 전체 옵션 (AI agent용)
bos apply \
  --blueprint config/blueprint.yaml \
  --profile .bos/config/profile.yaml \
  --mode init \
  --project-root /path/to/project \
  --format json

# drift 감지 + 자동 수정
bos apply --mode incremental --fix

# dry-run (실제 변경 없이 미리보기)
bos apply --mode incremental --dry-run

# blueprint/team ID 오버라이드
bos apply \
  --mode init \
  --app-identifier com.myorg.myapp \
  --apple-team-id XXXXXXXXXX
```

**Exit codes**: 0 = 성공, 2 = 스키마 오류, 3 = drift 감지

### bos verify

```bash
# 기본
bos verify

# 전체 옵션
bos verify \
  --profile .bos/config/profile.yaml \
  --project-root /path/to/project \
  --format json
```

**Exit codes**: 0 = 통과, 3 = drift, 4 = 검증 실패

### bos release-init

```bash
# 기본
bos release-init

# 전체 옵션
bos release-init \
  --blueprint config/blueprint.yaml \
  --profile .bos/config/profile.yaml \
  --project-root /path/to/project \
  --format json
```

---

## 7. 엣지 케이스 & 해결책

| 상황 | 증상 | 해결 |
|------|------|------|
| xcode-select → CLT | `tuist generate` 실패: "Couldn't find Xcode's Info.plist" | `sudo xcode-select -s /Applications/Xcode.app` |
| tuist plugin 구버전 | `tuist scaffold` 실패: "Unknown option '--app-identifier'" | `rm -rf Tuist/Plugins/tma && bos apply --mode init` |
| 스캐폴드 파일 이미 존재 | `tuist scaffold` 건너뜀 (정상) | `bos apply --mode init` 은 idempotent — 문제 없음 |
| bundle ID 불일치 | 앱 타겟 ID가 appIdentifier와 다름 | `release.fastlane.appIdentifier` 값 확인 후 re-apply |
| signing.env 미설정 | `bos doctor --for release-init` exit 6 | `.bos/config/signing.env` 파일 작성 |
| sudo 명령 auto-install 실패 | "sudo: a terminal is required" | xcode-select 수동 실행: `sudo xcode-select -s /Applications/Xcode.app` |
| doctor 기본 scope가 release | exit 6 (signing 없음) | `bos doctor` (default = core) 또는 `--for core` 명시 |
| `SettingsDictionary = []` 컴파일 오류 | teamId 제공 시 빈 dict가 `[]`로 생성 | 최신 bos 소스로 재빌드 후 plugin 재설치 |

---

## 8. 생성 파일 구조 (apply --mode init 결과)

```
project-root/
├── config/
│   ├── blueprint.yaml           # 입력: 프로젝트 설계도
│   └── toolchain.lock.yaml      # 생성: 도구 버전 잠금
├── .bos/
│   └── config/
│       ├── profile.yaml         # 생성 or 기존: 코딩 정책
│       └── signing.env          # 생성: 릴리즈 signing 환경 (git 제외)
├── Tuist/
│   └── Plugins/
│       └── tma/                 # 생성: scaffold 템플릿 플러그인
├── Projects/
│   ├── App/                     # 생성: App 타겟
│   ├── Features/
│   │   ├── Root/               # 생성: Root Feature
│   │   └── Home/               # 생성: Home Feature (예시)
│   ├── Domains/
│   │   └── Item/               # 생성: Item Domain
│   ├── Services/
│   │   └── ItemService/        # 생성: ItemService
│   └── Shared/
│       ├── Core/               # 생성: Core
│       └── DesignSystem/       # 생성: DesignSystem
└── Workspace.swift              # 생성: Tuist Workspace
```

---

## 9. 새 프로젝트 체크리스트

```
[ ] Apple Developer 계정 확인 (Team ID 준비)
[ ] App Bundle ID 결정 (com.org.appname 형식)
[ ] Xcode.app 설치 확인
[ ] xcode-select → Xcode.app 가리키는지 확인
[ ] tuist 설치 확인 (brew install tuist)

[ ] config/blueprint.yaml 작성 (또는 bos plan으로 생성)
[ ] bos doctor --for core 실행 → exit 0 확인
[ ] bos apply --mode init 실행 → exit 0 확인
[ ] tuist install && tuist generate 실행
[ ] Xcode에서 빌드 확인

릴리즈 준비 시:
[ ] .bos/config/signing.env 작성 (5개 키 모두)
[ ] bos doctor --for release-init → exit 0 확인
[ ] bos release-init 실행
```

---

## 10. JSON 출력 파싱 (AI Agent용)

모든 명령에 `--format json` 추가 시 구조화된 JSON 출력:

```bash
bos doctor --for core --format json
```

```json
{
  "command": "doctor",
  "status": "success",
  "exitCode": 0,
  "summary": "Doctor passed for core",
  "scope": "core",
  "findings": [
    {
      "tool": "swift",
      "severity": "required",
      "status": "installed",
      "expectedRule": "semver-range:>=6.0 <7.0",
      "actualVersion": "6.0.3",
      "action": "No action required"
    }
  ],
  "installAttempts": [],
  "artifacts": ["/path/to/.bos/artifacts/doctor/doctor-TIMESTAMP.json"]
}
```

**Exit code 확인 패턴 (shell)**:
```bash
bos doctor --for core --format json
EXIT=$?
if [ $EXIT -ne 0 ]; then
  echo "Doctor failed with exit $EXIT"
  exit $EXIT
fi
```

---

## 11. .gitignore 권장

```gitignore
# bos 생성 파일
.bos/artifacts/
.bos/config/signing.env    # 절대 커밋 금지 — 민감 정보

# Tuist
*.xcodeproj
*.xcworkspace
Tuist/.build/
```

---

## 빠른 참조 카드

```
명령           역할                    최소 입력
──────────────────────────────────────────────────
bos doctor     환경/버전 체크          없음
bos plan       PRD → blueprint         --plan-dir 또는 --prd
bos apply      scaffold 생성/갱신      blueprint.yaml 존재
bos verify     코드 검증               없음 (blueprint + profile 자동 탐색)
bos release-init fastlane 설정         blueprint.yaml + signing.env

Exit Codes: 0=성공, 2=스키마오류, 3=drift, 4=verify실패, 5=release실패, 6=doctor실패
```
