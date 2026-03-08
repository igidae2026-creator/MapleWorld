# Server Architecture

MapleWorld is being reduced from a standalone MMO runtime into a gameplay-only MSW runtime plus offline control surfaces.

Core loop:

1. `msw_runtime/` exposes only gameplay entrypoints and runtime-facing state.
2. Control-plane, replay, scheduling, failover, and clustering live under `offline_ops/`.
3. Content loading and validation live under `content_build/`.
4. The previous bridge/bootstrap ownership model has been removed.

Robustness now depends on a clear boundary: gameplay remains in the MSW runtime, while replay/audit/control systems live offline.

Key runtime-connected support layers:

- `content_build/` owns content preparation and validation.
- `offline_ops/` owns replay, audit, telemetry, stability, and control-plane tooling.
- `scripts/` remains temporary gameplay logic pending further extraction into `msw_runtime/` and `shared_rules/`.
