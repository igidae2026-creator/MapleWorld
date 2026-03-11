# MapleWorld Re-architecture Migration Map

> Historical migration reference.
> Treat this as implementation history, not current authority.
> The live documentation split is defined in `docs/standards/DOCUMENTATION_MAP.md`.

| Current file or area | Target destination | Action |
| --- | --- | --- |
| `msw/world_server_bridge.lua` | deleted | delete |
| `scripts/server_bootstrap.lua` | deleted | delete |
| `msw/world_server_entry.lua` | `msw_runtime/entry/world_server_entry.lua` | replace |
| `msw/world_server_component.lua` | `msw_runtime/entry/world_server_component.lua` | replace |
| `msw/component_manifest.lua` | `msw_runtime/component_manifest.lua` | replace |
| `scripts/codex/*` | `ai_evolution_offline/codex/` | move |
| `ops/prompts/*` | `ai_evolution_offline/prompts/` | move |
| `ops/codex_state/*` | `offline_ops/codex_state/` | move |
| `ops/*.lua` | `offline_ops/` | move |
| `data/content_loader.lua` | `content_build/content_loader.lua` | move |
| `data/content_registry.lua` | `content_build/content_registry.lua` | move |
| `data/content_index.lua` | `content_build/content_index.lua` | move |
| `data/content_validation.lua` | `content_build/content_validation.lua` | move |
| `data/world_runtime.lua` | deleted | delete |
| `scripts/damage_formula.lua` | `shared_rules/damage_formula.lua` | move |
| `scripts/boss_mechanics_system.lua` | `shared_rules/boss_mechanics_system.lua` | move |
| bootstrap/bridge dependent tests | deleted | delete |
| content and offline-evolution tests | `tests/` | keep |
