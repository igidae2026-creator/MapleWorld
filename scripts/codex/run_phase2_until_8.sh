#!/usr/bin/env bash
set -euo pipefail

REPO="${HOME}/MapleWorld"
PROMPT_FILE="${REPO}/ops/prompts/phase2_prompt.txt"
STATE_FILE="${REPO}/ops/codex_state/phase2_counter.txt"
LOG_DIR="${REPO}/ops/codex_state/phase2_runs"

mkdir -p "$LOG_DIR"
touch "$STATE_FILE"

count=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
count=${count:-0}

while [ "$count" -lt 8 ]; do
  next=$((count + 1))

  echo "========== PHASE 2 RUN $next / 8 =========="

  codex exec --cd "$REPO" --full-auto < "$PROMPT_FILE" \
    | tee "$LOG_DIR/run_${next}.log"

  echo "$next" > "$STATE_FILE"
  count=$next

  echo "---------- progress after run $next ----------"
  [ -f "$REPO/ops/codex_state/progress.json" ] && cat "$REPO/ops/codex_state/progress.json"
  echo
done

echo "Completed 8 Phase-2 cycles."
