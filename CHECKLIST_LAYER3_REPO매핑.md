# Checklist Layer 3 - REPO매핑

Layer 3 maps Layer 2 responsibilities to concrete repository files.

| Module | Canonical Files | Status |
| --- | --- | --- |
| Top Governance | `GOAL.md`, `METAOS_CONSTITUTION.md`, `AGENTS.md` | active |
| Player Experience Evaluation | `docs/reference/QUALITY_GATES.md`, `metrics_engine/player_experience_metrics.py`, `offline_ops/codex_state/simulation_runs/player_experience_metrics_latest.json` | active |
| Standards and Thresholds | `UNIVERSAL_FINAL_THRESHOLD_BUNDLE.md`, `docs/standards/AUTONOMY_TARGET.md`, `docs/standards/KOREAN_PLAYER_FEEL_STANDARD.md`, `docs/standards/DOCUMENTATION_MAP.md` | active |
| Guard Rails | `docs/guards/AI_FUN_GUARD.md`, `docs/guards/CANON_LOCK.md`, `docs/guards/GAMEPLAY_VARIANCE_RULES.md`, `metrics_engine/fun_guard_metrics.py` | active |
| Autonomous Execution | `docs/reference/EXECUTION_LOOP.md`, `docs/operations/AUTONOMY_STACK.md`, `auto_continue.sh`, `ai_evolution_offline/codex/run_bottleneck_loop.sh`, `scripts/codex/run_autonomy_daemon.sh` | active |
| Runtime Boundary | `docs/reference/ARCHITECTURE.md`, `docs/reference/SERVER_ARCHITECTURE.md`, `docs/reference/ECONOMY_MODEL.md`, `msw_runtime/README.md`, `shared_rules/README.md`, `content_build/README.md`, `offline_ops/README.md` | active |
| MSW Runtime and State | `msw_runtime/`, `shared_rules/`, `content_build/`, `data/runtime_tables.lua` | active |
| Content and Design Graph | `data/design_graph/`, `data/quests.csv`, `data/dialogues.csv`, `data/npcs.csv`, `data/items.csv` | active |
| Economy and Balance Control | `data/balance/`, `metrics_engine/economy_pressure_metrics.py`, `data/liveops/overrides/` | active |
| Simulation and Verification | `simulation_py/`, `simulation_lua/`, `tests/`, `metrics_engine/run_quality_eval.py` | active |
| Progress Tracking | `ai_evolution_offline/codex/design_pipeline.py`, `offline_ops/codex_state/progress.json`, `offline_ops/codex_state/eval_scores.json` | active |
| Patch Governance | `CHECKLIST_METHOD_패치.md`, `COVERAGE_AUDIT.csv`, `CONFLICT_LOG.csv` | active |
| Outer Intake and Promotion | `docs/operations/AUTONOMY_STACK.md`, `offline_ops/autonomy/`, `GOAL.md`, `METAOS_CONSTITUTION.md` | active |
| Documentation Authority | `DOCS_CANON.md`, `README.md`, `docs/standards/DOCUMENTATION_MAP.md`, `docs/standards/KOREAN_PLAYER_FEEL_STANDARD.md` | active |
| Repo Surface Audit | `scripts/run_repo_surface_audit.py`, `offline_ops/codex_state/governance/repo_surface_status.json`, `offline_ops/codex_state/governance/repo_surface_history.jsonl` | active |

## Mapping Rules

- Top authority lives at repository root.
- Generated reports do not outrank canonical root files.
- Prompt assets are execution inputs, not governance authority.
- Reference markdown may explain implementation details, but root authority decides policy.
- Standards live under `docs/standards/`, guard rails under `docs/guards/`, and operational loop surfaces under `docs/operations/`.
- Repo surface boundaries must remain machine-audited so runtime, offline control, evaluation, data, and documentation do not drift back into ambiguous ownership.

## Current Gap Focus

- `run_bottleneck_loop.sh` should consume player bottleneck outputs more directly.
- coverage and conflict files exist but are not yet fully enforced by Python validators.
- documentation authority should remain synchronized between `DOCS_CANON.md` and `docs/standards/DOCUMENTATION_MAP.md`.
- autonomy architecture is now defined, but the supervisor/event-log/job-queue/policy runtime surface is not yet fully implemented as first-class code.
- final-threshold bundle authority now exists, but runtime implementations must still converge on one machine-readable evaluation surface.
- repo surface audit should remain green so `ops/`, `offline_ops/`, `scripts/`, `msw_runtime/`, and `docs/*` do not collapse back into mixed ownership.
