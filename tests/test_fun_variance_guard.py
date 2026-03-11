from __future__ import annotations

import tempfile
import json
from dataclasses import replace
from pathlib import Path
import re
import unittest


ROOT_DIR = Path(__file__).resolve().parents[1]

import sys

sys.path.insert(0, str(ROOT_DIR / "metrics_engine"))

from fun_guard_metrics import FunGuardSources, build_fun_guard_metrics


def _write_python_sim(tmp_dir: str, map_role_distribution: dict[str, object]) -> Path:
    path = Path(tmp_dir) / "python_simulation_latest.json"
    path.write_text(
        json.dumps(
            {
                "world": {
                    "map_role_distribution": map_role_distribution,
                }
            },
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )
    return path


class FunVarianceGuardTest(unittest.TestCase):
    def test_current_repository_passes_fun_guard(self) -> None:
        payload = build_fun_guard_metrics()
        for key in (
            "distinctiveness",
            "variance_health",
            "memorable_rewards",
            "early_loop_texture",
            "map_role_separation",
        ):
            self.assertRegex(str(payload[key]), r"^\d+~\d+$")
        self.assertEqual(payload["patch_veto"], "allow")

    def test_flattened_drop_variance_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            flattened_drop_table = Path(tmp_dir) / "drop_table.csv"
            flattened_drop_table.write_text(
                "\n".join(
                    [
                        "monster_id,item_id,drop_profile,rarity_band,drop_rate",
                        "starter_a,item_01,flat_table,common,0.2",
                        "starter_b,item_02,flat_table,common,0.2",
                        "starter_c,item_03,flat_table,common,0.2",
                    ]
                )
                + "\n",
                encoding="utf-8",
            )
            payload = build_fun_guard_metrics(
                replace(
                    FunGuardSources.default(),
                    drop_table_path=flattened_drop_table,
                )
            )
            self.assertEqual(payload["patch_veto"], "reject")
            self.assertLess(payload["centers"]["variance_health"], payload["floor_centers"]["variance_health"])
            self.assertLess(payload["centers"]["memorable_rewards"], payload["floor_centers"]["memorable_rewards"])

    def test_normalized_map_roles_are_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            python_sim_path = _write_python_sim(
                tmp_dir,
                {
                    "early_01": {
                        "population": 1,
                        "roles": {
                            "safe": {"map_id": "shared_map"},
                            "alternative": {"map_id": "shared_map"},
                            "high_risk_high_reward": {"map_id": "shared_map"},
                        },
                    },
                    "early_02": {
                        "population": 1,
                        "roles": {
                            "safe": {"map_id": "shared_map"},
                            "alternative": {"map_id": "shared_map"},
                            "high_risk_high_reward": {"map_id": "shared_map"},
                        },
                    },
                },
            )
            payload = build_fun_guard_metrics(
                replace(
                    FunGuardSources.default(),
                    python_simulation_path=python_sim_path,
                )
            )
            self.assertEqual(payload["patch_veto"], "reject")
            self.assertTrue(
                any("map role pattern elevated risk" in reason for reason in payload["reasons"])
            )

    def test_map_efficiency_variance_collapse_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            python_sim_path = _write_python_sim(
                tmp_dir,
                {
                    "early_01": {
                        "population": 1,
                        "roles": {
                            "safe": {"map_id": "starter_safe", "throughput_proxy": 1.0},
                            "alternative": {"map_id": "starter_alt", "throughput_proxy": 1.06},
                            "high_risk_high_reward": {"map_id": "starter_risk", "throughput_proxy": 1.08},
                        },
                    },
                },
            )
            payload = build_fun_guard_metrics(
                replace(
                    FunGuardSources.default(),
                    python_simulation_path=python_sim_path,
                )
            )
            self.assertEqual(payload["patch_veto"], "reject")
            self.assertTrue(
                any("throughput spread below floor" in reason for reason in payload["reasons"])
            )

    def test_role_names_without_throughput_spread_are_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            python_sim_path = _write_python_sim(
                tmp_dir,
                {
                    "early_01": {
                        "population": 1,
                        "roles": {
                            "safe": {"map_id": "starter_safe", "throughput_proxy": 1.00, "reward_pressure_proxy": 1.00},
                            "alternative": {"map_id": "starter_alt", "throughput_proxy": 1.04, "reward_pressure_proxy": 1.05},
                            "high_risk_high_reward": {"map_id": "starter_risk", "throughput_proxy": 1.07, "reward_pressure_proxy": 1.08},
                        },
                    },
                    "early_02": {
                        "population": 1,
                        "roles": {
                            "safe": {"map_id": "harbor_safe", "throughput_proxy": 1.00, "reward_pressure_proxy": 1.00},
                            "alternative": {"map_id": "forest_alt", "throughput_proxy": 1.03, "reward_pressure_proxy": 1.04},
                            "high_risk_high_reward": {"map_id": "cliff_risk", "throughput_proxy": 1.06, "reward_pressure_proxy": 1.07},
                        },
                    },
                },
            )
            payload = build_fun_guard_metrics(
                replace(
                    FunGuardSources.default(),
                    python_simulation_path=python_sim_path,
                )
            )
            self.assertEqual(payload["patch_veto"], "reject")
            self.assertTrue(
                any("throughput spread below floor" in reason for reason in payload["reasons"])
            )

    def test_reward_pressure_collapse_is_rejected_even_when_throughput_spread_passes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            python_sim_path = _write_python_sim(
                tmp_dir,
                {
                    "early_01": {
                        "population": 1,
                        "roles": {
                            "safe": {"map_id": "starter_safe", "throughput_proxy": 1.00, "reward_pressure_proxy": 1.00, "reward_identity_tag": "consumable_farming"},
                            "alternative": {"map_id": "starter_alt", "throughput_proxy": 1.13, "reward_pressure_proxy": 1.05, "reward_identity_tag": "vendor_loot"},
                            "high_risk_high_reward": {"map_id": "starter_risk", "throughput_proxy": 1.25, "reward_pressure_proxy": 1.09, "reward_identity_tag": "rare_excitement"},
                        },
                    },
                },
            )
            payload = build_fun_guard_metrics(
                replace(
                    FunGuardSources.default(),
                    python_simulation_path=python_sim_path,
                )
            )
            self.assertEqual(payload["patch_veto"], "reject")
            self.assertTrue(
                any("reward pressure spread below floor" in reason for reason in payload["reasons"])
            )

    def test_reward_identity_collapse_is_rejected_even_when_numeric_spreads_pass(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            python_sim_path = _write_python_sim(
                tmp_dir,
                {
                    "early_01": {
                        "population": 1,
                        "roles": {
                            "safe": {"map_id": "starter_safe", "throughput_proxy": 1.00, "reward_pressure_proxy": 1.00, "reward_identity_tag": "vendor_loot"},
                            "alternative": {"map_id": "starter_alt", "throughput_proxy": 1.14, "reward_pressure_proxy": 1.17, "reward_identity_tag": "vendor_loot"},
                            "high_risk_high_reward": {"map_id": "starter_risk", "throughput_proxy": 1.27, "reward_pressure_proxy": 1.31, "reward_identity_tag": "vendor_loot"},
                        },
                    },
                },
            )
            payload = build_fun_guard_metrics(
                replace(
                    FunGuardSources.default(),
                    python_simulation_path=python_sim_path,
                )
            )
            self.assertEqual(payload["patch_veto"], "reject")
            self.assertTrue(
                any("reward identity collapsed" in reason for reason in payload["reasons"])
            )

    def test_perion_hotspot_reward_floor_is_rejected_even_when_band_spread_passes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            python_sim_path = _write_python_sim(
                tmp_dir,
                {
                    "early_02": {
                        "population": 1,
                        "roles": {
                            "safe": {
                                "map_id": "lith_harbor_coast_road",
                                "throughput_proxy": 0.95,
                                "reward_pressure_proxy": 0.97,
                                "reward_identity_tag": "consumable_farming",
                            },
                            "alternative": {
                                "map_id": "ellinia_lower_canopy",
                                "throughput_proxy": 1.03,
                                "reward_pressure_proxy": 1.04,
                                "reward_identity_tag": "gear_upgrade",
                            },
                            "high_risk_high_reward": {
                                "map_id": "perion_rockfall_edge",
                                "throughput_proxy": 1.07,
                                "reward_pressure_proxy": 1.11,
                                "reward_identity_tag": "rare_excitement",
                            },
                        },
                    },
                },
            )
            payload = build_fun_guard_metrics(
                replace(
                    FunGuardSources.default(),
                    python_simulation_path=python_sim_path,
                )
            )
            self.assertEqual(payload["patch_veto"], "reject")
            self.assertTrue(
                any("hotspot reward floor broken at perion_rockfall_edge" in reason for reason in payload["reasons"])
            )


if __name__ == "__main__":
    unittest.main()
