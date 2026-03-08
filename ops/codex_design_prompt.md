# Codex Design Prompt

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

Implementation requirement

You must modify repository files directly.

Update the following files:

data/design_graph/nodes.json
data/design_graph/frontier.json
data/design_graph/index.json
ops/codex_state/progress.json

Append new nodes to nodes.json.

Replace frontier.json with newly generated frontier nodes.

Update node_count accordingly.

Do not output suggestions. Only apply file changes.

Expansion rule

If frontier contains N nodes,
generate 20-40 child nodes for each.

Example

economy
-> economy.currency
-> economy.currency.monster_drop
-> economy.currency.monster_drop.rate
