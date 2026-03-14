# File-by-File Audit

Legend:
- **Evidence A**: source body directly inspected in this pass
- **Evidence B**: role inferred from repository docs + path + file naming

## Root

- `README.md` — Evidence A — Entry contract is good and narrow. Keep. Tighten relative links and add a v2 scope boundary section.
- `AGENTS.md` — Evidence A — Useful reading order and runtime metadata rules. Keep. Fix local absolute links.
- `Package.swift` — Evidence A — Minimal package graph fits the philosophy. Keep. Add explicit product comments and future module placeholders only when needed.
- `Package.resolved` — Evidence A — Healthy pinning. Keep. Add automated drift check in CI.
- `Mintfile` — Evidence A — Out of sync risk if release tags move independently. Refactor or remove if not part of the install path.
- `.gitignore` — Evidence A — Secret/runtime ignores are correct, but commit-safe profile/blueprint semantics conflict with the docs. Must change.

## Config

- `config/toolchain.lock.yaml` — Evidence A — Good beginning. Extend with `xcode`, `ruby`, `bundler`, `node`, `devicectl/simctl strategy`, and explicit adapter compatibility windows.

## Docs

- `docs/PRODUCT_GUIDE.md` — Evidence A — Strong command contract. Keep.
- `docs/ARCHITECTURE.md` — Evidence A — Honest and simple. Keep, but update once schema split and new domains land.
- `docs/OPERATIONS_GUIDE.md` — Evidence A — Operationally useful. Keep, but align with final path semantics.
- `docs/TESTING_GUIDE.md` — Evidence A — Good philosophy. Extend with compatibility matrix, migration tests, and real-tool contract tests.

## Sources/BosCLI

- `main.swift` — Evidence A — Clean dispatcher. Keep.
- `CLIParsing.swift` — Evidence A — Hand-rolled parser is fine for v1, risky for v2. Refactor into a command-spec driven parser.
- `CLICommandContext.swift` — Evidence A — Central path/context resolver. Keep, but split profile/blueprint/signing loaders into separate IO helpers.
- `CLIConfigSupport.swift` — Evidence A — Too much responsibility: templates, parsing, locking, IO. Split into `ProfileIO`, `SigningEnvIO`, `LockIO`, `YamlCodec`.
- `CLIModels.swift` — Evidence B — Exit codes and payload DTOs. Keep, but split protocol/serialization models from process exit codes.
- `CLIOutputSupport.swift` — Evidence B — Output formatter. Keep.
- `CLIPathSupport.swift` — Evidence B — Path resolution helpers. Keep, but move root sentinel logic here once added.
- `CLIProcessSupport.swift` — Evidence B — Process wrappers/version detection. Keep, but shared adapter runner should own this long term.
- `DoctorSupport.swift` — Evidence A — Probably too broad. Refactor into `ToolDetector`, `InstallerHints`, `DoctorRunner`.
- `DoctorCommand.swift` — Evidence B — Thin adapter. Keep.
- `PlanCommand.swift` — Evidence A — Clear wrapper over `PlanEngine`; current PLAN ingestion is marker-driven and useful. Keep.
- `ApplyCommand.swift` — Evidence A — Dry-run sandbox behavior is good. Keep.
- `VerifyCommand.swift` — Evidence B — Thin wrapper. Keep.
- `ASCCommand.swift` — Evidence A — Excellent pattern: env bridge, artifact write, secret sanitation, exit code preservation. Keep and generalize as adapter standard.
- `AppRegisterCommand.swift` — Evidence A — Good profile backfill pattern. Keep.
- `ReleaseInitCommand.swift` — Evidence A — Thin adapter. Keep.
- `ReleaseCheckCommand.swift` — Evidence A — Correct guard around write mode. Keep.
- `ReleaseRunCommand.swift` — Evidence A — Good orchestration boundary. Keep.

## Sources/BosCore

- `Schemas.swift` — Evidence A — Central schema monolith. Must split.
- `PlanEngine.swift` — Evidence A — Strong bootstrap engine. Keep, but move from heuristic parsing toward schema-driven planning.
- `ApplyEngine.swift` — Evidence A — One of the core assets. Keep. Add template versioning and migration hooks.
- `VerifyEngine.swift` — Evidence A — Correctly narrow smoke validation. Keep.
- `DoctorEngine.swift` — Evidence A — Valuable contract gate. Keep, but align findings with real tool requirements.
- `AppRegistrationEngine.swift` — Evidence A — Important engine. Keep, but formalize provider and retry/idempotency policy.
- `ASCBackend.swift` — Evidence A — Good thin adapter core. Keep.
- `ASCAppStoreAppResolver.swift` — Evidence A — Good focused helper. Keep.
- `ASCAppStoreReadinessChecker.swift` — Evidence A — Good focused helper. Keep.
- `OnboardingConfiguration.swift` — Evidence A — Useful policy file. Keep.
- `SigningEnvironmentPolicy.swift` — Evidence A — Good validation boundary. Keep.
- `RuntimeArtifacts.swift` — Evidence A — Good core primitive. Keep, but standardize manifest shape across all commands.
- `BosStateStore.swift` — Evidence A — Good state summary writer. Expand into resumable run metadata.
- `CommandOutput.swift` — Evidence B — Stable output payloads. Keep.
- `NameNormalizer.swift` — Evidence B — Shared naming logic. Keep, but document normalization rules.
- `ProjectBuildSupport.swift` — Evidence B — Shared project/build resolution. Keep.
- `ReleaseInitEngine.swift` — Evidence A — Good local scaffold stage. Keep.
- `ReleaseCheckEngine.swift` — Evidence A — Strong release gate concept. Keep.
- `ReleaseRunEngine.swift` — Evidence A — Strong stage-based runner. Keep.
- `RuntimeSupport.swift` — Evidence B — Shared runtime helpers. Keep.
- `SecretRedactionSupport.swift` — Evidence B — Keep and expand with property-based tests.
- `Resources/` — Evidence B — Product assets, not repo docs. Add explicit versioning and checksum tests.

## Tests/CoreTests

- `PlanEngineIntegrationTests.swift` — Evidence A — Good contract coverage. Keep and extend with malformed PLAN corpus tests.
- `ApplyEngineIntegrationTests.swift` — Evidence A — High value. Keep and expand with template version migration tests.
- `VerifyEngineIntegrationTests.swift` — Evidence A — High value. Keep.
- `AppRegistrationIntegrationTests.swift` — Evidence A — High value. Keep.
- `ReleaseCheckEngineIntegrationTests.swift` — Evidence A — High value. Keep.
- `ReleaseRunEngineIntegrationTests.swift` — Evidence A — High value. Keep.
- `CLIJsonOutputIntegrationTests.swift` — Evidence A — Critical contract lock. Keep.
- `SchemaValidationTests.swift` — Evidence B — Keep, but extend after schema split.
- `RuntimeArtifactsTests.swift` — Evidence B — Keep.
- `SecretRedactionSupportTests.swift` — Evidence B — Keep and expand.
- `ASCBackendIntegrationTests.swift` — Evidence B — Keep.
- `ASCAppStoreAppResolverTests.swift` — Evidence B — Keep.
- `ASCAppStoreReadinessCheckerTests.swift` — Evidence B — Keep.
- `DoctorEngineIntegrationTests.swift` — Evidence B — Keep.
- `NativeAppRegistrationProviderTests.swift` — Evidence B — Keep.
- `ProfilePolicyE2ETests.swift` — Evidence B — Keep.
- `ReleaseInitEngineIntegrationTests.swift` — Evidence B — Keep.

## Tests/Fixtures

- `Tests/Fixtures/daycraft.yaml` — Evidence B — Keep as representative fixture, but add more fixture families.

## Immediate contradictions and defects to resolve

1. **commit-safe profile vs ignored path**
2. **generated blueprint as primary input vs ignored path**
3. **absolute local links embedded in docs**
4. **toolchain lock not matching full release dependencies**
5. **version source split between release tags and Mint install metadata**
