from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
import unittest


ROOT_DIR = Path(__file__).resolve().parents[1]
STATUS_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "governance" / "coverage_conflict_status.json"


class CoverageConflictAuditSmokeTest(unittest.TestCase):
    def test_governance_status_is_generated(self) -> None:
        subprocess.run([sys.executable, "scripts/run_coverage_conflict_audit.py"], cwd=ROOT_DIR, check=True)
        payload = json.loads(STATUS_PATH.read_text(encoding="utf-8"))
        self.assertIn("layer_status", payload)
        self.assertIn("A1_coverage_audit", payload["layer_status"])
        self.assertIn("A2_conflict_log", payload["layer_status"])


if __name__ == "__main__":
    unittest.main()
