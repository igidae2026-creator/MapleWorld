from __future__ import annotations

import json
from pathlib import Path

from quality_metrics import build_quality_metrics

ROOT_DIR = Path(__file__).resolve().parents[1]
RUNS_DIR = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs"
LUA_PATH = RUNS_DIR / "lua_simulation_latest.json"
PYTHON_PATH = RUNS_DIR / "python_simulation_latest.json"
OUTPUT_PATH = RUNS_DIR / "quality_metrics_latest.json"


def main() -> int:
    lua_data = json.loads(LUA_PATH.read_text(encoding="utf-8"))
    python_data = json.loads(PYTHON_PATH.read_text(encoding="utf-8"))
    payload = build_quality_metrics(lua_data, python_data)
    OUTPUT_PATH.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(OUTPUT_PATH)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
