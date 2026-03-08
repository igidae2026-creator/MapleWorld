from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
import unittest


ROOT_DIR = Path(__file__).resolve().parents[1]
OUTPUT_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs" / "quality_metrics_latest.json"


class QualityMetricsSmokeTest(unittest.TestCase):
    def test_quality_metrics_generate_output(self) -> None:
        subprocess.run(["lua", "simulation_lua/run_all.lua"], cwd=ROOT_DIR, check=True)
        subprocess.run([sys.executable, "simulation_py/run_all.py"], cwd=ROOT_DIR, check=True)
        subprocess.run([sys.executable, "metrics_engine/run_quality_eval.py"], cwd=ROOT_DIR, check=True)
        payload = json.loads(OUTPUT_PATH.read_text(encoding="utf-8"))
        for key in (
            "combat_quality",
            "progression_pacing",
            "economy_stability",
            "content_pressure_proxy",
            "boss_quality_proxy",
            "overall_quality_estimate",
        ):
            self.assertIn(key, payload)
            self.assertRegex(payload[key], r"^\d+~\d+$")


if __name__ == "__main__":
    unittest.main()
