from __future__ import annotations

import json
import tempfile
from dataclasses import replace
from pathlib import Path
import unittest


ROOT_DIR = Path(__file__).resolve().parents[1]

import sys

sys.path.insert(0, str(ROOT_DIR / "metrics_engine"))

from fun_guard_metrics import FunGuardSources, build_fun_guard_metrics


def _write_python_sim(tmp_dir: str, world: dict[str, object], economy: dict[str, object] | None = None) -> Path:
    path = Path(tmp_dir) / "python_simulation_latest.json"
    path.write_text(
        json.dumps(
            {
                "world": world,
                "economy": economy
                or {
                    "total_mesos_created": 1000,
                    "total_mesos_removed": 1000,
                    "net_inflation_signal": "stable_low_positive",
                    "sink_ratio": 1.0,
                },
            },
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )
    return path


class MVPStabilizerGuardsTest(unittest.TestCase):
    def test_repository_bundle_one_guards_allow(self) -> None:
        payload = build_fun_guard_metrics()
        self.assertEqual(payload["reward_identity_diversity_guard"]["status"], "allow")
        self.assertEqual(payload["strategy_diversity_guard"]["status"], "allow")
        self.assertEqual(payload["economy_drift_guard"]["status"], "allow")
        self.assertEqual(payload["exploit_scenario_tests"]["status"], "allow")

    def test_reward_identity_entropy_collapse_rejects_patch(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            drop_path = Path(tmp_dir) / "drop_table.csv"
            drop_path.write_text(
                "\n".join(
                    [
                        "monster_id,item_id,drop_profile,rarity_band,drop_rate,reward_identity,drop_tier",
                        "a,item_1,starter,common,0.25,equipment,tier0",
                        "b,item_2,starter,common,0.25,equipment,tier0",
                        "c,item_3,starter,common,0.25,equipment,tier0",
                    ]
                )
                + "\n",
                encoding="utf-8",
            )
            payload = build_fun_guard_metrics(replace(FunGuardSources.default(), drop_table_path=drop_path))
            self.assertEqual(payload["patch_veto"], "reject")
            self.assertEqual(payload["reward_identity_diversity_guard"]["status"], "reject")

    def test_strategy_meta_collapse_rejects_patch(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            sim_path = _write_python_sim(
                tmp_dir,
                {
                    "map_role_distribution": {
                        "early_01": {
                            "population": 1,
                            "roles": {
                                "safe": {"map_id": "starter_safe", "throughput_proxy": 1.0, "reward_pressure_proxy": 1.0, "reward_identity_tag": "currency"},
                                "alternative": {"map_id": "starter_alt", "throughput_proxy": 1.2, "reward_pressure_proxy": 1.2, "reward_identity_tag": "utility"},
                                "high_risk_high_reward": {"map_id": "starter_risk", "throughput_proxy": 1.4, "reward_pressure_proxy": 1.4, "reward_identity_tag": "rare"},
                            },
                        }
                    },
                    "strategy_usage": {
                        "mob_combat": {"steady_grind": 0.9, "burst_window": 0.05, "objective_chain": 0.05},
                        "skill_usage": {"aoe_cycle": 0.92, "single_target": 0.04, "utility_cast": 0.04},
                        "map_farming": {"safe_loop": 0.9, "alt_route": 0.05, "contested_lane": 0.05},
                    },
                },
            )
            payload = build_fun_guard_metrics(replace(FunGuardSources.default(), python_simulation_path=sim_path))
            self.assertEqual(payload["patch_veto"], "reject")
            self.assertEqual(payload["strategy_diversity_guard"]["status"], "reject")

    def test_economy_drift_rejects_patch(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            sim_path = _write_python_sim(
                tmp_dir,
                {
                    "map_role_distribution": {
                        "early_01": {
                            "population": 1,
                            "roles": {
                                "safe": {"map_id": "starter_safe", "throughput_proxy": 1.0, "reward_pressure_proxy": 1.0, "reward_identity_tag": "currency"},
                                "alternative": {"map_id": "starter_alt", "throughput_proxy": 1.2, "reward_pressure_proxy": 1.2, "reward_identity_tag": "utility"},
                                "high_risk_high_reward": {"map_id": "starter_risk", "throughput_proxy": 1.4, "reward_pressure_proxy": 1.4, "reward_identity_tag": "rare"},
                            },
                        }
                    },
                    "strategy_usage": {
                        "mob_combat": {"steady_grind": 0.4, "burst_window": 0.3, "objective_chain": 0.3},
                        "skill_usage": {"aoe_cycle": 0.34, "single_target": 0.33, "utility_cast": 0.33},
                        "map_farming": {"safe_loop": 0.34, "alt_route": 0.33, "contested_lane": 0.33},
                    },
                },
                economy={
                    "total_mesos_created": 100000,
                    "total_mesos_removed": 12000,
                    "net_inflation_signal": "high_positive",
                    "sink_ratio": 0.12,
                },
            )
            payload = build_fun_guard_metrics(replace(FunGuardSources.default(), python_simulation_path=sim_path))
            self.assertEqual(payload["patch_veto"], "reject")
            self.assertEqual(payload["economy_drift_guard"]["status"], "reject")


if __name__ == "__main__":
    unittest.main()
