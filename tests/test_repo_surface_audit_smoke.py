from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
import unittest


ROOT_DIR = Path(__file__).resolve().parents[1]
OUTPUT_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "governance" / "repo_surface_status.json"


class RepoSurfaceAuditSmokeTest(unittest.TestCase):
    def test_repo_surface_audit_is_generated(self) -> None:
        subprocess.run([sys.executable, "scripts/run_repo_surface_audit.py"], cwd=ROOT_DIR, check=True)
        payload = json.loads(OUTPUT_PATH.read_text(encoding="utf-8"))
        self.assertEqual(payload["status"], "pass")
        self.assertTrue(payload["checks"]["root_authority_surface_clean"])
        self.assertTrue(payload["checks"]["surface_groups_present"])
        self.assertTrue(payload["checks"]["document_buckets_present"])


if __name__ == "__main__":
    unittest.main()
