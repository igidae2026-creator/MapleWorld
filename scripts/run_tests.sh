#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

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
python3 tests/test_fun_variance_guard.py
python3 tests/test_canon_lock_guard.py
python3 tests/test_agent5_economy_prompt_smoke.py
python3 tests/test_agent6_content_prompt_smoke.py
