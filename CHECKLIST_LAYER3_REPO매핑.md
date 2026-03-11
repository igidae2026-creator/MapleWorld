# Checklist Layer 3 - REPO매핑

Layer 3 maps Layer 2 responsibilities to concrete repository files.

| Module | Canonical Files | Status |
| --- | --- | --- |
| Top Governance | `GOAL.md`, `METAOS_CONSTITUTION.md`, `AGENTS.md` | active |
| Player Experience Evaluation | `QUALITY_GATES.md`, `metrics_engine/player_experience_metrics.py`, `offline_ops/codex_state/simulation_runs/player_experience_metrics_latest.json` | active |
| Autonomous Execution | `EXECUTION_LOOP.md`, `AUTONOMY_STACK.md`, `UNIVERSAL_FINAL_THRESHOLD_BUNDLE.md`, `auto_continue.sh`, `ai_evolution_offline/codex/run_bottleneck_loop.sh` | active |
| Runtime Boundary | `ARCHITECTURE.md`, `SERVER_ARCHITECTURE.md`, `ECONOMY_MODEL.md`, `msw_runtime/README.md`, `shared_rules/README.md`, `content_build/README.md`, `offline_ops/README.md` | active |
| Progress Tracking | `ai_evolution_offline/codex/design_pipeline.py`, `offline_ops/codex_state/progress.json`, `offline_ops/codex_state/eval_scores.json` | active |
| Patch Governance | `CHECKLIST_METHOD_패치.md`, `COVERAGE_AUDIT.csv`, `CONFLICT_LOG.csv` | active |
| Outer Intake and Promotion | `AUTONOMY_STACK.md`, `GOAL.md`, `METAOS_CONSTITUTION.md` | active |
| Documentation Authority | `DOCS_CANON.md`, `README.md` | transitional |

## Mapping Rules

- Top authority lives at repository root.
- Generated reports do not outrank canonical root files.
- Prompt assets are execution inputs, not governance authority.
- Reference markdown may explain implementation details, but root authority decides policy.

## Current Gap Focus

- `run_bottleneck_loop.sh` should consume player bottleneck outputs more directly.
- coverage and conflict files exist but are not yet fully enforced by Python validators.
- documentation authority is partially transitioned from the earlier lightweight canon.
- autonomy architecture is now defined, but the supervisor/event-log/job-queue/policy runtime surface is not yet fully implemented as first-class code.
- final-threshold bundle authority now exists, but runtime implementations must still converge on one machine-readable evaluation surface.
