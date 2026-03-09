#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROMPTS_DIR="$ROOT_DIR/ai_evolution_offline/prompts"
LOOP_DIR="$ROOT_DIR/offline_ops/codex_state/bottleneck_loop"
SNAPSHOT_DIR="$ROOT_DIR/offline_ops/codex_state/snapshots"
STATE_FILE="$LOOP_DIR/loop_state.env"
FAILURE_LOG="$LOOP_DIR/failures.log"
VERIFY_DONE_FILE="$LOOP_DIR/verify_done"
CHECKPOINT_READY_FILE="$LOOP_DIR/checkpoint_ready"
CHECKPOINT_LOG="$LOOP_DIR/checkpoints.log"
SIMULATION_RUNS_DIR="$ROOT_DIR/offline_ops/codex_state/simulation_runs"

MAX_REPEATED_BOTTLENECKS="${MAX_REPEATED_BOTTLENECKS:-3}"
MAX_FAILING_PATCH_CYCLES="${MAX_FAILING_PATCH_CYCLES:-3}"
MAX_REGRESSION_CYCLES="${MAX_REGRESSION_CYCLES:-1}"
MAX_FAKE_PROGRESS_CYCLES="${MAX_FAKE_PROGRESS_CYCLES:-1}"
MAX_PATCH_FILES="${MAX_PATCH_FILES:-4}"
MAX_PATCH_ROOTS="${MAX_PATCH_ROOTS:-2}"
COORDINATOR_RETRY_LIMIT="${COORDINATOR_RETRY_LIMIT:-1}"
MAX_CYCLES="${MAX_CYCLES:-}"

mkdir -p "$LOOP_DIR" "$SNAPSHOT_DIR"

if [ -f "$STATE_FILE" ]; then
  # shellcheck disable=SC1090
  . "$STATE_FILE"
fi

LAST_BOTTLENECK="${LAST_BOTTLENECK:-}"
REPEATED_BOTTLENECK_COUNT="${REPEATED_BOTTLENECK_COUNT:-0}"
FAILING_PATCH_CYCLES="${FAILING_PATCH_CYCLES:-0}"
REGRESSION_CYCLES="${REGRESSION_CYCLES:-0}"
CYCLE_COUNTER="${CYCLE_COUNTER:-0}"
FAKE_PROGRESS_CYCLES="${FAKE_PROGRESS_CYCLES:-0}"
LAST_SUCCESSFUL_BOTTLENECK="${LAST_SUCCESSFUL_BOTTLENECK:-}"
LAST_SUCCESS_EFFICIENCY_ESTIMATE="${LAST_SUCCESS_EFFICIENCY_ESTIMATE:-}"
LAST_SUCCESS_PATCH_FILES_COUNT="${LAST_SUCCESS_PATCH_FILES_COUNT:-0}"

persist_state() {
  cat > "$STATE_FILE" <<EOF
LAST_BOTTLENECK=$(printf '%q' "$LAST_BOTTLENECK")
REPEATED_BOTTLENECK_COUNT=$REPEATED_BOTTLENECK_COUNT
FAILING_PATCH_CYCLES=$FAILING_PATCH_CYCLES
REGRESSION_CYCLES=$REGRESSION_CYCLES
CYCLE_COUNTER=$CYCLE_COUNTER
FAKE_PROGRESS_CYCLES=$FAKE_PROGRESS_CYCLES
LAST_SUCCESSFUL_BOTTLENECK=$(printf '%q' "$LAST_SUCCESSFUL_BOTTLENECK")
LAST_SUCCESS_EFFICIENCY_ESTIMATE=$(printf '%q' "$LAST_SUCCESS_EFFICIENCY_ESTIMATE")
LAST_SUCCESS_PATCH_FILES_COUNT=$LAST_SUCCESS_PATCH_FILES_COUNT
EOF
}

record_failure() {
  local cycle_id="$1"
  local reason="$2"
  local details_file="$3"
  {
    printf '[%s] cycle=%s reason=%s\n' "$(date +%Y-%m-%dT%H:%M:%S%z)" "$cycle_id" "$reason"
    if [ -n "$details_file" ] && [ -f "$details_file" ]; then
      sed -n '1,120p' "$details_file"
    fi
    printf '\n'
  } >> "$FAILURE_LOG"
}

run_standard_tests() {
  if command -v make >/dev/null 2>&1; then
    make test
  else
    bash "$ROOT_DIR/scripts/run_tests.sh"
  fi
}

run_simulation_pipeline() {
  mkdir -p "$SIMULATION_RUNS_DIR"
  lua "$ROOT_DIR/simulation_lua/run_all.lua"
  python3 "$ROOT_DIR/simulation_py/run_all.py"
  python3 "$ROOT_DIR/metrics_engine/run_quality_eval.py"
}

ensure_simulation_outputs() {
  [ -f "$SIMULATION_RUNS_DIR/lua_simulation_latest.json" ] \
    && [ -f "$SIMULATION_RUNS_DIR/python_simulation_latest.json" ] \
    && [ -f "$SIMULATION_RUNS_DIR/quality_metrics_latest.json" ]
}

clear_cycle_signals() {
  rm -f "$VERIFY_DONE_FILE" "$CHECKPOINT_READY_FILE"
}

record_checkpoint() {
  local cycle_id="$1"
  local timestamp="$2"
  local verify_status="$3"
  {
    printf '[%s] cycle=%s' "$timestamp" "$CYCLE_COUNTER"
    if [ -n "$CHOSEN_BOTTLENECK" ]; then
      printf ' bottleneck=%s' "$CHOSEN_BOTTLENECK"
    fi
    if [ -n "$PATCH_LOG" ]; then
      printf ' patch=%s' "$(basename "$PATCH_LOG")"
    fi
    printf ' verify=%s cycle_id=%s\n' "$verify_status" "$cycle_id"
  } >> "$CHECKPOINT_LOG"
}

snapshot_repo() {
  local cycle_id="$1"
  local snapshot_tar="$SNAPSHOT_DIR/snapshot_${cycle_id}.tar.gz"
  local snapshot_files="$SNAPSHOT_DIR/${cycle_id}.files"
  (
    cd "$ROOT_DIR"
    find . \
      -path './.git' -prune -o \
      -path './offline_ops/codex_state/snapshots' -prune -o \
      -type f -print | LC_ALL=C sort > "$snapshot_files"
    tar -czf "$snapshot_tar" \
      --exclude='./offline_ops/codex_state/snapshots' \
      --exclude='./.git' \
      .
  )
}

restore_snapshot() {
  local cycle_id="$1"
  local snapshot_tar="$SNAPSHOT_DIR/snapshot_${cycle_id}.tar.gz"
  local snapshot_files="$SNAPSHOT_DIR/${cycle_id}.files"
  local current_files="$SNAPSHOT_DIR/${cycle_id}.restore.files"

  (
    cd "$ROOT_DIR"
    tar -xzf "$snapshot_tar"
    find . \
      -path './.git' -prune -o \
      -path './offline_ops/codex_state/snapshots' -prune -o \
      -type f -print | LC_ALL=C sort > "$current_files"
  )

  if [ -f "$snapshot_files" ] && [ -f "$current_files" ]; then
    while IFS= read -r extra_file; do
      rm -f "$ROOT_DIR/${extra_file#./}"
    done < <(comm -13 "$snapshot_files" "$current_files")
  fi
}

extract_bottleneck() {
  awk '
    /^CHOSEN_BOTTLENECK:$/ { capture=1; next }
    capture == 1 {
      if ($0 == "") exit
      print
      exit
    }
  ' "$LOOP_DIR/decision.txt"
}

extract_efficiency_estimate() {
  awk '
    /^CURRENT_EFFICIENCY_ESTIMATE:$/ { capture=1; next }
    capture == 1 {
      if ($0 == "") exit
      print
      exit
    }
  ' "$LOOP_DIR/decision.txt"
}

extract_decision_files() {
  awk '
    /^FILES:$/ { capture=1; next }
    /^PATCH_BOUNDARY:$/ { capture=0 }
    capture == 1 && $0 ~ /^- / {
      line=$0
      sub(/^- /, "", line)
      gsub(/`/, "", line)
      print line
    }
  ' "$LOOP_DIR/decision.txt"
}

build_coordinator_input() {
  local rejection_reason="$1"
  cat "$PROMPTS_DIR/coordinator.txt"
  if [ -n "$rejection_reason" ]; then
    printf "\n\nDecision validation feedback:\n"
    printf "The previous coordinator output was rejected for this reason: %s\n" "$rejection_reason"
    printf "Produce a narrower, valid bottleneck that stays within one bounded patch.\n"
  fi
  printf "\n\nAgent outputs:\n\n"
  printf "=== Agent 1 ===\n"
  cat "$LOOP_DIR/agent1.txt"
  printf "\n\n=== Agent 2 ===\n"
  cat "$LOOP_DIR/agent2.txt"
  printf "\n\n=== Agent 3 ===\n"
  cat "$LOOP_DIR/agent3.txt"
  printf "\n\n=== Agent 4 ===\n"
  cat "$LOOP_DIR/agent4.txt"
  printf "\n\n=== Agent 5 ===\n"
  cat "$LOOP_DIR/agent5.txt"
  printf "\n\n=== Agent 6 ===\n"
  cat "$LOOP_DIR/agent6.txt"
  printf "\n\n=== Agent 7 ===\n"
  cat "$LOOP_DIR/agent7.txt"
  printf "\n\n=== Agent 8 ===\n"
  cat "$LOOP_DIR/agent8.txt"
  printf "\n"
}

run_coordinator() {
  local rejection_reason="$1"
  build_coordinator_input "$rejection_reason" | codex exec -C "$ROOT_DIR" --output-last-message "$LOOP_DIR/decision.txt" -
}

build_fun_guard_input() {
  cat "$PROMPTS_DIR/agent9_fun_guard.txt"
  printf "\n\nCoordinator decision:\n\n"
  cat "$LOOP_DIR/decision.txt"
  printf "\n"
}

run_fun_guard_agent() {
  build_fun_guard_input | codex exec -C "$ROOT_DIR" --output-last-message "$LOOP_DIR/agent9.txt" -
}

extract_patch_veto() {
  awk '
    /^PATCH_VETO[[:space:]]*=/ {
      value=$0
      sub(/^PATCH_VETO[[:space:]]*=[[:space:]]*/, "", value)
      print value
      exit
    }
    /^PATCH_VETO:$/ { capture=1; next }
    capture == 1 {
      if ($0 == "") exit
      print
      exit
    }
  ' "$LOOP_DIR/agent9.txt"
}

validate_decision() {
  local chosen_bottleneck="$1"
  local efficiency_estimate="$2"
  local decision_files=("$@")
  local file_count top_level_roots path root
  local -A unique_roots=()

  decision_files=("${decision_files[@]:2}")
  file_count="${#decision_files[@]}"

  if [ -z "$chosen_bottleneck" ]; then
    printf '%s' "missing chosen bottleneck"
    return 0
  fi
  if [ "$file_count" -eq 0 ]; then
    printf '%s' "missing patch file list"
    return 0
  fi
  if [ "$file_count" -gt "$MAX_PATCH_FILES" ]; then
    printf '%s' "patch scope exceeds allowed boundary (${file_count} files > ${MAX_PATCH_FILES})"
    return 0
  fi

  for path in "${decision_files[@]}"; do
    if [[ "$path" == *"*"* ]]; then
      printf '%s' "patch scope contains wildcard path: $path"
      return 0
    fi
    if [ -d "$ROOT_DIR/$path" ]; then
      printf '%s' "patch scope contains directory instead of file: $path"
      return 0
    fi
    root="${path%%/*}"
    if [[ -n "$root" ]]; then
      unique_roots["$root"]=1
    fi
  done

  top_level_roots=0
  for root in "${!unique_roots[@]}"; do
    top_level_roots=$((top_level_roots + 1))
  done
  if [ "$top_level_roots" -gt "$MAX_PATCH_ROOTS" ]; then
    printf '%s' "patch scope spans too many top-level areas (${top_level_roots} > ${MAX_PATCH_ROOTS})"
    return 0
  fi

  if [ -n "$LAST_SUCCESSFUL_BOTTLENECK" ] && \
     [ "$chosen_bottleneck" = "$LAST_SUCCESSFUL_BOTTLENECK" ] && \
     [ -n "$efficiency_estimate" ] && \
     [ "$efficiency_estimate" = "$LAST_SUCCESS_EFFICIENCY_ESTIMATE" ] && \
     [ "$LAST_SUCCESS_PATCH_FILES_COUNT" -gt 0 ]; then
    printf '%s' "fake progress detected: bottleneck and efficiency estimate are unchanged from the prior successful cycle"
    return 0
  fi

  return 1
}

should_stop_for_repetition() {
  local bottleneck="$1"
  if [ "$bottleneck" = "$LAST_BOTTLENECK" ]; then
    REPEATED_BOTTLENECK_COUNT=$((REPEATED_BOTTLENECK_COUNT + 1))
  else
    LAST_BOTTLENECK="$bottleneck"
    REPEATED_BOTTLENECK_COUNT=1
  fi
  persist_state
  [ "$REPEATED_BOTTLENECK_COUNT" -ge "$MAX_REPEATED_BOTTLENECKS" ]
}

while true
do
  if [ -n "$MAX_CYCLES" ] && [ "$CYCLE_COUNTER" -ge "$MAX_CYCLES" ]; then
    echo "Max cycle limit reached. Stopping loop."
    exit 0
  fi

  CYCLE_COUNTER=$((CYCLE_COUNTER + 1))
  clear_cycle_signals
  persist_state
  CYCLE_ID="$(date +%Y%m%d_%H%M%S)_${CYCLE_COUNTER}"
  PRECHECK_LOG="$LOOP_DIR/precheck_${CYCLE_ID}.log"
  PATCH_LOG="$LOOP_DIR/patch_${CYCLE_ID}.txt"
  PATCH_STDOUT_LOG="$LOOP_DIR/patch_stdout_${CYCLE_ID}.log"
  VERIFY_LOG="$LOOP_DIR/verify_${CYCLE_ID}.log"
  SIMULATION_LOG="$LOOP_DIR/simulation_${CYCLE_ID}.log"

  echo "=== PRECHECK ==="
  if ! run_standard_tests > "$PRECHECK_LOG" 2>&1; then
    REGRESSION_CYCLES=$((REGRESSION_CYCLES + 1))
    persist_state
    record_failure "$CYCLE_ID" "precheck_regression" "$PRECHECK_LOG"
    echo "Precheck regression detected. Stopping loop."
    exit 1
  fi

  echo "=== SIMULATION ==="
  if ! run_simulation_pipeline > "$SIMULATION_LOG" 2>&1 || ! ensure_simulation_outputs; then
    REGRESSION_CYCLES=$((REGRESSION_CYCLES + 1))
    persist_state
    record_failure "$CYCLE_ID" "simulation_pipeline_failed" "$SIMULATION_LOG"
    echo "Simulation pipeline failed. Stopping loop."
    exit 1
  fi

  echo "=== AGENT 1 ==="
  codex exec -C "$ROOT_DIR" --output-last-message "$LOOP_DIR/agent1.txt" - < "$PROMPTS_DIR/agent1_architecture.txt"

  echo "=== AGENT 2 ==="
  codex exec -C "$ROOT_DIR" --output-last-message "$LOOP_DIR/agent2.txt" - < "$PROMPTS_DIR/agent2_gameplay.txt"

  echo "=== AGENT 3 ==="
  codex exec -C "$ROOT_DIR" --output-last-message "$LOOP_DIR/agent3.txt" - < "$PROMPTS_DIR/agent3_rules_content.txt"

  echo "=== AGENT 4 ==="
  codex exec -C "$ROOT_DIR" --output-last-message "$LOOP_DIR/agent4.txt" - < "$PROMPTS_DIR/agent4_validation.txt"

  echo "=== AGENT 5 ==="
  codex exec -C "$ROOT_DIR" --output-last-message "$LOOP_DIR/agent5.txt" - < "$PROMPTS_DIR/agent5_economy.txt"

  echo "=== AGENT 6 ==="
  codex exec -C "$ROOT_DIR" --output-last-message "$LOOP_DIR/agent6.txt" - < "$PROMPTS_DIR/agent6_content.txt"

  echo "=== AGENT 7 ==="
  codex exec -C "$ROOT_DIR" --output-last-message "$LOOP_DIR/agent7.txt" - < "$PROMPTS_DIR/agent7_simulation.txt"

  echo "=== AGENT 8 ==="
  codex exec -C "$ROOT_DIR" --output-last-message "$LOOP_DIR/agent8.txt" - < "$PROMPTS_DIR/agent8_meta_quality.txt"

  echo "=== COORDINATOR ==="
  run_coordinator ""

  DECISION_RETRY_COUNT=0
  while true
  do
    CHOSEN_BOTTLENECK="$(extract_bottleneck)"
    CURRENT_EFFICIENCY_ESTIMATE="$(extract_efficiency_estimate)"
    mapfile -t DECISION_FILES < <(extract_decision_files)
    if DECISION_REJECTION_REASON="$(validate_decision "$CHOSEN_BOTTLENECK" "$CURRENT_EFFICIENCY_ESTIMATE" "${DECISION_FILES[@]}")"; then
      if [[ "$DECISION_REJECTION_REASON" == fake\ progress* ]]; then
        FAKE_PROGRESS_CYCLES=$((FAKE_PROGRESS_CYCLES + 1))
        persist_state
      fi
      if [ "$DECISION_RETRY_COUNT" -ge "$COORDINATOR_RETRY_LIMIT" ]; then
        record_failure "$CYCLE_ID" "invalid_decision:${DECISION_REJECTION_REASON}" "$LOOP_DIR/decision.txt"
        if [ "$FAKE_PROGRESS_CYCLES" -ge "$MAX_FAKE_PROGRESS_CYCLES" ]; then
          echo "Fake progress threshold reached. Stopping loop."
          exit 1
        fi
        continue 2
      fi
      DECISION_RETRY_COUNT=$((DECISION_RETRY_COUNT + 1))
      run_coordinator "$DECISION_REJECTION_REASON"
      continue
    fi
    echo "=== AGENT 9 ==="
    run_fun_guard_agent
    PATCH_VETO="$(extract_patch_veto)"
    if [ "$PATCH_VETO" = "reject" ]; then
      DECISION_REJECTION_REASON="fun guard veto: proposed stability gain harms variance, memorable rewards, canon texture, or map-role separation"
      if [ "$DECISION_RETRY_COUNT" -ge "$COORDINATOR_RETRY_LIMIT" ]; then
        record_failure "$CYCLE_ID" "invalid_decision:${DECISION_REJECTION_REASON}" "$LOOP_DIR/agent9.txt"
        continue 2
      fi
      DECISION_RETRY_COUNT=$((DECISION_RETRY_COUNT + 1))
      run_coordinator "$DECISION_REJECTION_REASON"
      continue
    fi
    break
  done

  if should_stop_for_repetition "$CHOSEN_BOTTLENECK"; then
    record_failure "$CYCLE_ID" "repeated_bottleneck" "$LOOP_DIR/decision.txt"
    echo "Repeated bottleneck threshold reached. Stopping loop."
    exit 1
  fi

  echo "=== PATCH ==="
  snapshot_repo "$CYCLE_ID"
  set +e
  {
    cat "$PROMPTS_DIR/apply_patch.txt"
    printf "\n\nCoordinator decision:\n\n"
    cat "$LOOP_DIR/decision.txt"
    printf "\n"
  } | codex exec -C "$ROOT_DIR" --output-last-message "$PATCH_LOG" - > "$PATCH_STDOUT_LOG" 2>&1
  PATCH_EXIT=$?
  set -e

  if [ "$PATCH_EXIT" -ne 0 ]; then
    FAILING_PATCH_CYCLES=$((FAILING_PATCH_CYCLES + 1))
    persist_state
    restore_snapshot "$CYCLE_ID"
    record_failure "$CYCLE_ID" "patch_execution_failed" "$PATCH_STDOUT_LOG"
    if [ "$FAILING_PATCH_CYCLES" -ge "$MAX_FAILING_PATCH_CYCLES" ]; then
      echo "Patch failure threshold reached. Stopping loop."
      exit 1
    fi
    continue
  fi

  if ! run_standard_tests > "$VERIFY_LOG" 2>&1; then
    FAILING_PATCH_CYCLES=$((FAILING_PATCH_CYCLES + 1))
    REGRESSION_CYCLES=$((REGRESSION_CYCLES + 1))
    persist_state
    restore_snapshot "$CYCLE_ID"
    record_failure "$CYCLE_ID" "post_patch_regression" "$VERIFY_LOG"
    if [ "$REGRESSION_CYCLES" -ge "$MAX_REGRESSION_CYCLES" ] || [ "$FAILING_PATCH_CYCLES" -ge "$MAX_FAILING_PATCH_CYCLES" ]; then
      echo "Regression threshold reached. Stopping loop."
      exit 1
    fi
    continue
  fi

  FAILING_PATCH_CYCLES=0
  REGRESSION_CYCLES=0
  FAKE_PROGRESS_CYCLES=0
  LAST_SUCCESSFUL_BOTTLENECK="$CHOSEN_BOTTLENECK"
  LAST_SUCCESS_EFFICIENCY_ESTIMATE="$CURRENT_EFFICIENCY_ESTIMATE"
  LAST_SUCCESS_PATCH_FILES_COUNT="${#DECISION_FILES[@]}"
  persist_state
  touch "$VERIFY_DONE_FILE"
  if [ ! -f "$VERIFY_DONE_FILE" ]; then
    record_failure "$CYCLE_ID" "missing_verify_done" "$VERIFY_LOG"
    echo "Verify completion signal missing. Stopping loop."
    exit 1
  fi
  cat "$PATCH_LOG"

  touch "$CHECKPOINT_READY_FILE"
  if [ ! -f "$CHECKPOINT_READY_FILE" ]; then
    record_failure "$CYCLE_ID" "missing_checkpoint_ready" "$VERIFY_LOG"
    echo "Checkpoint signal missing. Stopping loop."
    exit 1
  fi

  CYCLE_COMPLETED_AT="$(date +%Y-%m-%dT%H:%M:%S%z)"
  record_checkpoint "$CYCLE_ID" "$CYCLE_COMPLETED_AT" "passed"
  printf 'CYCLE_COMPLETE %s %s\n' "$CYCLE_COUNTER" "$CYCLE_COMPLETED_AT"
done
