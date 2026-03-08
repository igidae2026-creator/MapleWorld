#!/usr/bin/env bash
set -euo pipefail

REPO="${HOME}/MapleWorld"
PROMPT_FILE="${REPO}/ops/prompts/p0_prompt_codex_isolated_01.txt"
STATE_FILE="${REPO}/ops/codex_state/p0_counter_codex_isolated_01.txt"
PROGRESS_FILE="${REPO}/ops/codex_state/p0_prog_codex_isolated_01.json"
LAST_RUN_FILE="${REPO}/ops/codex_state/p0_last_run_codex_isolated_01.txt"
LOG_DIR="${REPO}/ops/codex_state/p0_runs_codex_isolated_01"
MAX_RUNS="${1:-52}"
VALIDATOR="${REPO}/scripts/codex/validate_p0_progress_codex_isolated_01.py"

mkdir -p "$LOG_DIR"
touch "$STATE_FILE"
touch "$LAST_RUN_FILE"

if ! remaining=$("$VALIDATOR"); then
  echo "Invalid P0 progress schema: $PROGRESS_FILE"
  exit 1
fi

count=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
count=${count:-0}

while [ "$count" -lt "$MAX_RUNS" ]; do
  next=$((count + 1))

  if [ -f "$PROGRESS_FILE" ]; then
    completed=$(grep -c '"status": "complete"' "$PROGRESS_FILE" || true)
    total=$(grep -c '"key": "' "$PROGRESS_FILE" || true)
    echo "========== P0 RUN $next / $MAX_RUNS =========="
    echo "completed_items=$completed total_items=$total"
    if [ "$total" -gt 0 ] && [ "$completed" -ge "$total" ]; then
      echo "All P0 items completed."
      break
    fi
  else
    echo "Missing progress file: $PROGRESS_FILE"
    exit 1
  fi

  codex exec --cd "$REPO" --full-auto < "$PROMPT_FILE" \
    | tee "$LOG_DIR/run_${next}.log"

  if ! remaining_after=$("$VALIDATOR"); then
    echo "Invalid P0 progress schema after run $next: $PROGRESS_FILE"
    exit 1
  fi

  echo "$next" > "$STATE_FILE"
  count=$next

  echo "---------- progress after run $next ----------"
  [ -f "$PROGRESS_FILE" ] && cat "$PROGRESS_FILE"
  echo
  echo "---------- last run ----------"
  [ -f "$LAST_RUN_FILE" ] && cat "$LAST_RUN_FILE"
  echo
  echo "remaining_items=$remaining_after"
  echo
done

echo "P0 loop finished."
