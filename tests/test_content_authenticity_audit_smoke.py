from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
import unittest


ROOT_DIR = Path(__file__).resolve().parents[1]
OUTPUT_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "governance" / "content_authenticity_status.json"


class ContentAuthenticityAuditSmokeTest(unittest.TestCase):
    def test_content_authenticity_audit_is_generated(self) -> None:
        subprocess.run([sys.executable, "scripts/run_content_authenticity_audit.py"], cwd=ROOT_DIR, check=True)
        payload = json.loads(OUTPUT_PATH.read_text(encoding="utf-8"))
        self.assertIn("status", payload)
        self.assertIn("ratios", payload)
        self.assertIn("blocking_hotspots", payload)
        self.assertIn("dialogue_placeholder_ratio", payload["ratios"])


if __name__ == "__main__":
    unittest.main()
