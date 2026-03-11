from __future__ import annotations

import tempfile
from pathlib import Path
import unittest


ROOT_DIR = Path(__file__).resolve().parents[1]

import sys

sys.path.insert(0, str(ROOT_DIR / "metrics_engine"))

from mvp_stability import compute_drop_ladder_metrics, load_drop_rows


class DropLadderMetricsTest(unittest.TestCase):
    def test_repository_drop_ladder_passes(self) -> None:
        payload = compute_drop_ladder_metrics(load_drop_rows())
        self.assertEqual(payload["status"], "allow")
        self.assertRegex(payload["drop_excitement_score"], r"^\d+~\d+$")

    def test_low_boss_ceiling_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            path = Path(tmp_dir) / "drop_table.csv"
            path.write_text(
                "\n".join(
                    [
                        "monster_id,item_id,drop_profile,rarity_band,drop_rate,reward_identity,drop_tier",
                        "field_1,item_1,starter,common,0.3,currency,tier1",
                        "field_2,item_2,starter,common,0.3,utility,tier1",
                        "boss_1,item_3,boss,boss,0.01,rare,tier2",
                    ]
                )
                + "\n",
                encoding="utf-8",
            )
            payload = compute_drop_ladder_metrics(load_drop_rows(path))
            self.assertEqual(payload["status"], "reject")


if __name__ == "__main__":
    unittest.main()
