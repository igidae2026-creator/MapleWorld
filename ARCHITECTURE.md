# Architecture

MapleWorld is organized as four connected planes.

1. Content plane
   `content_build/content_registry.lua` generates the canonical content graph. `content_build/content_loader.lua` attaches validation, indexes, balance tables, and generation seeds. `data/runtime_tables.lua` remains a consumer-facing table surface, but world runtime ownership no longer lives inside the gameplay boundary.

2. Gameplay plane
   `msw_runtime/` is the target gameplay root. The previous `server_bootstrap` integration spine was removed so MSW runtime ownership is no longer routed through a standalone MMO bootstrap.

3. Authority and operations plane
   `offline_ops/` owns persistence tooling, replay, control-plane state, cluster routing, sessions, failover, telemetry, audit, exploit scoring, distributed rate limits, and policy evaluation outside the MSW runtime.

4. Runtime binding plane
   `msw_runtime/` now exposes a thin gameplay entry surface. The giant runtime bridge was removed instead of preserved.
