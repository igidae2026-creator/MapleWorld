# Documentation Canon

This repository does not treat every `*.md` file as equal authority.

Canonical documents define stable execution rules, player-facing quality targets, and live design intent. Other markdown files are support material, implementation reference, or prompt assets.

If a conflict exists between the top governance skeleton and earlier lightweight canonical documents, the top governance skeleton wins.

## Top Canonical Set

These files are the actual authority-bearing set.

- `GOAL.md`
- `METAOS_CONSTITUTION.md`
- `RULE_CARDS.jsonl`
- `CHECKLIST_LAYER1_목표조건.md`
- `CHECKLIST_LAYER2_모듈책임.md`
- `CHECKLIST_LAYER3_REPO매핑.md`
- `CHECKLIST_METHOD_패치.md`
- `COVERAGE_AUDIT.csv`
- `CONFLICT_LOG.csv`

## Standard Documents

These define cross-cutting standards under the top authority and above subsystem references.

- `UNIVERSAL_FINAL_THRESHOLD_BUNDLE.md`
- `docs/standards/AUTONOMY_TARGET.md`
- `docs/standards/KOREAN_PLAYER_FEEL_STANDARD.md`
- `docs/standards/DOCUMENTATION_MAP.md`

## Operating Entry Surface

These are the normal orientation documents for contributors and autonomous loops, but they are not top authority.

- `AGENTS.md`
- `README.md`
- `DOCS_CANON.md`
- `docs/operations/AUTONOMY_STACK.md`

## Reference Documents

These documents remain useful, but they are not primary authority when they conflict with the canonical set:

- `docs/reference/CONTENT_MODEL.md`
- `docs/reference/CONTENT_PIPELINE.md`
- `docs/reference/WORLD_MODEL.md`
- `docs/reference/GAMEPLAY_SYSTEMS.md`
- `docs/reference/PLAYER_PROGRESSION.md`
- `docs/reference/ITEM_SYSTEM.md`
- `docs/reference/WORLD_EVENTS.md`
- `docs/reference/ECONOMY_MODEL.md`
- `docs/reference/SERVER_ARCHITECTURE.md`
- `docs/reference/OPERATIONS.md`
- `docs/reference/PERFORMANCE_MODEL.md`
- `docs/legacy/GENESIS_FRAGMENT_LEGACY.md`
- `docs/legacy/MIGRATION_HISTORY_LEGACY.md`
- `docs/legacy/CODEX_DESIGN_PROMPT_LEGACY.md`
- `docs/guards/CANON_LOCK.md`
- `docs/guards/GAMEPLAY_VARIANCE_RULES.md`
- `docs/guards/AI_FUN_GUARD.md`

Reference documents may describe subsystems in more detail, but they should be updated only when they materially help implementation or verification.

For the full current classification, use `docs/standards/DOCUMENTATION_MAP.md`.

## Prompt Assets

These markdown files are execution assets, not design authority:

- `ai_evolution_offline/prompts/*.md`
- `ai_evolution_offline/codex_design_prompt.md`

They may change frequently and should follow the canonical set rather than define it.

## Generated Reports

These markdown files are outputs and should not be treated as stable design authority:

- `offline_ops/codex_state/simulation_runs/**/*.md`
- `offline_ops/codex_state/loop_upgrades/*.md`

## Mutation Rules

- Prefer updating the top canonical set instead of scattering new policy across many markdown files.
- If a new document does not own a stable contract, keep it out of the canonical set.
- If a reference document conflicts with a top canonical or standard document, the higher document wins.
- If a report suggests a rule change, land that rule in a canonical document and keep the report as evidence only.
