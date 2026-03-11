from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path
import unittest


ROOT_DIR = Path(__file__).resolve().parents[1]
VALIDATOR = ROOT_DIR / "ai_evolution_offline" / "codex" / "validate_bottleneck_scope.py"
ECONOMY_PRESSURE_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs" / "economy_pressure_metrics_latest.json"
EARLY02_REBALANCE_REPORT = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs" / "early02_rebalance_candidates.json"
EARLY02_SHADOW_RELIEF_REPORT = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs" / "early02_shadow_relief_candidates.json"


class BottleneckScopeValidatorTest(unittest.TestCase):
    def setUp(self) -> None:
        self._economy_pressure_backup = ECONOMY_PRESSURE_PATH.read_text(encoding="utf-8")
        self._early02_rebalance_backup = EARLY02_REBALANCE_REPORT.read_text(encoding="utf-8")
        self._early02_shadow_relief_backup = EARLY02_SHADOW_RELIEF_REPORT.read_text(encoding="utf-8")

    def tearDown(self) -> None:
        ECONOMY_PRESSURE_PATH.write_text(self._economy_pressure_backup, encoding="utf-8")
        EARLY02_REBALANCE_REPORT.write_text(self._early02_rebalance_backup, encoding="utf-8")
        EARLY02_SHADOW_RELIEF_REPORT.write_text(self._early02_shadow_relief_backup, encoding="utf-8")

    def _write_top_pressure_node(self, node: str) -> None:
        payload = json.loads(self._economy_pressure_backup)
        payload["top_pressure_nodes"] = [{"node": node, "pressure": 1.2765}]
        ECONOMY_PRESSURE_PATH.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    def _write_top_pressure_nodes(self, nodes: list[str]) -> None:
        payload = json.loads(self._economy_pressure_backup)
        payload["top_pressure_nodes"] = [
            {"node": node, "pressure": round(1.2765 - (index * 0.01), 4)}
            for index, node in enumerate(nodes)
        ]
        ECONOMY_PRESSURE_PATH.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    def _write_rebalance_recommendation(self, recommendation: str) -> None:
        payload = json.loads(self._early02_rebalance_backup)
        payload["recommendation"] = recommendation
        EARLY02_REBALANCE_REPORT.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    def _write_shadow_relief_recommendation(self, recommendation: str) -> None:
        payload = json.loads(self._early02_shadow_relief_backup)
        payload["recommendation"] = recommendation
        EARLY02_SHADOW_RELIEF_REPORT.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    def test_validator_accepts_active_bottleneck_scope(self) -> None:
        self._write_top_pressure_node("map:perion_rockfall_edge")
        self._write_rebalance_recommendation("use_best_candidate")
        self._write_shadow_relief_recommendation("use_best_candidate")
        with tempfile.TemporaryDirectory() as tmp_dir:
            decision = Path(tmp_dir) / "decision.txt"
            decision.write_text(
                "CURRENT_EFFICIENCY_ESTIMATE:\n"
                "88~91\n\n"
                "BOTTLENECK_KEY:\n"
                "economy_coherence\n\n"
                "CHOSEN_BOTTLENECK:\n"
                "economy_coherence is the narrowest active player bottleneck because drop pressure remains elevated.\n\n"
                "FILES:\n"
                "- data/balance/maps/role_bands.csv\n\n"
                "PATCH_BOUNDARY:\n"
                "narrow map-scoped economy pressure repair\n",
                encoding="utf-8",
            )
            result = subprocess.run(
                [sys.executable, str(VALIDATOR), str(decision)],
                cwd=ROOT_DIR,
                check=True,
                capture_output=True,
                text=True,
            )
            self.assertIn("PASS", result.stdout)

    def test_validator_accepts_map_balance_patch_for_economy_coherence(self) -> None:
        self._write_top_pressure_node("map:perion_rockfall_edge")
        self._write_rebalance_recommendation("use_best_candidate")
        self._write_shadow_relief_recommendation("use_best_candidate")
        with tempfile.TemporaryDirectory() as tmp_dir:
            decision = Path(tmp_dir) / "decision.txt"
            decision.write_text(
                "CURRENT_EFFICIENCY_ESTIMATE:\n"
                "88~90\n\n"
                "BOTTLENECK_KEY:\n"
                "economy_coherence\n\n"
                "CHOSEN_BOTTLENECK:\n"
                "economy_coherence remains the binding next-cycle bottleneck.\n\n"
                "FILES:\n"
                "- /home/meta_os/MapleWorld/data/balance/maps/role_bands.csv\n\n"
                "PATCH_BOUNDARY:\n"
                "one-field balance adjustment only\n",
                encoding="utf-8",
            )
            result = subprocess.run(
                [sys.executable, str(VALIDATOR), str(decision)],
                cwd=ROOT_DIR,
                check=True,
                capture_output=True,
                text=True,
            )
            self.assertIn("PASS", result.stdout)

    def test_validator_rejects_read_only_evidence_paths_in_files(self) -> None:
        self._write_top_pressure_node("sink:repair_bill_band_02")
        with tempfile.TemporaryDirectory() as tmp_dir:
            decision = Path(tmp_dir) / "decision.txt"
            decision.write_text(
                "CURRENT_EFFICIENCY_ESTIMATE:\n"
                "88~91\n\n"
                "BOTTLENECK_KEY:\n"
                "economy_coherence\n\n"
                "CHOSEN_BOTTLENECK:\n"
                "economy_coherence is the narrowest active player bottleneck because drop pressure remains elevated.\n\n"
                "FILES:\n"
                "- data/balance/economy/sinks.csv\n"
                "- offline_ops/codex_state/simulation_runs/economy_pressure_metrics_latest.json\n\n"
                "PATCH_BOUNDARY:\n"
                "narrow economy pressure repair\n",
                encoding="utf-8",
            )
            result = subprocess.run(
                [sys.executable, str(VALIDATOR), str(decision)],
                cwd=ROOT_DIR,
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("file outside allowed roots", result.stdout)

    def test_validator_rejects_content_build_for_economy_coherence(self) -> None:
        self._write_top_pressure_node("map:perion_rockfall_edge")
        with tempfile.TemporaryDirectory() as tmp_dir:
            decision = Path(tmp_dir) / "decision.txt"
            decision.write_text(
                "CURRENT_EFFICIENCY_ESTIMATE:\n"
                "88~90\n\n"
                "BOTTLENECK_KEY:\n"
                "economy_coherence\n\n"
                "CHOSEN_BOTTLENECK:\n"
                "economy_coherence remains the binding next-cycle bottleneck.\n\n"
                "FILES:\n"
                "- content_build/content_registry.lua\n\n"
                "PATCH_BOUNDARY:\n"
                "bounded source-table edit\n",
                encoding="utf-8",
            )
            result = subprocess.run(
                [sys.executable, str(VALIDATOR), str(decision)],
                cwd=ROOT_DIR,
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("file outside allowed roots", result.stdout)

    def test_validator_rejects_non_map_patch_when_economy_hotspot_is_map_scoped(self) -> None:
        self._write_top_pressure_node("map:perion_rockfall_edge")
        with tempfile.TemporaryDirectory() as tmp_dir:
            decision = Path(tmp_dir) / "decision.txt"
            decision.write_text(
                "CURRENT_EFFICIENCY_ESTIMATE:\n"
                "88~90\n\n"
                "BOTTLENECK_KEY:\n"
                "economy_coherence\n\n"
                "CHOSEN_BOTTLENECK:\n"
                "economy_coherence remains bound to a map hotspot.\n\n"
                "FILES:\n"
                "- data/balance/economy/sinks.csv\n\n"
                "PATCH_BOUNDARY:\n"
                "level-band sink tweak\n",
                encoding="utf-8",
            )
            result = subprocess.run(
                [sys.executable, str(VALIDATOR), str(decision)],
                cwd=ROOT_DIR,
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("map-scoped top pressure node", result.stdout)

    def test_validator_rejects_perion_only_reduction_when_early02_is_floor_locked(self) -> None:
        self._write_top_pressure_node("map:perion_rockfall_edge")
        with tempfile.TemporaryDirectory() as tmp_dir:
            decision = Path(tmp_dir) / "decision.txt"
            decision.write_text(
                "CURRENT_EFFICIENCY_ESTIMATE:\n"
                "88~90\n\n"
                "BOTTLENECK_KEY:\n"
                "economy_coherence\n\n"
                "CHOSEN_BOTTLENECK:\n"
                "Trim only perion_rockfall_edge in early_02.\n\n"
                "NEXT_PATCH_OBJECTIVE:\n"
                "Lower perion_rockfall_edge reward and throughput a little.\n\n"
                "FILES:\n"
                "- data/balance/maps/role_bands.csv\n\n"
                "PATCH_BOUNDARY:\n"
                "one file one map only\n",
                encoding="utf-8",
            )
            result = subprocess.run(
                [sys.executable, str(VALIDATOR), str(decision)],
                cwd=ROOT_DIR,
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("spread floors are already at the guarded minimum", result.stdout)

    def test_validator_rejects_repeated_early02_patch_when_rebalance_is_exhausted(self) -> None:
        self._write_top_pressure_node("map:perion_rockfall_edge")
        self._write_rebalance_recommendation("same-band early_02 rebalance exhausted")
        with tempfile.TemporaryDirectory() as tmp_dir:
            decision = Path(tmp_dir) / "decision.txt"
            decision.write_text(
                "CURRENT_EFFICIENCY_ESTIMATE:\n"
                "82~85\n\n"
                "BOTTLENECK_KEY:\n"
                "economy_coherence\n\n"
                "CHOSEN_BOTTLENECK:\n"
                "Try another early_02 role_bands adjustment around perion_rockfall_edge.\n\n"
                "NEXT_PATCH_OBJECTIVE:\n"
                "Adjust ellinia_lower_canopy and lith_harbor_coast_road again.\n\n"
                "FILES:\n"
                "- data/balance/maps/role_bands.csv\n\n"
                "PATCH_BOUNDARY:\n"
                "same-band early_02 rebalance retry\n",
                encoding="utf-8",
            )
            result = subprocess.run(
                [sys.executable, str(VALIDATOR), str(decision)],
                cwd=ROOT_DIR,
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("same-band early_02 rebalance is exhausted", result.stdout)

    def test_validator_requires_next_non_early02_map_after_early02_exhaustion(self) -> None:
        self._write_top_pressure_nodes(
            [
                "map:perion_rockfall_edge",
                "map:ellinia_lower_canopy",
                "map:lith_harbor_coast_road",
                "map:ancient_hidden_domains_rift",
            ]
        )
        self._write_rebalance_recommendation("same-band early_02 rebalance exhausted")
        with tempfile.TemporaryDirectory() as tmp_dir:
            decision = Path(tmp_dir) / "decision.txt"
            decision.write_text(
                "CURRENT_EFFICIENCY_ESTIMATE:\n"
                "82~85\n\n"
                "BOTTLENECK_KEY:\n"
                "economy_coherence\n\n"
                "CHOSEN_BOTTLENECK:\n"
                "Reduce high_risk_high_reward rows across role_bands.\n\n"
                "NEXT_PATCH_OBJECTIVE:\n"
                "Trim generic high-risk spikes.\n\n"
                "FILES:\n"
                "- data/balance/maps/role_bands.csv\n\n"
                "PATCH_BOUNDARY:\n"
                "generic role band smoothing\n",
                encoding="utf-8",
            )
            result = subprocess.run(
                [sys.executable, str(VALIDATOR), str(decision)],
                cwd=ROOT_DIR,
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("decision must target the next map-scoped pressure node", result.stdout)

    def test_validator_rejects_same_band_retry_when_shadow_relief_is_exhausted(self) -> None:
        self._write_top_pressure_nodes(
            [
                "map:perion_rockfall_edge",
                "map:ellinia_lower_canopy",
                "map:lith_harbor_coast_road",
                "map:ancient_hidden_domains_rift",
            ]
        )
        self._write_shadow_relief_recommendation("same-band early_02 shadow relief exhausted")
        with tempfile.TemporaryDirectory() as tmp_dir:
            decision = Path(tmp_dir) / "decision.txt"
            decision.write_text(
                "CURRENT_EFFICIENCY_ESTIMATE:\n"
                "77~80\n\n"
                "BOTTLENECK_KEY:\n"
                "economy_coherence\n\n"
                "CHOSEN_BOTTLENECK:\n"
                "Retry another same-band early_02 shadow relief.\n\n"
                "NEXT_PATCH_OBJECTIVE:\n"
                "Adjust ellinia_lower_canopy and lith_harbor_coast_road one more time.\n\n"
                "FILES:\n"
                "- data/balance/maps/role_bands.csv\n\n"
                "PATCH_BOUNDARY:\n"
                "same-band early_02 retry\n",
                encoding="utf-8",
            )
            result = subprocess.run(
                [sys.executable, str(VALIDATOR), str(decision)],
                cwd=ROOT_DIR,
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("same-band early_02 rebalance is exhausted", result.stdout)


if __name__ == "__main__":
    unittest.main()
