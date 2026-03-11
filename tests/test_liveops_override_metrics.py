from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
import unittest


ROOT_DIR = Path(__file__).resolve().parents[1]
OUTPUT_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs" / "liveops_override_metrics_latest.json"


class LiveopsOverrideMetricsTest(unittest.TestCase):
    def test_liveops_override_metrics_generate_output(self) -> None:
        subprocess.run(["lua", "simulation_lua/run_all.lua"], cwd=ROOT_DIR, check=True)
        subprocess.run([sys.executable, "simulation_py/run_all.py"], cwd=ROOT_DIR, check=True)
        subprocess.run([sys.executable, "metrics_engine/run_quality_eval.py"], cwd=ROOT_DIR, check=True)

        payload = json.loads(OUTPUT_PATH.read_text(encoding="utf-8"))
        self.assertIn(payload["status"], {"allow", "reject"})
        self.assertIn("override_plane_score", payload)
        self.assertIn("rollback_readiness", payload)
        self.assertIn("policy_plane_coverage", payload)
        self.assertIn("adaptive_override_actions", payload)
        self.assertIn("intervention_profiles", payload)
        self.assertGreaterEqual(float(payload["override_plane_score"]), 0.0)
        self.assertLessEqual(float(payload["override_plane_score"]), 1.0)


if __name__ == "__main__":
    unittest.main()
