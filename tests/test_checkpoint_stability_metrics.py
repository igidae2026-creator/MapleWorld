from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
import unittest


ROOT_DIR = Path(__file__).resolve().parents[1]
OUTPUT_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs" / "checkpoint_stability_latest.json"

EXPECTED_CHECKPOINTS = {
    "world_stability",
    "player_flow_stability",
    "economy_stability",
    "meta_stability",
    "content_scale_out_stability",
    "liveops_override_safety",
}


class CheckpointStabilityMetricsTest(unittest.TestCase):
    def test_checkpoint_metrics_generate_output(self) -> None:
        subprocess.run(["lua", "simulation_lua/run_all.lua"], cwd=ROOT_DIR, check=True)
        subprocess.run([sys.executable, "simulation_py/run_all.py"], cwd=ROOT_DIR, check=True)
        subprocess.run([sys.executable, "metrics_engine/run_quality_eval.py"], cwd=ROOT_DIR, check=True)

        payload = json.loads(OUTPUT_PATH.read_text(encoding="utf-8"))
        self.assertIn(payload["status"], {"stable", "unstable"})
        self.assertEqual(set(payload["checkpoints"].keys()), EXPECTED_CHECKPOINTS)
        for checkpoint in EXPECTED_CHECKPOINTS:
            row = payload["checkpoints"][checkpoint]
            self.assertIn(row["status"], {"stable", "unstable"})
            self.assertGreaterEqual(float(row["score"]), 0.0)
            self.assertLessEqual(float(row["score"]), 1.0)


if __name__ == "__main__":
    unittest.main()
