# Documentation Map

## Purpose

This file is the repository-wide map for deciding which documents are authoritative, which are active references, and which are legacy support material.

It exists to stop documentation drift, duplicated authority, and stale root markdown from being mistaken for live governance.

## 1. Top Authority

These files define repository authority and override lower documents when conflicts exist.

- [`GOAL.md`](/home/meta_os/MapleWorld/GOAL.md)
- [`METAOS_CONSTITUTION.md`](/home/meta_os/MapleWorld/METAOS_CONSTITUTION.md)
- [`RULE_CARDS.jsonl`](/home/meta_os/MapleWorld/RULE_CARDS.jsonl)
- [`CHECKLIST_LAYER1_목표조건.md`](/home/meta_os/MapleWorld/CHECKLIST_LAYER1_목표조건.md)
- [`CHECKLIST_LAYER2_모듈책임.md`](/home/meta_os/MapleWorld/CHECKLIST_LAYER2_모듈책임.md)
- [`CHECKLIST_LAYER3_REPO매핑.md`](/home/meta_os/MapleWorld/CHECKLIST_LAYER3_REPO매핑.md)
- [`CHECKLIST_METHOD_패치.md`](/home/meta_os/MapleWorld/CHECKLIST_METHOD_패치.md)
- [`COVERAGE_AUDIT.csv`](/home/meta_os/MapleWorld/COVERAGE_AUDIT.csv)
- [`CONFLICT_LOG.csv`](/home/meta_os/MapleWorld/CONFLICT_LOG.csv)

## 2. Threshold And Player-Facing Standards

These files define cross-cutting evaluation standards beneath the top skeleton and above module-local reference docs.

- [`UNIVERSAL_FINAL_THRESHOLD_BUNDLE.md`](/home/meta_os/MapleWorld/UNIVERSAL_FINAL_THRESHOLD_BUNDLE.md)
- [`docs/standards/AUTONOMY_TARGET.md`](/home/meta_os/MapleWorld/docs/standards/AUTONOMY_TARGET.md)
- [`docs/standards/KOREAN_PLAYER_FEEL_STANDARD.md`](/home/meta_os/MapleWorld/docs/standards/KOREAN_PLAYER_FEEL_STANDARD.md)
- [`docs/standards/DOCUMENTATION_MAP.md`](/home/meta_os/MapleWorld/docs/standards/DOCUMENTATION_MAP.md)

## 3. Operating Entry Documents

These files are the normal entry surface for contributors and autonomous loops. They explain how to operate inside the current authority model, but they do not outrank the top skeleton.

- [`AGENTS.md`](/home/meta_os/MapleWorld/AGENTS.md)
- [`README.md`](/home/meta_os/MapleWorld/README.md)
- [`DOCS_CANON.md`](/home/meta_os/MapleWorld/DOCS_CANON.md)
- [`docs/operations/AUTONOMY_STACK.md`](/home/meta_os/MapleWorld/docs/operations/AUTONOMY_STACK.md)

## 4. Active Reference Documents

These files are still useful implementation references. They may guide subsystem work, but they should not be treated as independent policy authority.

- [`docs/reference/ARCHITECTURE.md`](/home/meta_os/MapleWorld/docs/reference/ARCHITECTURE.md)
- [`docs/reference/GAME_DESIGN.md`](/home/meta_os/MapleWorld/docs/reference/GAME_DESIGN.md)
- [`docs/reference/EXECUTION_LOOP.md`](/home/meta_os/MapleWorld/docs/reference/EXECUTION_LOOP.md)
- [`docs/reference/QUALITY_GATES.md`](/home/meta_os/MapleWorld/docs/reference/QUALITY_GATES.md)
- [`docs/reference/TEST_STRATEGY.md`](/home/meta_os/MapleWorld/docs/reference/TEST_STRATEGY.md)
- [`docs/reference/SECURITY_MODEL.md`](/home/meta_os/MapleWorld/docs/reference/SECURITY_MODEL.md)
- [`docs/reference/CONTENT_MODEL.md`](/home/meta_os/MapleWorld/docs/reference/CONTENT_MODEL.md)
- [`docs/reference/CONTENT_PIPELINE.md`](/home/meta_os/MapleWorld/docs/reference/CONTENT_PIPELINE.md)
- [`docs/reference/GAMEPLAY_SYSTEMS.md`](/home/meta_os/MapleWorld/docs/reference/GAMEPLAY_SYSTEMS.md)
- [`docs/reference/PLAYER_PROGRESSION.md`](/home/meta_os/MapleWorld/docs/reference/PLAYER_PROGRESSION.md)
- [`docs/reference/ITEM_SYSTEM.md`](/home/meta_os/MapleWorld/docs/reference/ITEM_SYSTEM.md)
- [`docs/reference/WORLD_MODEL.md`](/home/meta_os/MapleWorld/docs/reference/WORLD_MODEL.md)
- [`docs/reference/WORLD_EVENTS.md`](/home/meta_os/MapleWorld/docs/reference/WORLD_EVENTS.md)
- [`docs/reference/ECONOMY_MODEL.md`](/home/meta_os/MapleWorld/docs/reference/ECONOMY_MODEL.md)
- [`docs/reference/OPERATIONS.md`](/home/meta_os/MapleWorld/docs/reference/OPERATIONS.md)
- [`docs/reference/SERVER_ARCHITECTURE.md`](/home/meta_os/MapleWorld/docs/reference/SERVER_ARCHITECTURE.md)
- [`docs/reference/PERFORMANCE_MODEL.md`](/home/meta_os/MapleWorld/docs/reference/PERFORMANCE_MODEL.md)
- [`docs/guards/CANON_LOCK.md`](/home/meta_os/MapleWorld/docs/guards/CANON_LOCK.md)
- [`docs/guards/GAMEPLAY_VARIANCE_RULES.md`](/home/meta_os/MapleWorld/docs/guards/GAMEPLAY_VARIANCE_RULES.md)
- [`docs/guards/AI_FUN_GUARD.md`](/home/meta_os/MapleWorld/docs/guards/AI_FUN_GUARD.md)

## 5. Legacy Or Session-Bound Material

These files should not be used as stable authority without explicit promotion into the top skeleton or active reference set.

- [`docs/legacy/ROADMAP_LEGACY.md`](/home/meta_os/MapleWorld/docs/legacy/ROADMAP_LEGACY.md)
- [`docs/legacy/SESSION_HANDOFF_LEGACY.md`](/home/meta_os/MapleWorld/docs/legacy/SESSION_HANDOFF_LEGACY.md)
- [`docs/legacy/GENESIS_FRAGMENT_LEGACY.md`](/home/meta_os/MapleWorld/docs/legacy/GENESIS_FRAGMENT_LEGACY.md)
- [`docs/legacy/EXPLORATION_OS_FRAMING_LEGACY.md`](/home/meta_os/MapleWorld/docs/legacy/EXPLORATION_OS_FRAMING_LEGACY.md)
- [`docs/legacy/MIGRATION_HISTORY_LEGACY.md`](/home/meta_os/MapleWorld/docs/legacy/MIGRATION_HISTORY_LEGACY.md)
- [`docs/legacy/CODEX_DESIGN_PROMPT_LEGACY.md`](/home/meta_os/MapleWorld/docs/legacy/CODEX_DESIGN_PROMPT_LEGACY.md)

These are useful for context recovery, but they should be treated as historical or exploratory unless promoted.

## 6. Prompt Assets

Prompt files are execution assets, not policy authority.

- [`ai_evolution_offline/prompts`](/home/meta_os/MapleWorld/ai_evolution_offline/prompts)
- [`ops/prompts`](/home/meta_os/MapleWorld/ops/prompts)

## 6B. Repo Surface Audit

The repository should not rely on humans to remember where MSW runtime, offline control, evaluation, and policy surfaces belong.

That boundary is machine-audited through:

- [`scripts/run_repo_surface_audit.py`](/home/meta_os/MapleWorld/scripts/run_repo_surface_audit.py)
- [`offline_ops/codex_state/governance/repo_surface_status.json`](/home/meta_os/MapleWorld/offline_ops/codex_state/governance/repo_surface_status.json)

## 6A. Reference Location Rule

Root markdown should be reserved for top authority and operating entry documents.

Implementation reference markdown belongs under `docs/reference/`.
Cross-cutting standards belong under `docs/standards/`.
Cross-cutting guard rails belong under `docs/guards/`.
Autonomy operating surfaces belong under `docs/operations/`.

## 7. Mutation Rules

- Add or change rules in the top authority first.
- Add new standards only when they cannot live inside an existing top authority file.
- Prefer moving stale policy upward over creating more parallel reference markdown.
- Do not claim a document is canonical unless it appears in sections 1 or 2.

## 8. Naming Guidance

For AI-assisted navigation, file names should expose role and authority immediately.

Prefer:

- explicit authority names such as `GOAL.md` or `CHECKLIST_LAYER1_목표조건.md`
- role-bearing names such as `DOCUMENTATION_MAP.md` or `KOREAN_PLAYER_FEEL_STANDARD.md`
- stable prefixes for grouped documents
- path-level grouping that exposes intent, such as `docs/standards/`, `docs/guards/`, and `docs/operations/`

Avoid adding more ambiguous names like `Genesis.md`, `NEXT_SESSION.md`, or generic prompt titles unless they are clearly marked and placed under `docs/legacy/`.
