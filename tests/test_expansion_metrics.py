from __future__ import annotations

import unittest

from pathlib import Path
import sys

ROOT_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT_DIR / "metrics_engine"))

from expansion_metrics import build_expansion_metrics


class ExpansionMetricsTest(unittest.TestCase):
    def test_repository_expansion_metrics_allow(self) -> None:
        payload = build_expansion_metrics()
        self.assertEqual(payload["expansion_veto"], "allow")
        self.assertEqual(payload["bundle_a_starter_world_identity"]["status"], "allow")
        self.assertEqual(payload["bundle_b_quest_progression_scaffolding"]["status"], "allow")
        self.assertEqual(payload["bundle_c_boss_chase_identity"]["status"], "allow")
        self.assertEqual(payload["bundle_d_strategy_expression"]["status"], "allow")

    def test_strategy_monopoly_rejected(self) -> None:
        payload = build_expansion_metrics(
            {
                "economy": {
                    "total_mesos_created": 1000,
                    "total_mesos_removed": 1000,
                    "sink_ratio": 1.0,
                },
                "world": {
                    "starter_region_identity": {
                        "region_count": 5,
                        "combat_rhythm_diversity": 5,
                        "reward_identity_diversity": 11,
                        "traversal_tone_diversity": 5,
                    },
                    "quest_progression_scaffold": {
                        "quest_reward_density": 1.05,
                        "progression_smoothness": 0.9,
                        "questline_drought_detected": False,
                        "single_pattern_concentration": 0.2,
                        "kill_fetch_combined_share": 0.4,
                        "pattern_caps": {
                            "max_single_pattern_share": 0.34,
                            "max_kill_fetch_combined_share": 0.58,
                        },
                    },
                    "boss_chase_identity": {
                        "boss_desirability_separation": 0.2,
                        "field_vs_boss_reward_clarity": 0.35,
                        "chase_item_overconcentration_risk": 0.3,
                        "risk_caps": {
                            "min_desirability_separation": 0.14,
                            "max_single_item_share": 0.46,
                        },
                    },
                    "early_strategy_expression": {
                        "early_route_diversity": 1.82,
                        "class_archetype_expression": 0.72,
                        "low_level_strategy_concentration": 0.76,
                        "anti_monopoly": {
                            "max_single_route_share": 0.47,
                            "min_route_entropy": 1.78,
                            "min_archetype_expression_score": 0.68,
                        },
                    },
                },
            }
        )
        self.assertEqual(payload["bundle_d_strategy_expression"]["status"], "reject")
        self.assertEqual(payload["expansion_veto"], "reject")


if __name__ == "__main__":
    unittest.main()
