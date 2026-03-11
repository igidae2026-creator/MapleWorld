# Documentation Canon

This repository does not treat every `*.md` file as equal authority.

Canonical documents define stable execution rules, architecture boundaries, player-facing quality targets, and live design intent. Other markdown files are support material, generated reports, or prompt assets.

If a conflict exists between the top governance skeleton and earlier lightweight canonical documents, the top governance skeleton wins.

## Canonical Set

- `GOAL.md`
  Repository-level objective authority.
- `METAOS_CONSTITUTION.md`
  Repository-level invariant and authority order.
- `RULE_CARDS.jsonl`
  Compact top-level rule inventory.
- `CHECKLIST_LAYER1_목표조건.md`
  Goal-condition layer for the skeleton.
- `CHECKLIST_LAYER2_모듈책임.md`
  Module-responsibility layer for the skeleton.
- `CHECKLIST_LAYER3_REPO매핑.md`
  Repository-mapping layer for the skeleton.
- `CHECKLIST_METHOD_패치.md`
  Governance patch-order contract.
- `COVERAGE_AUDIT.csv`
  Coverage audit for top-level governance.
- `CONFLICT_LOG.csv`
  Conflict register for top-level governance.
- `AGENTS.md`
  Repository-wide autonomous execution rules and optimization priorities.
- `README.md`
  Entry surface for repository structure, current operating model, and verification commands.
- `ARCHITECTURE.md`
  System planes, ownership boundaries, and runtime responsibility split.
- `GAME_DESIGN.md`
  Canonical player-facing design intent for progression, combat, economy, social play, and world loops.
- `EXECUTION_LOOP.md`
  Canonical autonomous development loop. Defines bottleneck-first execution rather than broad feature-first execution.
- `QUALITY_GATES.md`
  Canonical player-experience acceptance gates. Defines the minimum feel floor for first 10 minutes, first hour, and Day-1 return intent.
- `TEST_STRATEGY.md`
  Canonical validation and regression strategy.
- `SECURITY_MODEL.md`
  Canonical authority, anti-exploit, and mutation safety model.
- `ROADMAP.md`
  Current expansion order after the canonical gates are satisfied.

## Reference Documents

These documents remain useful, but they are not primary authority when they conflict with the canonical set:

- `CONTENT_MODEL.md`
- `CONTENT_PIPELINE.md`
- `WORLD_MODEL.md`
- `GAMEPLAY_SYSTEMS.md`
- `PLAYER_PROGRESSION.md`
- `ITEM_SYSTEM.md`
- `WORLD_EVENTS.md`
- `ECONOMY_MODEL.md`
- `SERVER_ARCHITECTURE.md`
- `OPERATIONS.md`
- `PERFORMANCE_MODEL.md`
- `Genesis.md`
- `migration_map.md`
- `codex_design_prompt.md`
- `docs/CANON_LOCK.md`
- `docs/GAMEPLAY_VARIANCE_RULES.md`
- `docs/AI_FUN_GUARD.md`

Reference documents may describe subsystems in more detail, but they should be updated only when they materially help implementation or verification.

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

- Prefer updating the canonical set instead of scattering new policy across many markdown files.
- If a new document does not own a stable contract, keep it out of the canonical set.
- If a reference document conflicts with a canonical document, the canonical document wins.
- If a report suggests a rule change, land that rule in a canonical document and keep the report as evidence only.
