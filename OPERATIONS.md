# Operations

Operations stay scoped to a single live world runtime.

- continuity: snapshot manager, replay engine, deterministic replay validator, consistency validator
- safety: cheat detection, exploit monitor, distributed rate limits, policy evaluation
- observability: telemetry pipeline, metrics aggregation, runtime profiler, performance counters, audit log
- runtime control: admin console, GM command service, party finder visibility, live event activation
- throughput protection: event batching and entity indexing

Primary operator surfaces:

- `world:adminStatus()`
- `world:getControlPlaneReport()`
- `world:getEconomyReport()`
- `world:activateWorldEvent()`
