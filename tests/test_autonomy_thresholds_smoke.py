from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
import unittest


ROOT_DIR = Path(__file__).resolve().parents[1]
STATUS_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "thresholds" / "latest_status.json"


class AutonomyThresholdsSmokeTest(unittest.TestCase):
    def test_threshold_status_is_generated(self) -> None:
        subprocess.run([sys.executable, "scripts/snapshot_metaos_aux_artifacts.py"], cwd=ROOT_DIR, check=True)
        subprocess.run([sys.executable, "scripts/run_autonomy_thresholds.py"], cwd=ROOT_DIR, check=True)
        payload = json.loads(STATUS_PATH.read_text(encoding="utf-8"))
        self.assertIn("thresholds", payload)
        self.assertIn("status", payload)
        self.assertIn("components", payload)
        self.assertIn("execution", payload["thresholds"])
        self.assertIn("final", payload["thresholds"])
        self.assertIn("final_threshold_met", payload["status"])
        self.assertIn("human_lift_proximity", payload["components"]["final"])


if __name__ == "__main__":
    unittest.main()
