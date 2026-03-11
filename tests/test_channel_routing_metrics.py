from __future__ import annotations

import unittest

from pathlib import Path
import sys

ROOT_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT_DIR / "metrics_engine"))

from channel_routing_metrics import build_channel_routing_metrics


class ChannelRoutingMetricsTest(unittest.TestCase):
    def test_repository_channel_routing_is_allow(self) -> None:
        payload = build_channel_routing_metrics()
        self.assertEqual(payload["status"], "allow")
        for key in ("node_concurrency", "hotspot_score", "channel_pressure", "spawn_pressure"):
            self.assertIn(key, payload)

    def test_overcrowding_and_stagnation_reject(self) -> None:
        payload = build_channel_routing_metrics(
            {
                "world": {
                    "channel_routing_model": {
                        "node_concurrency": {
                            "map:a": {
                                "visit_total": 40.0,
                                "target_concurrency": 10.0,
                                "spawn_capacity": 4.0,
                                "channel_count": 1,
                                "channel_loads": {"ch_1": 40.0},
                                "spawn_multiplier": 1.0,
                                "reward_bias": 1.25,
                            },
                            "map:b": {
                                "visit_total": 36.0,
                                "target_concurrency": 10.0,
                                "spawn_capacity": 4.0,
                                "channel_count": 1,
                                "channel_loads": {"ch_1": 36.0},
                                "spawn_multiplier": 1.0,
                                "reward_bias": 1.22,
                            },
                        },
                        "post_adaptation_pressure": {
                            "map:a": 1.6,
                            "map:b": 1.5,
                        },
                        "transition_counts": {
                            "map:a->map:b": 2,
                        },
                        "exploration_stagnation_index": 0.8,
                        "adaptive_policies": {
                            "soft_rerouting": [],
                            "spawn_redistribution": [],
                            "dynamic_channel_balancing": [],
                        },
                    }
                }
            }
        )
        self.assertEqual(payload["status"], "reject")
        self.assertTrue(len(payload["overcrowded_maps"]) >= 2)
        self.assertTrue(len(payload["farming_hotspots"]) >= 2)


if __name__ == "__main__":
    unittest.main()
