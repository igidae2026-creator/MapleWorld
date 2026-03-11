from __future__ import annotations

import unittest

from pathlib import Path
import sys

ROOT_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT_DIR / "metrics_engine"))

from economy_pressure_metrics import build_economy_pressure_metrics


class EconomyPressureMetricsTest(unittest.TestCase):
    def test_repository_economy_pressure_is_allow(self) -> None:
        payload = build_economy_pressure_metrics()
        self.assertEqual(payload["status"], "allow")
        for key in (
            "drop_pressure",
            "inflation_pressure",
            "reward_scarcity_index",
            "item_desirability_gradient",
            "farming_loop_risk",
            "sink_effectiveness",
            "currency_velocity_proxy",
            "reward_saturation_index",
            "top_pressure_nodes",
            "regional_reward_redistribution",
        ):
            self.assertIn(key, payload)
        self.assertIn("economy_intervention_profiles", payload)
        self.assertGreaterEqual(len(payload["economy_intervention_profiles"]), 1)

    def test_inflation_and_saturation_reject(self) -> None:
        payload = build_economy_pressure_metrics(
            {
                "economy_pressure_model": {
                    "economy_flow": {
                        "mesos_generation": 100000,
                        "mesos_removed": 12000,
                        "item_generation": 7000,
                        "adjusted_item_generation": 6900,
                    },
                    "adaptive_controls": {
                        "dynamic_drop_adjustment": 1.0,
                        "sink_amplification": 1.0,
                        "scarcity_balancing": 0.88,
                    },
                    "pressure_context": {
                        "inflation_pressure": 0.46,
                        "drop_pressure": 1.2,
                        "reward_scarcity_index": 0.12,
                        "item_desirability_gradient": 0.22,
                        "reward_saturation_index": 0.88,
                        "farming_loop_risk": 0.76,
                    },
                    "sink_source_tracking": {
                        "item_sources_by_route": {"grind": 95.0, "safe": 5.0},
                        "item_sources_by_boss_tier": {"tier_early": 95.0, "tier_mid": 5.0},
                        "mesos_sources_by_region": {"region:a": 9000.0},
                        "mesos_sinks_by_region": {"region:a": 1000.0},
                    },
                }
            }
        )
        self.assertEqual(payload["status"], "reject")
        self.assertTrue(len(payload["detections"]["inflation_spikes"]) >= 1)
        self.assertTrue(len(payload["detections"]["reward_saturation"]) >= 1)
        self.assertTrue(len(payload["detections"]["farming_economy_loops"]) >= 1)
        self.assertTrue(len(payload["detections"]["route_based_reward_abuse"]) >= 1)
        self.assertTrue(len(payload["detections"]["boss_reward_overconcentration"]) >= 1)


if __name__ == "__main__":
    unittest.main()
