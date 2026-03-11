from __future__ import annotations

import csv
import tempfile
from pathlib import Path
import unittest


ROOT_DIR = Path(__file__).resolve().parents[1]

import sys

sys.path.insert(0, str(ROOT_DIR / "metrics_engine"))

from mvp_stability import compute_early_progression_metrics


def _load_level_rows() -> list[dict[str, str]]:
    path = ROOT_DIR / "data" / "balance" / "progression" / "level_curve.csv"
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


class EarlyProgressionMetricsTest(unittest.TestCase):
    def test_repository_early_progression_is_stable(self) -> None:
        payload = compute_early_progression_metrics(_load_level_rows())
        self.assertEqual(payload["status"], "allow")
        self.assertRegex(payload["early_progression_metric"], r"^\d+~\d+$")

    def test_power_spike_curve_is_flagged(self) -> None:
        rows = _load_level_rows()
        with tempfile.TemporaryDirectory() as tmp_dir:
            path = Path(tmp_dir) / "level_curve.csv"
            with path.open("w", newline="", encoding="utf-8") as handle:
                writer = csv.DictWriter(handle, fieldnames=["level", "exp_required"])
                writer.writeheader()
                for row in rows:
                    level = int(row["level"])
                    exp_required = int(row["exp_required"])
                    if 18 <= level <= 22:
                        exp_required *= 5
                    writer.writerow({"level": level, "exp_required": exp_required})
            with path.open(newline="", encoding="utf-8") as handle:
                payload = compute_early_progression_metrics(list(csv.DictReader(handle)))
            self.assertEqual(payload["status"], "reject")
            self.assertIn("power_spike_risk", payload["issues"])


if __name__ == "__main__":
    unittest.main()
