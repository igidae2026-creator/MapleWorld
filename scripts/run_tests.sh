#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

python3 ai_evolution_offline/codex/validate_top_skeleton.py

lua simulation_lua/run_all.lua
python3 simulation_py/run_all.py
python3 metrics_engine/run_quality_eval.py

lua tests/content_integrity_test.lua
lua tests/regional_progression_tables_test.lua
lua tests/msw_runtime_boundary_test.lua
lua tests/msw_runtime_transitive_boundary_test.lua
lua tests/msw_runtime_gameplay_test.lua
lua tests/msw_runtime_progression_test.lua
lua tests/boss_reward_distribution_test.lua
lua tests/economy_balance_table_test.lua
lua tests/economy_runtime_invariant_test.lua
lua tests/simulation_lua_smoke_test.lua
python3 tests/test_simulation_py_smoke.py
python3 tests/test_quality_metrics_smoke.py
python3 tests/test_top_skeleton_validator.py
python3 tests/test_liveops_override_metrics.py
python3 tests/test_checkpoint_stability_metrics.py
python3 tests/test_checkpoint_autonomy_smoke.py
python3 tests/test_autonomy_thresholds_smoke.py
python3 tests/test_final_threshold_eval_smoke.py
python3 tests/test_final_threshold_repair_flow.py
python3 tests/test_coverage_conflict_audit_smoke.py
python3 tests/test_fun_variance_guard.py
python3 tests/test_mvp_stabilizer_guards.py
python3 tests/test_drop_ladder_metrics.py
python3 tests/test_early_progression_metrics.py
python3 tests/test_economy_pressure_metrics.py
python3 tests/test_early02_rebalance_search.py
python3 tests/test_next_map_rebalance_search.py
python3 tests/test_player_experience_metrics.py
python3 tests/test_canon_lock_guard.py
python3 tests/test_agent5_economy_prompt_smoke.py
python3 tests/test_agent6_content_prompt_smoke.py
