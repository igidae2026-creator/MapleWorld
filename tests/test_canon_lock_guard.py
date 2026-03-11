from __future__ import annotations

import json
import tempfile
from dataclasses import replace
from pathlib import Path
import unittest


ROOT_DIR = Path(__file__).resolve().parents[1]

import sys

sys.path.insert(0, str(ROOT_DIR / "metrics_engine"))

from fun_guard_metrics import FunGuardSources, validate_canon_locks


class CanonLockGuardTest(unittest.TestCase):
    def test_locked_assets_are_present(self) -> None:
        payload = validate_canon_locks()
        self.assertEqual(payload["status"], "ok")
        self.assertEqual(payload["reasons"], [])

    def test_missing_locked_region_is_rejected(self) -> None:
        regional_text = (ROOT_DIR / "data" / "regional_progression_tables.lua").read_text(encoding="utf-8")
        stripped_text = regional_text.replace("{ id = 'henesys', range = { 1, 24 }, loop = 'introductory hunting, potion sustain, and first-job setup' },\n", "")
        with tempfile.TemporaryDirectory() as tmp_dir:
            regional_path = Path(tmp_dir) / "regional_progression_tables.lua"
            regional_path.write_text(stripped_text, encoding="utf-8")
            payload = validate_canon_locks(
                replace(
                    FunGuardSources.default(),
                    regional_progression_path=regional_path,
                )
            )
            self.assertEqual(payload["status"], "reject")
            self.assertIn("henesys", payload["missing"]["regions"])

    def test_missing_locked_reward_suffix_is_rejected(self) -> None:
        regional_text = (ROOT_DIR / "data" / "regional_progression_tables.lua").read_text(encoding="utf-8")
        stripped_text = regional_text.replace("reward = region.id .. '_boss_writ'", "reward = region.id .. '_boss_token'")
        with tempfile.TemporaryDirectory() as tmp_dir:
            regional_path = Path(tmp_dir) / "regional_progression_tables.lua"
            regional_path.write_text(stripped_text, encoding="utf-8")
            payload = validate_canon_locks(
                replace(
                    FunGuardSources.default(),
                    regional_progression_path=regional_path,
                )
            )
            self.assertEqual(payload["status"], "reject")
            self.assertIn("boss_writ", payload["missing"]["rewards"])

    def test_missing_locked_boss_is_rejected(self) -> None:
        runtime_text = (ROOT_DIR / "runtime_tables.lua").read_text(encoding="utf-8")
        stripped_text = runtime_text.replace("'mano', ", "")
        with tempfile.TemporaryDirectory() as tmp_dir:
            runtime_path = Path(tmp_dir) / "runtime_tables.lua"
            runtime_path.write_text(stripped_text, encoding="utf-8")
            payload = validate_canon_locks(
                replace(
                    FunGuardSources.default(),
                    runtime_tables_path=runtime_path,
                )
            )
            self.assertEqual(payload["status"], "reject")
            self.assertIn("mano", payload["missing"]["bosses"])

    def test_missing_locked_anchor_is_rejected(self) -> None:
        anchor_payload = json.loads((ROOT_DIR / "data" / "canon" / "canonical_anchors.json").read_text(encoding="utf-8"))
        anchor_payload["zones"].pop("starter_town", None)
        with tempfile.TemporaryDirectory() as tmp_dir:
            anchor_path = Path(tmp_dir) / "canonical_anchors.json"
            anchor_path.write_text(json.dumps(anchor_payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
            payload = validate_canon_locks(
                replace(
                    FunGuardSources.default(),
                    canonical_anchors_path=anchor_path,
                )
            )
            self.assertEqual(payload["status"], "reject")
            self.assertIn("starter_town", payload["missing"]["anchors"])


if __name__ == "__main__":
    unittest.main()
