# Checklist Layer 2 - 모듈책임

Layer 2 maps Layer 1 objective conditions into implementation responsibilities.

## Top Governance Module

- `GOAL.md`
- `METAOS_CONSTITUTION.md`
- `AGENTS.md`

Responsibility:
- hold top authority
- prevent lower-level governance drift
- fix the optimization direction

## Player Experience Evaluation Module

- `docs/reference/QUALITY_GATES.md`
- `metrics_engine/player_experience_metrics.py`
- `offline_ops/codex_state/simulation_runs/player_experience_metrics_latest.json`

Responsibility:
- score player-experience gates
- identify the active player bottleneck
- prevent feature-first drift

## Autonomous Execution Module

- `docs/reference/EXECUTION_LOOP.md`
- `docs/operations/AUTONOMY_STACK.md`
- `UNIVERSAL_FINAL_THRESHOLD_BUNDLE.md`
- `ai_evolution_offline/codex/run_bottleneck_loop.sh`
- `auto_continue.sh`

Responsibility:
- run bottleneck-first loops
- keep branch count bounded
- prefer small winning patches
- evolve the execution stack from one loop into event log + typed snapshots + job queue + supervisor
- provide the policy surface required for scope selection and material promotion
- evaluate final-threshold readiness as one bundle and emit only the missing criteria as next repair work

## Runtime and Shared Logic Boundary Module

- `msw_runtime/`
- `shared_rules/`
- `content_build/`
- `offline_ops/`

Responsibility:
- preserve authority boundaries
- keep live runtime gameplay-only
- keep offline tooling out of MSW authority
- keep economy pressure tuning and intervention selection offline, while runtime only applies server-authoritative gameplay mutation and report surfaces

## Patch Governance Module

- `CHECKLIST_METHOD_패치.md`
- `COVERAGE_AUDIT.csv`
- `CONFLICT_LOG.csv`

Responsibility:
- record what the skeleton covers
- record where rules conflict
- force governance changes to move through top authority

## Progress Tracking Module

- `ai_evolution_offline/codex/design_pipeline.py`
- `offline_ops/codex_state/progress.json`
- `offline_ops/codex_state/eval_scores.json`

Responsibility:
- keep structural scores and player bottlenecks visible together
- preserve repeated-run state

## Outer Intake and Promotion Module

- `docs/operations/AUTONOMY_STACK.md`
- `METAOS_CONSTITUTION.md`
- `GOAL.md`

Responsibility:
- define how new external materials enter the system
- classify scope fit, authority fit, and upgrade value
- allow automatic promotion of qualified materials into governed execution
- reject low-value or out-of-scope materials without requiring default human sorting

## PASS Conditions

- every top-level objective has a responsible module
- every responsible module has a stable repository home
- player bottleneck selection is connected to the loop
- external material handling is governed by explicit promotion logic rather than ad hoc human sorting

## FAIL Conditions

- objectives exist without owners
- owners exist without repository authority
- bottleneck outputs are generated but ignored by the loop
- new material intake depends on manual interpretation because no governed promotion surface exists
