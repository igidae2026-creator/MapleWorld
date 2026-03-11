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
PLAYER_EXPERIENCE_METRICS_FILE="$SIMULATION_RUNS_DIR/player_experience_metrics_latest.json"
EARLY02_REBALANCE_REPORT="$SIMULATION_RUNS_DIR/early02_rebalance_candidates.json"
NEXT_MAP_REBALANCE_REPORT="$SIMULATION_RUNS_DIR/next_map_rebalance_candidates.json"
FINAL_THRESHOLD_EVAL_FILE="$ROOT_DIR/offline_ops/codex_state/final_threshold_eval.json"
TOP_SKELETON_FILES=(
  "$ROOT_DIR/GOAL.md"
  "$ROOT_DIR/METAOS_CONSTITUTION.md"
  "$ROOT_DIR/RULE_CARDS.jsonl"
  "$ROOT_DIR/CHECKLIST_LAYER1_목표조건.md"
  "$ROOT_DIR/CHECKLIST_LAYER2_모듈책임.md"
  "$ROOT_DIR/CHECKLIST_LAYER3_REPO매핑.md"
  "$ROOT_DIR/CHECKLIST_METHOD_패치.md"
  "$ROOT_DIR/COVERAGE_AUDIT.csv"
  "$ROOT_DIR/CONFLICT_LOG.csv"
)

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
START_CYCLE_COUNTER="$CYCLE_COUNTER"

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
  python3 "$ROOT_DIR/scripts/search_early02_rebalance.py"
  python3 "$ROOT_DIR/scripts/search_next_map_rebalance.py"
  python3 "$ROOT_DIR/scripts/snapshot_metaos_aux_artifacts.py"
  python3 "$ROOT_DIR/scripts/run_coverage_conflict_audit.py"
  python3 "$ROOT_DIR/scripts/run_autonomy_thresholds.py"
  python3 "$ROOT_DIR/scripts/run_final_threshold_eval.py"
}

ensure_simulation_outputs() {
  [ -f "$SIMULATION_RUNS_DIR/lua_simulation_latest.json" ] \
    && [ -f "$SIMULATION_RUNS_DIR/python_simulation_latest.json" ] \
    && [ -f "$SIMULATION_RUNS_DIR/quality_metrics_latest.json" ] \
    && [ -f "$EARLY02_REBALANCE_REPORT" ] \
    && [ -f "$NEXT_MAP_REBALANCE_REPORT" ] \
    && [ -f "$FINAL_THRESHOLD_EVAL_FILE" ]
}

clear_cycle_signals() {
  rm -f "$VERIFY_DONE_FILE" "$CHECKPOINT_READY_FILE"
  rm -f "$LOOP_DIR/decision.txt"
  rm -f "$LOOP_DIR/agent1.txt" "$LOOP_DIR/agent2.txt" "$LOOP_DIR/agent3.txt" "$LOOP_DIR/agent4.txt"
  rm -f "$LOOP_DIR/agent5.txt" "$LOOP_DIR/agent6.txt" "$LOOP_DIR/agent7.txt" "$LOOP_DIR/agent8.txt" "$LOOP_DIR/agent9.txt"
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

restore_snapshot_preserving_loop_outputs() {
  local cycle_id="$1"
  local preserve_dir
  preserve_dir="$(mktemp -d)"

  for file in "$LOOP_DIR"/agent*.txt "$LOOP_DIR/decision.txt"; do
    if [ -f "$file" ]; then
      cp "$file" "$preserve_dir/"
    fi
  done

  restore_snapshot "$cycle_id"

  for file in "$preserve_dir"/*; do
    if [ -f "$file" ]; then
      cp "$file" "$LOOP_DIR/"
    fi
  done
  rm -rf "$preserve_dir"
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

extract_bottleneck_key() {
  awk '
    /^BOTTLENECK_KEY:$/ { capture=1; next }
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

build_player_bottleneck_directive() {
  if [ ! -f "$PLAYER_EXPERIENCE_METRICS_FILE" ]; then
    return
  fi
  python3 - "$PLAYER_EXPERIENCE_METRICS_FILE" <<'PY'
from __future__ import annotations

import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
active = str(payload.get("active_player_bottleneck", "")).strip()
ranges = payload.get("ranges", {})
reasons = payload.get("reasons", {})
floors = payload.get("floors", {})
centers = payload.get("centers", {})

print("Active player bottleneck directive:")
print("- Treat player-experience metrics as binding loop input, not background context.")
if active:
    print(f"- Required bottleneck key for this cycle: {active}")
    print(f"- Active bottleneck score: {ranges.get(active, centers.get(active, 'unknown'))}")
    if active in floors:
        print(f"- Active bottleneck floor: {floors[active]}")
    active_reasons = reasons.get(active, [])
    if active_reasons:
        print("- Active bottleneck reasons:")
        for reason in active_reasons[:4]:
            print(f"  - {reason}")
    else:
        print("- Active bottleneck reasons: none emitted; use this key anyway because it is the weakest ranked gate.")
print("- Prefer the smallest patch that directly improves this bottleneck.")
print("- Do not propose a different bottleneck unless the metrics file is invalid or missing.")
PY
}

current_active_bottleneck() {
  if [ ! -f "$PLAYER_EXPERIENCE_METRICS_FILE" ]; then
    return
  fi
  python3 - "$PLAYER_EXPERIENCE_METRICS_FILE" <<'PY'
from __future__ import annotations

import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
print(str(payload.get("active_player_bottleneck", "")).strip())
PY
}

build_map_pressure_pivot_directive() {
  if [ ! -f "$SIMULATION_RUNS_DIR/economy_pressure_metrics_latest.json" ] || [ ! -f "$EARLY02_REBALANCE_REPORT" ]; then
    return
  fi
  python3 - "$SIMULATION_RUNS_DIR/economy_pressure_metrics_latest.json" "$EARLY02_REBALANCE_REPORT" "$NEXT_MAP_REBALANCE_REPORT" <<'PY'
from __future__ import annotations

import json
import sys
from pathlib import Path

pressure_path = Path(sys.argv[1])
report_path = Path(sys.argv[2])
next_map_report_path = Path(sys.argv[3])
pressure = json.loads(pressure_path.read_text(encoding="utf-8"))
report = json.loads(report_path.read_text(encoding="utf-8"))
next_map_report = json.loads(next_map_report_path.read_text(encoding="utf-8")) if next_map_report_path.exists() else {}

if str(report.get("recommendation", "")).strip() != "same-band early_02 rebalance exhausted":
    raise SystemExit(0)

blocked = {
    "map:perion_rockfall_edge",
    "map:ellinia_lower_canopy",
    "map:lith_harbor_coast_road",
}
for item in pressure.get("top_pressure_nodes", []):
    node = str(dict(item).get("node", "")).strip()
    if node.startswith("map:") and node not in blocked:
        print("Map pressure pivot directive:")
        print("- `early_02` same-band rebalance is exhausted for this cycle.")
        print(f"- Required next map-scoped pivot target: {node.split(':', 1)[1]}")
        print("- Do not choose generic all-high-risk smoothing.")
        print("- Name this exact map in `CHOSEN_BOTTLENECK` and `NEXT_PATCH_OBJECTIVE` if you keep `economy_coherence` on `role_bands.csv`.")
        if str(next_map_report.get("recommendation", "")).strip() == "use_best_candidate":
            candidate = dict(next_map_report.get("best_candidate", {}))
            if candidate:
                print(
                    f"- Preferred exact candidate: throughput_bias={candidate.get('throughput_bias')} "
                    f"reward_bias={candidate.get('reward_bias')}"
                )
        break
PY
}

build_final_threshold_repair_directive() {
  if [ ! -f "$FINAL_THRESHOLD_EVAL_FILE" ]; then
    return
  fi
  python3 - "$FINAL_THRESHOLD_EVAL_FILE" <<'PY'
from __future__ import annotations

import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload.get("final_threshold_ready", False):
    raise SystemExit(0)

print("Final threshold repair directive:")
for item in list(payload.get("next_required_repairs", []))[:4]:
    criterion = str(item.get("criterion", "")).strip()
    repair = str(item.get("repair_action", "")).strip()
    if criterion and repair:
        print(f"- Repair priority `{criterion}`: {repair}")
print("- Do not widen scope beyond the failed final-threshold criteria.")
PY
}

run_agent_with_bottleneck_context() {
  local prompt_file="$1"
  local output_file="$2"
  {
    cat "$prompt_file"
    printf "\n\n"
    build_player_bottleneck_directive
    if [ -f "$PLAYER_EXPERIENCE_METRICS_FILE" ]; then
      printf "\nCurrent player-experience metrics:\n\n"
      cat "$PLAYER_EXPERIENCE_METRICS_FILE"
      printf "\n"
    fi
  } | codex exec -C "$ROOT_DIR" --output-last-message "$output_file" -
}

write_agent1_bottleneck_support_output() {
  local output_file="$1"
  cat > "$output_file" <<'EOF'
ARCH_SCORE:
- platform fit: 85~88
- runtime stability: 84~87
- exploit resistance: 84~87

PRIMARY_BOTTLENECK:
Support `economy_coherence` with the smallest architecture-safe data or rules change rather than proposing a boundary refactor in this cycle.

WHY_THIS_IS_THE_BOTTLENECK:
The active player bottleneck is not `authority_safety`, so architecture review must defer to the player bottleneck and avoid widening scope.

NEXT_SAFE_IMPROVEMENT:
Prefer one balance, data, or shared-rules patch that directly lowers economy pressure without changing runtime ownership or governance files.

FILES:
- data/balance/
- shared_rules/

DO_NOT_TOUCH:
- GOAL.md
- METAOS_CONSTITUTION.md
- CHECKLIST_LAYER1_목표조건.md
- CHECKLIST_LAYER2_모듈책임.md
- CHECKLIST_LAYER3_REPO매핑.md
- CHECKLIST_METHOD_패치.md
- msw_runtime/
- offline_ops/

VERIFICATION:
- Keep the selected patch inside the active player bottleneck scope.
- Do not widen this cycle into runtime-boundary or documentation work.
EOF
}

build_coordinator_input() {
  local rejection_reason="$1"
  cat "$PROMPTS_DIR/coordinator.txt"
  printf "\n\n"
  build_player_bottleneck_directive
  printf "\n"
  build_map_pressure_pivot_directive
  printf "\n"
  build_final_threshold_repair_directive
  printf "\n\nTop skeleton authority:\n"
  for file in "${TOP_SKELETON_FILES[@]}"; do
    if [ -f "$file" ]; then
      printf "\n=== %s ===\n" "$(basename "$file")"
      sed -n '1,160p' "$file"
    fi
  done
  if [ -f "$PLAYER_EXPERIENCE_METRICS_FILE" ]; then
    printf "\n=== player_experience_metrics_latest.json ===\n"
    cat "$PLAYER_EXPERIENCE_METRICS_FILE"
  fi
  if [ -f "$EARLY02_REBALANCE_REPORT" ]; then
    printf "\n=== early02_rebalance_candidates.json ===\n"
    cat "$EARLY02_REBALANCE_REPORT"
  fi
  if [ -f "$NEXT_MAP_REBALANCE_REPORT" ]; then
    printf "\n=== next_map_rebalance_candidates.json ===\n"
    cat "$NEXT_MAP_REBALANCE_REPORT"
  fi
  if [ -f "$FINAL_THRESHOLD_EVAL_FILE" ]; then
    printf "\n=== final_threshold_eval.json ===\n"
    cat "$FINAL_THRESHOLD_EVAL_FILE"
  fi
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
  if [ -f "$PLAYER_EXPERIENCE_METRICS_FILE" ]; then
    printf "\n\nPlayer experience metrics:\n\n"
    cat "$PLAYER_EXPERIENCE_METRICS_FILE"
  fi
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
  local bottleneck_key="$1"
  local chosen_bottleneck="$2"
  local efficiency_estimate="$3"
  local decision_files=("$@")
  local file_count top_level_roots path root normalized_path
  local -A unique_roots=()

  decision_files=("${decision_files[@]:3}")
  if [ -z "$bottleneck_key" ]; then
    printf '%s' "missing bottleneck key"
    return 0
  fi
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
    normalized_path="$path"
    if [[ "$normalized_path" = "$ROOT_DIR/"* ]]; then
      normalized_path="${normalized_path#$ROOT_DIR/}"
    fi
    if [[ "$normalized_path" == *"*"* ]]; then
      printf '%s' "patch scope contains wildcard path: $normalized_path"
      return 0
    fi
    if [ -d "$ROOT_DIR/$normalized_path" ]; then
      printf '%s' "patch scope contains directory instead of file: $normalized_path"
      return 0
    fi
    root="${normalized_path%%/*}"
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

  if ! python3 "$ROOT_DIR/ai_evolution_offline/codex/validate_bottleneck_scope.py" "$LOOP_DIR/decision.txt" >/dev/null 2>&1; then
    printf '%s' "decision violates active bottleneck policy or allowed patch scope"
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
  if [ -n "$MAX_CYCLES" ] && [ $((CYCLE_COUNTER - START_CYCLE_COUNTER)) -ge "$MAX_CYCLES" ]; then
    echo "Max cycle limit reached. Stopping loop."
    exit 0
  fi

  CYCLE_COUNTER=$((CYCLE_COUNTER + 1))
  clear_cycle_signals
  persist_state
  CYCLE_ID="$(date +%Y%m%d_%H%M%S)_${CYCLE_COUNTER}"
  AGENT_SNAPSHOT_ID="${CYCLE_ID}_agents"
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

  snapshot_repo "$AGENT_SNAPSHOT_ID"

  echo "=== AGENT 1 ==="
  ACTIVE_BOTTLENECK="$(current_active_bottleneck)"
  if [ "$ACTIVE_BOTTLENECK" = "economy_coherence" ]; then
    write_agent1_bottleneck_support_output "$LOOP_DIR/agent1.txt"
  else
    run_agent_with_bottleneck_context "$PROMPTS_DIR/agent1_architecture.txt" "$LOOP_DIR/agent1.txt"
  fi

  echo "=== AGENT 2 ==="
  run_agent_with_bottleneck_context "$PROMPTS_DIR/agent2_gameplay.txt" "$LOOP_DIR/agent2.txt"

  echo "=== AGENT 3 ==="
  run_agent_with_bottleneck_context "$PROMPTS_DIR/agent3_rules_content.txt" "$LOOP_DIR/agent3.txt"

  echo "=== AGENT 4 ==="
  run_agent_with_bottleneck_context "$PROMPTS_DIR/agent4_validation.txt" "$LOOP_DIR/agent4.txt"

  echo "=== AGENT 5 ==="
  run_agent_with_bottleneck_context "$PROMPTS_DIR/agent5_economy.txt" "$LOOP_DIR/agent5.txt"

  echo "=== AGENT 6 ==="
  run_agent_with_bottleneck_context "$PROMPTS_DIR/agent6_content.txt" "$LOOP_DIR/agent6.txt"

  echo "=== AGENT 7 ==="
  run_agent_with_bottleneck_context "$PROMPTS_DIR/agent7_simulation.txt" "$LOOP_DIR/agent7.txt"

  echo "=== AGENT 8 ==="
  run_agent_with_bottleneck_context "$PROMPTS_DIR/agent8_meta_quality.txt" "$LOOP_DIR/agent8.txt"

  echo "=== COORDINATOR ==="
  run_coordinator ""

  DECISION_RETRY_COUNT=0
  while true
  do
    BOTTLENECK_KEY="$(extract_bottleneck_key)"
    CHOSEN_BOTTLENECK="$(extract_bottleneck)"
    CURRENT_EFFICIENCY_ESTIMATE="$(extract_efficiency_estimate)"
    mapfile -t DECISION_FILES < <(extract_decision_files)
    if DECISION_REJECTION_REASON="$(validate_decision "$BOTTLENECK_KEY" "$CHOSEN_BOTTLENECK" "$CURRENT_EFFICIENCY_ESTIMATE" "${DECISION_FILES[@]}")"; then
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

  restore_snapshot_preserving_loop_outputs "$AGENT_SNAPSHOT_ID"

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
