from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
import unittest


ROOT_DIR = Path(__file__).resolve().parents[1]
REPORT_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs" / "next_map_rebalance_candidates.json"
ROLE_BANDS_PATH = ROOT_DIR / "data" / "balance" / "maps" / "role_bands.csv"


class NextMapRebalanceSearchTest(unittest.TestCase):
    def test_report_targets_non_early02_map(self) -> None:
        subprocess.run([sys.executable, "scripts/search_next_map_rebalance.py"], cwd=ROOT_DIR, check=True)
        payload = json.loads(REPORT_PATH.read_text(encoding="utf-8"))
        self.assertIn("target_map", payload)
        self.assertNotIn(payload["target_map"], {"perion_rockfall_edge", "ellinia_lower_canopy", "lith_harbor_coast_road"})
        self.assertIn(payload["recommendation"], {"use_best_candidate", "next-map rebalance exhausted", "no_next_map_candidate"})
        self.assertGreaterEqual(REPORT_PATH.stat().st_mtime, ROLE_BANDS_PATH.stat().st_mtime)


if __name__ == "__main__":
    unittest.main()
