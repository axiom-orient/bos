# Tasks (Execution Queue)

| TASK-ID | Priority | Status | Description | Done Criteria | Evidence |
|---|---|---|---|---|---|
| QA-001 | P0 | DONE | `verify` 명령의 계약(인자 오류 vs 실행 오류)을 명시하고 코드/테스트에 동일 반영 | `verify`는 실행형 계약으로 유지하고, 계약 테스트는 옵션 파싱 실패 케이스만 검증 | `Tests/CoreTests/CLIJsonOutputIntegrationTests.swift` (`testCommandsReturnParseableJSONOnContractErrors`, `testVerifyReturnsParseableJSONOnExecutionFailure`), `swift test --filter CoreTests.CLIJsonOutputIntegrationTests` |
| QA-002 | P0 | DONE | CLI 계약 테스트에서 외부 툴 실행 금지(`tuist/xcodebuild/fastlane`) | 계약 테스트 실행에서 외부 툴 실행 없이 종료되고 JSON 계약만 검증 | `Tests/CoreTests/CLIJsonOutputIntegrationTests.swift` (malformed option 케이스), `swift test --filter CoreTests.CLIJsonOutputIntegrationTests` |
| QA-003 | P0 | DONE | 테스트를 `contract/behavior/integration`으로 분리해 의도를 명확화 | CLI 테스트에 계약/행동 의도가 분리되고 테스트 설명이 문서화됨 | `Tests/CoreTests/CLIJsonOutputIntegrationTests.swift`, `Tests/README.md` |
| QA-004 | P0 | DONE | 외부 툴 의존 테스트 timeout/실패 분류 기준 확정 | CLI 테스트 실행 헬퍼가 timeout 기반 종료를 보장하고 hang을 차단 | `Tests/CoreTests/CLIJsonOutputIntegrationTests.swift` (`runBootstrap(..., timeoutSeconds:)`, `waitForExit`), `swift test` (65 tests, 0 failures) |
| UX-001 | P0 | DONE | `doctor`를 1회 실행 중심 UX로 단순화 | `--for` 미지정 시 release-init 준비를 기본 수행하고 required 도구 자동 설치를 시도 | `Sources/BosCLI/main.swift` (`parseDoctorScope`, `runDoctor`, `performDoctorAutoInstall`) |
| UX-002 | P0 | DONE | signing secret 파일 기반 입력 자동화 | `.bos/config/signing.env` 템플릿 자동 생성 + doctor/release-init 자동 로드 + 형식 검증 연동 | `Sources/BosCLI/main.swift` (`resolveSigningEnvironment`, `runReleaseInit`), `.gitignore` |
| UX-003 | P0 | DONE | 런타임 아티팩트 경로의 하드코딩 제거 | 어떤 사용자 경로에서도 아티팩트가 `<project-root>/.bos/artifacts/<command>/`에 기록된다 | `Sources/BosCore/RuntimeArtifacts.swift`, `Sources/BosCore/{ApplyEngine,DoctorEngine,VerifyEngine,ReleaseInitEngine}.swift`, `Tests/CoreTests/CLIJsonOutputIntegrationTests.swift` (`testDoctorUsesProjectScopedArtifactDirectory`) |
| UX-004 | P0 | DONE | signing env 파일 문법 오류를 명확한 명령 실패 코드로 분류 | `doctor`는 6, `release-init`는 5로 종료하고 raw `NSError` 대신 사용자 메시지를 출력한다 | `Sources/BosCLI/main.swift` (`SigningEnvironmentFileError`, `signingEnvironmentLoadErrorMessage`, `runDoctor`, `runReleaseInit`), `Tests/CoreTests/CLIJsonOutputIntegrationTests.swift` (`testDoctorReportsDoctorFailureCodeOnInvalidSigningEnvironmentSyntax`, `testReleaseInitReportsReleaseFailureCodeOnInvalidSigningEnvironmentSyntax`) |
| SEC-001 | P1 | DONE | signing env 템플릿 파일 권한 최소화 | 자동 생성 파일 권한이 owner read/write(0600)로 설정된다 | `Sources/BosCLI/main.swift` (`hardenSigningEnvironmentFilePermissions`), `Tests/CoreTests/CLIJsonOutputIntegrationTests.swift` (`testDoctorDefaultsToReleaseInitAndCreatesSigningEnvTemplate`) |
| UX-005 | P0 | DONE | signing env 문법 오류의 줄번호 정확도 보정 | 빈 줄/주석이 있어도 메시지의 line 번호가 실제 파일 줄과 일치한다 | `Sources/BosCLI/main.swift` (`parseEnvironmentFile`), `Tests/CoreTests/CLIJsonOutputIntegrationTests.swift` (`testDoctorReportsAccurateLineNumberWithCommentsAndBlankLines`), `swift test --filter CoreTests.CLIJsonOutputIntegrationTests` (17 tests, 0 failures) |
| OPS-001 | P1 | DONE | 아티팩트 폴더 히스토리 보존 정책 추가 | 명령 재실행 시 직전 아티팩트를 지우지 않고 최근 N개만 유지한다 | `Sources/BosCore/RuntimeArtifacts.swift` (`maxRetainedArtifactsPerCommand`, `pruneOldArtifacts`), `Tests/CoreTests/CLIJsonOutputIntegrationTests.swift` (`testDoctorRetainsArtifactsAcrossRuns`), `Tests/CoreTests/RuntimeArtifactsTests.swift` (`testMakeDirectoryPrunesOldArtifactsAboveRetentionLimit`), `swift test` (65 tests, 0 failures) |
| QA-005 | P0 | DONE | 신규 UX 회귀 테스트 추가 | doctor 기본 scope/자동 템플릿 및 release-init env 파일 로드가 테스트로 고정 | `Tests/CoreTests/CLIJsonOutputIntegrationTests.swift` (`testDoctorDefaultsToReleaseInitAndCreatesSigningEnvTemplate`, `testReleaseInitReadsSigningEnvironmentFromDefaultFile`) |
| REL-001 | P0 | DONE | 출시 최소 게이트 정의(필수 테스트 세트 + 명령 증거) | 게이트 체크리스트 pass/fail가 명확하고 증거 경로 존재 | `docs/IMPLEMENTATION-PLAN.md`의 Release Gate Checklist + 결과 섹션 |
| REL-002 | P0 | DONE | 출시 전 3회 반복 검증 루틴 수행 | P0 테스트 세트 3회 연속 동일 결과 | `swift test --filter 'CoreTests\\.(CLIJsonOutputIntegrationTests|DoctorEngineIntegrationTests|ReleaseInitEngineIntegrationTests|ApplyEngineIntegrationTests|PlanEngineIntegrationTests|VerifyEngineIntegrationTests|SchemaValidationTests|ProfilePolicyE2ETests)'` 3회 연속 통과 (2026-03-05 19:30:59/19:32:18/19:33:36 KST) |
| REL-003 | P0 | DONE | 출시 직전 오픈 태스크 제로화 검증 | `P0/P1`의 `TODO/DOING/BLOCKED`가 0개임을 확인 | 본 문서 상태 스냅샷: P0/P1는 `DONE` 또는 `Excluded`만 존재 |
| LEG-001 | P1 | DONE | 불필요/중복 문서 정리(기준 문서 최소 세트 유지) | 운영 기준 문서가 4개(`README`, `PRODUCT_GUIDE`, `IMPLEMENTATION-PLAN`, `TASKS`)로 수렴 | 루트 기준 문서 4개 유지 + `docs/UX_REDESIGN.md` 제거 |
| LEG-002 | P1 | DONE | 레거시 플래그/분기 정리 목록 수립 및 제거 | 사용되지 않는 옵션/분기가 코드에서 제거되고 테스트가 갱신됨 | `Sources/BosCLI/main.swift`: `--verbose` 제거, deprecated lock 경로(`.bos/config/...`) 지원 제거 |
| LEG-003 | P1 | DONE | `docs/UX_REDESIGN.md` 정리(필요 내용 이관 후 삭제) | 기준 문서에 필요한 항목이 반영되고 `docs/UX_REDESIGN.md`가 제거됨 | `docs/PRODUCT_GUIDE.md`, `docs/IMPLEMENTATION-PLAN.md` 갱신 + `docs/UX_REDESIGN.md` 삭제 |
| DOC-002 | P1 | DONE | 문서와 실제 코드 상태 불일치 제거 | 문서의 상태/명령/예제가 실제 실행 결과와 일치 | `docs/PRODUCT_GUIDE.md`, `docs/IMPLEMENTATION-PLAN.md`, `Tests/README.md` 반영 + `swift test` 통과(65 tests) |
| SIGN-004 | P1 | DONE | signing preflight 강화(필수 env 형식 검증/안내) | 누락/형식 오류가 사전 차단되고 메시지가 구체적 | `Sources/BosCore/SigningEnvironmentPolicy.swift`, `Sources/BosCore/DoctorEngine.swift`, `Sources/BosCore/ReleaseInitEngine.swift`, `Sources/BosCLI/main.swift`, 관련 테스트 |
| SIGN-001 | P0 | DONE | `apply(init)` Team ID 전달 | 생성된 `Projects/**/Project.swift`에 `DEVELOPMENT_TEAM` 반영 | `Sources/BosCore/ApplyEngine.swift`, `Tests/CoreTests/ApplyEngineIntegrationTests.swift` |
| SIGN-002 | P0 | DONE | `release-init` certs lane을 ASC API key signing sync로 전환 | `Fastfile`에 `private_lane :asc_api_key` + `sync_code_signing(..., api_key: asc_api_key)` 존재 | `Sources/BosCore/ReleaseInitEngine.swift`, `Tests/CoreTests/ReleaseInitEngineIntegrationTests.swift` |
| ENV-006 | P0 | DONE | doctor lock 초기화 UX를 자동 생성 방식으로 단순화 | lock 미존재 시 `config/toolchain.lock.yaml` 자동 생성 후 검사 진행 | `Sources/BosCLI/main.swift`, `Tests/CoreTests/CLIJsonOutputIntegrationTests.swift` |
| DOC-001 | P1 | DONE | 계획/태스크 문서 정합성 1차 정리 | 계획 문서와 코드 상태의 명백한 충돌 제거 | `docs/IMPLEMENTATION-PLAN.md`, `docs/TASKS.md` |

## Excluded From This Release Scope
- `SIGN-003` (`release-init --run-certs`)
- `AET-004` (`--module-policy`)
- `AET-006` (`verify --smoke`)

## Release Gate Execution Evidence (2026-03-05 KST)
- Cycle-1: `swift test --filter 'CoreTests\\.(CLIJsonOutputIntegrationTests|DoctorEngineIntegrationTests|ReleaseInitEngineIntegrationTests|ApplyEngineIntegrationTests|PlanEngineIntegrationTests|VerifyEngineIntegrationTests|SchemaValidationTests|ProfilePolicyE2ETests)'` → 64 tests, 0 failures (start: 19:30:59)
- Cycle-2: same command → 64 tests, 0 failures (start: 19:32:18)
- Cycle-3: same command → 64 tests, 0 failures (start: 19:33:36)
- Final full check: `swift test` → 65 tests, 0 failures (start: 19:38:13)
