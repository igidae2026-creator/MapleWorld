# Test Strategy

Tests prioritize invariants over superficial method coverage.

- content integrity: validate generated content graph, counts, and references
- gameplay invariants: jobs, skills, stat allocation, crafting, social/trade, and combat progression
- economy invariants: market listings, mesos transfer correctness, and quest reward flow
- operations invariants: replay determinism, control-plane coherence, channel transfer routing, and consistency validation
- binding invariants: MSW manifest completeness and bridge reachability for new server methods
MapleWorld uses repository-level invariant tests instead of narrow unit-only coverage.

Core invariant groups:

- gameplay progression: class, job, skills, combat, boss mechanics, loot, quests, and guidance
- content density: registry integrity, regional progression coverage, rare-spawn coverage, and event availability
- economy and security: inflation, duplication prevention, exploit surfacing, transfer correctness, and market behavior
- persistence and runtime: replay determinism, save/load integrity, tick stability, stress behavior, and operator surfaces
