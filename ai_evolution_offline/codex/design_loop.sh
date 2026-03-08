#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

cd "$REPO_ROOT"

iteration=0
max_iterations=12

while true; do
  iteration=$((iteration + 1))
  echo "Design generation loop iteration: $iteration"
  bash ai_evolution_offline/codex/run_design_generation.sh

  if python3 -c 'import json; print("true" if json.load(open("offline_ops/codex_state/progress.json")).get("all_targets_met") else "false")' | grep -q '^true$'; then
    echo "All design generation targets reached."
    break
  fi

  if [ "$iteration" -ge "$max_iterations" ]; then
    echo "Maximum iterations reached before all targets were met." >&2
    exit 1
  fi
done
