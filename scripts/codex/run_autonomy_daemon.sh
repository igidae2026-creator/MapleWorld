#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATE_DIR="$ROOT_DIR/offline_ops/codex_state/autonomy_daemon"
LOG_DIR="$STATE_DIR/logs"
mkdir -p "$LOG_DIR"

SLEEP_SECONDS="${SLEEP_SECONDS:-15}"
MAX_CYCLES_PER_RUN="${MAX_CYCLES_PER_RUN:-1}"
SUPERVISOR_SWEEPS_PER_RUN="${SUPERVISOR_SWEEPS_PER_RUN:-8}"

run_supervisor_until_idle() {
  local sweep=0
  while [ "$sweep" -lt "$SUPERVISOR_SWEEPS_PER_RUN" ]
  do
    sweep=$((sweep + 1))
    local result
    result="$(python3 -m offline_ops.autonomy.supervisor run-once --worker-id "autonomy-daemon-${RUN_ID}-${sweep}")"
    printf '%s\n' "$result"
    if printf '%s' "$result" | rg -q '"status": "idle"'; then
      break
    fi
  done
}

while true
do
  RUN_ID="$(date +%Y%m%d_%H%M%S)"
  LOG_PATH="$LOG_DIR/run_${RUN_ID}.log"
  STATUS_PATH="$STATE_DIR/last_status.json"

  printf '{\n  "run_id": "%s",\n  "status": "running",\n  "log_path": "%s"\n}\n' "$RUN_ID" "$LOG_PATH" > "$STATUS_PATH"

  {
    echo "[${RUN_ID}] starting"
    cd "$ROOT_DIR"
    run_supervisor_until_idle
    MAX_CYCLES="$MAX_CYCLES_PER_RUN" bash auto_continue.sh
    python3 scripts/snapshot_metaos_aux_artifacts.py
    python3 scripts/run_repo_surface_audit.py
    python3 scripts/run_content_authenticity_audit.py
    python3 scripts/run_gameplay_depth_audit.py
    python3 scripts/run_coverage_conflict_audit.py
    python3 scripts/run_autonomy_thresholds.py
    python3 scripts/run_final_threshold_eval.py
    run_supervisor_until_idle
    echo "[${RUN_ID}] completed"
  } >"$LOG_PATH" 2>&1 || {
    printf '{\n  "run_id": "%s",\n  "status": "failed",\n  "log_path": "%s"\n}\n' "$RUN_ID" "$LOG_PATH" > "$STATUS_PATH"
    sleep "$SLEEP_SECONDS"
    continue
  }

  printf '{\n  "run_id": "%s",\n  "status": "completed",\n  "log_path": "%s"\n}\n' "$RUN_ID" "$LOG_PATH" > "$STATUS_PATH"
  sleep "$SLEEP_SECONDS"
done
