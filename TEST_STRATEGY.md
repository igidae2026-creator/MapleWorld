# Test Strategy

Tests prioritize invariants over superficial method coverage.

- content integrity: validate generated content graph, counts, and references
- gameplay invariants: jobs, skills, stat allocation, crafting, social/trade, and combat progression
- economy invariants: market listings, mesos transfer correctness, and quest reward flow
- operations invariants: replay determinism, control-plane coherence, channel transfer routing, and consistency validation
- binding invariants: MSW manifest completeness and bridge reachability for new server methods
