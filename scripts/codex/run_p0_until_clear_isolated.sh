#!/usr/bin/env bash
set -euo pipefail

REPO="${HOME}/MapleWorld"
PROMPT_FILE="${REPO}/ops/prompts/p0_clear_prompt.txt"
BACKLOG_FILE="${REPO}/ops/codex_state/p0_clear_backlog.json"
STATE_FILE="${REPO}/ops/codex_state/p0_clear_counter.txt"
LOG_DIR="${REPO}/ops/codex_state/p0_clear_runs"
PROGRESS_FILE="${REPO}/ops/codex_state/p0_clear_progress.json"

mkdir -p "$LOG_DIR"
mkdir -p "$(dirname "$STATE_FILE")"

if [ ! -f "$STATE_FILE" ]; then
  echo 0 > "$STATE_FILE"
fi

count=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
count=${count:-0}

all_done() {
  python3 - "$BACKLOG_FILE" <<'PY'
import json, sys
with open(sys.argv[1], "r", encoding="utf-8") as f:
    data = json.load(f)
tasks = data.get("tasks", [])
pending = [t for t in tasks if t.get("status") == "pending"]
print("yes" if not pending else "no")
PY
}

next_task() {
  python3 - "$BACKLOG_FILE" <<'PY'
import json, sys
with open(sys.argv[1], "r", encoding="utf-8") as f:
    data = json.load(f)
for t in data.get("tasks", []):
    if t.get("status") == "pending":
        print(f'{t.get("id")}::{t.get("title")}')
        break
PY
}

while true; do
  done_flag=$(all_done)
  if [ "$done_flag" = "yes" ]; then
    echo "All isolated P0 tasks are completed or blocked."
    break
  fi

  next=$((count + 1))
  task_info=$(next_task)
  task_id="${task_info%%::*}"
  task_title="${task_info#*::}"

  echo "========== ISOLATED P0 RUN $next =========="
  echo "task: $task_id :: $task_title"

  codex exec --cd "$REPO" --full-auto < "$PROMPT_FILE" | tee "$LOG_DIR/run_${next}_${task_id}.log"

  echo "$next" > "$STATE_FILE"
  count=$next

  echo "---------- isolated progress after run $next ----------"
  [ -f "$PROGRESS_FILE" ] && cat "$PROGRESS_FILE"
  echo
done

echo "Completed isolated sequential P0 execution."
