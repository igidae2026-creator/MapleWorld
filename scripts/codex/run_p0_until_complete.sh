#!/usr/bin/env bash
set -euo pipefail

REPO="${HOME}/MapleWorld"
PROMPT_FILE="${REPO}/ops/prompts/p0_completion_prompt.txt"
STATE_FILE="${REPO}/ops/codex_state/p0_counter.txt"
PROGRESS_FILE="${REPO}/ops/codex_state/p0_prog.json"
RUN_DIR="${REPO}/ops/codex_state/p0_runs"
VALIDATOR="${REPO}/scripts/codex/validate_p0_progress.py"

mkdir -p "$RUN_DIR"
touch "$STATE_FILE"

count=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
count=${count:-0}

while true; do
  if ! remaining=$("$VALIDATOR"); then
    echo "Invalid P0 progress schema: $PROGRESS_FILE"
    exit 1
  fi

  if [ "$remaining" -eq 0 ]; then
    echo "P0 completion achieved."
    break
  fi

  next=$((count + 1))

  echo "========== P0 CYCLE $next =========="
  echo "remaining targets: $remaining"

  cp "$PROGRESS_FILE" "$RUN_DIR/progress_before_${next}.json"

  codex exec --cd "$REPO" --full-auto < "$PROMPT_FILE" \
    | tee "$RUN_DIR/run_${next}.log"

  if ! remaining_after=$("$VALIDATOR"); then
    echo "Progress schema invalid after cycle $next"
    cp "$RUN_DIR/progress_before_${next}.json" "$PROGRESS_FILE"
    exit 1
  fi

  echo "$next" > "$STATE_FILE"
  count=$next

  echo "---------- progress after cycle $next ----------"
  cat "$PROGRESS_FILE"
  echo
  echo "remaining targets after cycle $next: $remaining_after"
done
