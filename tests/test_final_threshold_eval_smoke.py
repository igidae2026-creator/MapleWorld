from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
import unittest


ROOT_DIR = Path(__file__).resolve().parents[1]
OUTPUT_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "final_threshold_eval.json"


class FinalThresholdEvalSmokeTest(unittest.TestCase):
    def test_final_threshold_bundle_is_generated(self) -> None:
        subprocess.run([sys.executable, "scripts/snapshot_metaos_aux_artifacts.py"], cwd=ROOT_DIR, check=True)
        subprocess.run([sys.executable, "scripts/run_coverage_conflict_audit.py"], cwd=ROOT_DIR, check=True)
        subprocess.run([sys.executable, "scripts/run_autonomy_thresholds.py"], cwd=ROOT_DIR, check=True)
        subprocess.run([sys.executable, "scripts/run_final_threshold_eval.py"], cwd=ROOT_DIR, check=True)
        payload = json.loads(OUTPUT_PATH.read_text(encoding="utf-8"))
        self.assertIn("final_threshold_ready", payload)
        self.assertIn("failed_criteria", payload)
        self.assertIn("blocking_evidence", payload)
        self.assertIn("next_required_repairs", payload)
        self.assertIn("quality_lift_if_human_intervenes", payload)
        self.assertIn("criteria", payload)
        self.assertTrue(payload["final_threshold_ready"])


if __name__ == "__main__":
    unittest.main()
