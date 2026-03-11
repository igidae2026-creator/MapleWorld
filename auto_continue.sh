#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -f "$ROOT_DIR/ai_evolution_offline/codex/run_bottleneck_loop.sh" ]; then
  echo "missing bottleneck loop runner"
  exit 1
fi

cd "$ROOT_DIR"

python3 metrics_engine/run_quality_eval.py
python3 ai_evolution_offline/codex/score_candidates.py >/dev/null
python3 ai_evolution_offline/codex/update_progress.py
python3 ai_evolution_offline/codex/validate_top_skeleton.py

if [ -f "$ROOT_DIR/offline_ops/codex_state/progress.json" ]; then
  printf '\n--- DESIGN PROGRESS ---\n'
  sed -n '1,120p' "$ROOT_DIR/offline_ops/codex_state/progress.json"
fi

exec bash ai_evolution_offline/codex/run_bottleneck_loop.sh
