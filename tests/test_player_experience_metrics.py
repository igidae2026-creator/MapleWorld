from __future__ import annotations

import json
from pathlib import Path
import unittest


ROOT_DIR = Path(__file__).resolve().parents[1]

import sys

sys.path.insert(0, str(ROOT_DIR / "metrics_engine"))

from player_experience_metrics import build_player_experience_metrics


def _load_json(rel_path: str) -> dict[str, object]:
    return json.loads((ROOT_DIR / rel_path).read_text(encoding="utf-8"))


class PlayerExperienceMetricsTest(unittest.TestCase):
    def test_repository_player_experience_metrics_have_bottleneck(self) -> None:
        payload = build_player_experience_metrics(
            quality=_load_json("offline_ops/codex_state/simulation_runs/quality_metrics_latest.json"),
            fun_guard=_load_json("offline_ops/codex_state/simulation_runs/fun_guard_metrics_latest.json"),
            routing=_load_json("offline_ops/codex_state/simulation_runs/channel_routing_metrics_latest.json"),
            economy=_load_json("offline_ops/codex_state/simulation_runs/economy_pressure_metrics_latest.json"),
            liveops=_load_json("offline_ops/codex_state/simulation_runs/liveops_override_metrics_latest.json"),
            checkpoint=_load_json("offline_ops/codex_state/simulation_runs/checkpoint_stability_latest.json"),
            python_data=_load_json("offline_ops/codex_state/simulation_runs/python_simulation_latest.json"),
        )
        self.assertIn(payload["active_player_bottleneck"], payload["triage_order"])
        self.assertRegex(payload["ranges"]["first_10_minutes"], r"^\d+~\d+$")
        self.assertRegex(payload["ranges"]["first_hour_retention"], r"^\d+~\d+$")
        self.assertRegex(payload["ranges"]["day1_return_intent"], r"^\d+~\d+$")


if __name__ == "__main__":
    unittest.main()
