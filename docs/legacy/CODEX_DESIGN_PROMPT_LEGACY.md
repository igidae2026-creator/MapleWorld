# Codex Design Prompt

> Legacy prompt artifact.
> This file is not policy authority and may be stale relative to `ai_evolution_offline/prompts/` and the top skeleton.

Generate hierarchical design nodes for a MapleLand-class MMORPG world.

Data files

data/design_graph/nodes.json
data/design_graph/frontier.json
data/design_graph/index.json

Rules

1. Expand nodes listed in frontier.json
2. Generate 20-40 child nodes per frontier node
3. Prefer operational parameters used in live MMORPG balancing
4. Avoid duplicates using index.json
5. Append new nodes to nodes.json
6. Replace frontier with newly generated nodes
7. Update node_count in ops/codex_state/progress.json

Node format

```json
{
  "id": "economy.currency.monster_drop.rate",
  "layer": 4,
  "parent": "economy.currency.monster_drop"
}
```

Stop when node_count >= target_nodes.
