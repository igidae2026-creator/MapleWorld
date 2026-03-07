# Performance Model

Performance is handled inside the single authoritative runtime.

- bounded scheduler ticks
- event batching via `ops/event_batcher.lua`
- entity indexing via `ops/entity_index.lua`
- performance counters via `ops/performance_counters.lua`
- profiler samples and metrics aggregation on the world-ops tick

Tracked runtime signals:

- player count
- entity count
- combat throughput proxy
- batch queue depth
