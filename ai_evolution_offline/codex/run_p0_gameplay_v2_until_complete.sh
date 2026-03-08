#!/usr/bin/env bash
set -euo pipefail

REPO="${HOME}/MapleWorld"
PROMPT_FILE="${REPO}/ai_evolution_offline/prompts/p0_gameplay_v2_completion_prompt.txt"
STATE_FILE="${REPO}/offline_ops/codex_state/p0_gameplay_v2_counter.txt"
PROGRESS_FILE="${REPO}/offline_ops/codex_state/p0_gameplay_v2_progress.json"
RUN_DIR="${REPO}/offline_ops/codex_state/p0_gameplay_v2_runs"
VALIDATOR="${REPO}/ai_evolution_offline/codex/validate_p0_gameplay_v2_progress.py"

mkdir -p "$RUN_DIR"
touch "$STATE_FILE"

count=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
count=${count:-0}

while true; do
  remaining=$("$VALIDATOR")

  if [ "$remaining" -eq 0 ]; then
    echo "P0 gameplay v2 completion achieved."
    break
  fi

  next=$((count + 1))

  echo "========== P0 GAMEPLAY V2 CYCLE $next =========="
  echo "remaining targets: $remaining"

  cp "$PROGRESS_FILE" "$RUN_DIR/progress_before_${next}.json"

  codex exec --cd "$REPO" --full-auto < "$PROMPT_FILE" \
    | tee "$RUN_DIR/run_${next}.log"

  if ! remaining_after=$("$VALIDATOR"); then
    echo "Progress schema invalid after cycle $next"
    cp "$RUN_DIR/progress_before_${next}.json" "$PROGRESS_FILE"
    exit 1
  fi

  if [ "$remaining_after" -ge "$remaining" ]; then
    echo "No validated progress after cycle $next; stopping to avoid an infinite loop."
    echo "before=$remaining after=$remaining_after"
    exit 2
  fi

  echo "$next" > "$STATE_FILE"
  count=$next

  echo "---------- progress after cycle $next ----------"
  cat "$PROGRESS_FILE"
  echo
  echo "remaining targets after cycle $next: $remaining_after"
done
