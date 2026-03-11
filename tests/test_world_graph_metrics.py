from __future__ import annotations

import unittest

from pathlib import Path
import sys

ROOT_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT_DIR / "metrics_engine"))

from world_graph_metrics import build_world_graph_metrics


class WorldGraphMetricsTest(unittest.TestCase):
    def test_repository_world_graph_is_allow(self) -> None:
        payload = build_world_graph_metrics()
        self.assertEqual(payload["status"], "allow")
        for key in ("node_utilization", "content_density", "exploration_flow", "path_entropy", "travel_friction"):
            self.assertIn(key, payload)
        self.assertGreaterEqual(payload["content_density"], 0.6)

    def test_dead_zone_and_bottleneck_detection(self) -> None:
        payload = build_world_graph_metrics(
            {
                "world": {
                    "world_graph_model": {
                        "nodes": [
                            {"node_id": "region:a", "content_slots": 2},
                            {"node_id": "region:b", "content_slots": 2},
                            {"node_id": "map:a1", "content_slots": 1},
                            {"node_id": "map:a2", "content_slots": 1},
                            {"node_id": "map:b1", "content_slots": 1},
                        ],
                        "edges": [
                            {"from": "region:a", "to": "map:a1", "friction": 0.2},
                            {"from": "region:a", "to": "map:a2", "friction": 0.25},
                            {"from": "region:b", "to": "map:b1", "friction": 0.2},
                            {"from": "map:a1", "to": "region:b", "friction": 0.4},
                        ],
                        "node_visits": {
                            "region:a": 20,
                            "region:b": 1,
                            "map:a1": 20,
                            "map:a2": 18,
                            "map:b1": 0,
                        },
                        "expected_visits": {
                            "region:a": 10,
                            "region:b": 10,
                            "map:a1": 10,
                            "map:a2": 10,
                            "map:b1": 10,
                        },
                        "edge_traversals": {
                            "region:a->map:a1": 20,
                            "region:a->map:a2": 18,
                            "region:b->map:b1": 1,
                            "map:a1->region:b": 16,
                        },
                        "route_counts": {
                            "route:safe": 30,
                            "route:alt": 8,
                            "route:risk": 2,
                        },
                    }
                }
            }
        )
        self.assertTrue(len(payload["dead_zones"]) >= 1)
        self.assertTrue(len(payload["exploration_bottlenecks"]) >= 1)


if __name__ == "__main__":
    unittest.main()
