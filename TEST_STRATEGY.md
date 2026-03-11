# Test Strategy

Tests prioritize invariants over superficial method coverage.

- content integrity: validate generated content graph, counts, and references
- gameplay invariants: jobs, skills, stat allocation, crafting, social/trade, and combat progression
- economy invariants: market listings, mesos transfer correctness, and quest reward flow
- operations invariants: replay determinism, control-plane coherence, channel transfer routing, and consistency validation
- binding invariants: MSW manifest completeness and bridge reachability for new server methods

Player-experience gates are also first-class validation targets.

- `first_10_minutes`: early combat clarity, first reward visibility, first route change, and absence of dead onboarding
- `first_hour_retention`: route separation, repeated growth beats, visible build direction, and meaningful economy pressure
- `day1_return_intent`: unfinished chase goals, reward anticipation, social hooks, and visible next-step motivation

Architecture or balance changes that improve structural metrics while regressing these gates should be treated as failures, even if no low-level invariant breaks.

MapleWorld uses repository-level invariant tests instead of narrow unit-only coverage.

Core invariant groups:

- gameplay progression: class, job, skills, combat, boss mechanics, loot, quests, and guidance
- content density: registry integrity, regional progression coverage, rare-spawn coverage, and event availability
- economy and security: inflation, duplication prevention, exploit surfacing, transfer correctness, and market behavior
- persistence and runtime: replay determinism, save/load integrity, tick stability, stress behavior, and operator surfaces
- player-experience proxies: first-session flow, first-hour loop texture, return motivation, route variance, and social value windows
