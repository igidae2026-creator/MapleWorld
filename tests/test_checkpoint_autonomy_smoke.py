from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
import unittest


ROOT_DIR = Path(__file__).resolve().parents[1]
SUMMARY_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs" / "checkpoint_reports" / "checkpoint_summary.json"


class CheckpointAutonomySmokeTest(unittest.TestCase):
    def test_checkpoint_autonomy_smoke(self) -> None:
        subprocess.run(
            [
                sys.executable,
                "scripts/run_checkpoint_autonomy.py",
                "--max-cycles",
                "2",
                "--required-streak",
                "1",
            ],
            cwd=ROOT_DIR,
            check=True,
        )

        payload = json.loads(SUMMARY_PATH.read_text(encoding="utf-8"))
        self.assertIn(payload["finished_reason"], {"all_checkpoints_stable", "max_cycles_reached"})
        self.assertIn("checkpoint_status", payload)
        self.assertEqual(len(payload["checkpoint_status"]), 6)


if __name__ == "__main__":
    unittest.main()
