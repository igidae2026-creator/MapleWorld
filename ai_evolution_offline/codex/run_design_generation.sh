#!/usr/bin/env bash

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

cd "$REPO_ROOT"

echo "Starting MMO design graph generation..."

python3 ai_evolution_offline/codex/initialize_design_graph.py
python3 ai_evolution_offline/codex/expand_design_graph.py
python3 ai_evolution_offline/codex/merge_nodes.py
python3 ai_evolution_offline/codex/regenerate_frontier.py
python3 ai_evolution_offline/codex/generate_parameter_schema.py
python3 ai_evolution_offline/codex/generate_balance_tables.py
python3 ai_evolution_offline/codex/generate_liveops_assets.py
python3 ai_evolution_offline/codex/generate_expansion_assets.py
python3 ai_evolution_offline/codex/update_progress.py
