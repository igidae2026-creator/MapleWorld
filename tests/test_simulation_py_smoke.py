from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
import unittest


ROOT_DIR = Path(__file__).resolve().parents[1]
OUTPUT_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs" / "python_simulation_latest.json"


class SimulationPySmokeTest(unittest.TestCase):
    def test_python_simulation_generates_output(self) -> None:
        subprocess.run([sys.executable, "simulation_py/run_all.py"], cwd=ROOT_DIR, check=True)
        payload = json.loads(OUTPUT_PATH.read_text(encoding="utf-8"))
        self.assertIn("economy", payload)
        self.assertIn("world", payload)
        self.assertIn("net_inflation_signal", payload["economy"])
        self.assertIn("economy_pressure_model", payload)
        self.assertIn("strategy_usage", payload["world"])
        self.assertIn("anchor_topology", payload["world"])


if __name__ == "__main__":
    unittest.main()
