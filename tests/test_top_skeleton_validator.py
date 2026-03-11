from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
import unittest


ROOT_DIR = Path(__file__).resolve().parents[1]


class TopSkeletonValidatorTest(unittest.TestCase):
    def test_top_skeleton_validator_passes(self) -> None:
        subprocess.run([sys.executable, "metrics_engine/run_quality_eval.py"], cwd=ROOT_DIR, check=True)
        subprocess.run([sys.executable, "scripts/run_coverage_conflict_audit.py"], cwd=ROOT_DIR, check=True)
        subprocess.run([sys.executable, "scripts/run_autonomy_thresholds.py"], cwd=ROOT_DIR, check=True)
        subprocess.run([sys.executable, "scripts/run_final_threshold_eval.py"], cwd=ROOT_DIR, check=True)
        result = subprocess.run(
            [sys.executable, "ai_evolution_offline/codex/validate_top_skeleton.py"],
            cwd=ROOT_DIR,
            check=True,
            capture_output=True,
            text=True,
        )
        payload = json.loads(result.stdout)
        self.assertEqual(payload["status"], "PASS")
        self.assertIn("final_threshold_bundle_contract", {item["code"] for item in payload["checks"]})


if __name__ == "__main__":
    unittest.main()
