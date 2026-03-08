#!/usr/bin/env bash
set -euo pipefail

REPO="${HOME}/MapleWorld"
PROMPT_FILE="${REPO}/ops/prompts/phase2_prompt.txt"
LOG_DIR="${REPO}/ops/codex_state/phase2_runs"

mkdir -p "$LOG_DIR"

if [ ! -f "$PROMPT_FILE" ]; then
  echo "Missing prompt file: $PROMPT_FILE" >&2
  exit 1
fi

for i in $(seq 1 8); do
  echo "========== PHASE 2 RUN $i / 8 =========="
  codex exec --cd "$REPO" --full-auto < "$PROMPT_FILE" \
    | tee "$LOG_DIR/run_${i}.log"

  echo "---------- progress after run $i ----------"
  [ -f "$REPO/ops/codex_state/progress.json" ] && cat "$REPO/ops/codex_state/progress.json"
  echo
done

echo "Completed 8 Phase 2 runs."
