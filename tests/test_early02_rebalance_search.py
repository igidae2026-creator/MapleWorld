from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
import unittest


ROOT_DIR = Path(__file__).resolve().parents[1]
REPORT_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs" / "early02_rebalance_candidates.json"


class Early02RebalanceSearchTest(unittest.TestCase):
    def test_search_generates_candidate_report(self) -> None:
        subprocess.run([sys.executable, "scripts/search_early02_rebalance.py"], cwd=ROOT_DIR, check=True)
        payload = json.loads(REPORT_PATH.read_text(encoding="utf-8"))
        self.assertIn("baseline", payload)
        self.assertIn("candidate_count", payload)
        self.assertIn("recommendation", payload)
        self.assertIn("best_candidate", payload)
        if payload["best_candidate"] is not None:
            spreads = payload["best_candidate"]["early_02_spreads"]
            self.assertIn("lith_harbor_coast_road", payload["best_candidate"])
            self.assertIn("ellinia_lower_canopy", payload["best_candidate"])
            self.assertGreaterEqual(float(spreads["throughput_spread"]), 0.12)
            self.assertGreaterEqual(float(spreads["reward_spread"]), 0.14)


if __name__ == "__main__":
    unittest.main()
