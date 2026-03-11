from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
import unittest


ROOT_DIR = Path(__file__).resolve().parents[1]
OUTPUT_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "governance" / "gameplay_depth_status.json"


class GameplayDepthAuditSmokeTest(unittest.TestCase):
    def test_gameplay_depth_audit_is_generated(self) -> None:
        subprocess.run([sys.executable, "scripts/run_gameplay_depth_audit.py"], cwd=ROOT_DIR, check=True)
        payload = json.loads(OUTPUT_PATH.read_text(encoding="utf-8"))
        self.assertIn("status", payload)
        self.assertIn("metrics", payload)
        self.assertIn("thresholds", payload)
        self.assertIn("failures", payload)


if __name__ == "__main__":
    unittest.main()
