from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
import unittest


ROOT_DIR = Path(__file__).resolve().parents[1]
REPORT_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs" / "cross_band_rebalance_candidates.json"


class CrossBandRebalanceSearchTest(unittest.TestCase):
    def test_search_generates_cross_band_report(self) -> None:
        subprocess.run([sys.executable, "scripts/search_cross_band_rebalance.py"], cwd=ROOT_DIR, check=True)
        payload = json.loads(REPORT_PATH.read_text(encoding="utf-8"))
        self.assertIn("baseline", payload)
        self.assertIn("candidate_count", payload)
        self.assertIn("recommendation", payload)
        self.assertIn("evaluated_targets", payload)
        self.assertIsInstance(payload["evaluated_targets"], list)
        self.assertGreaterEqual(len(payload["evaluated_targets"]), 2)
        self.assertIn(payload["recommendation"], {"use_best_candidate", "cross-band rebalance exhausted"})
        if payload["best_candidate"] is not None:
            self.assertIn("adjustments", payload["best_candidate"])
            self.assertGreaterEqual(len(payload["best_candidate"]["adjustments"]), 2)


if __name__ == "__main__":
    unittest.main()
