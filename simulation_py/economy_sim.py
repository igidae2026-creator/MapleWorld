from __future__ import annotations

from typing import Iterable


def run_economy(players: Iterable[object], loops: int) -> dict[str, object]:
    total_mesos_created = 0
    total_mesos_removed = 0

    for player in players:
        stage_factor = {
            "early": 1.0,
            "mid": 1.35,
            "late": 1.7,
        }.get(getattr(player, "progression_stage", "early"), 1.0)
        created = int((65 + (getattr(player, "level", 1) * 4)) * stage_factor * loops)
        removed = int((28 + (getattr(player, "level", 1) * 2)) * stage_factor * loops)
        total_mesos_created += created
        total_mesos_removed += removed

    net = total_mesos_created - total_mesos_removed
    if net <= 4000:
        signal = "stable_low_positive"
    elif net <= 9000:
        signal = "moderate_positive"
    else:
        signal = "high_positive"

    return {
        "total_mesos_created": total_mesos_created,
        "total_mesos_removed": total_mesos_removed,
        "net_inflation_signal": signal,
    }
