from __future__ import annotations

from collections import Counter
from typing import Iterable


def _bucket(values: list[int]) -> dict[str, int]:
    values = sorted(values)
    if not values:
        return {"low": 0, "mid": 0, "high": 0}
    return {
        "low": values[0],
        "mid": values[len(values) // 2],
        "high": values[-1],
    }


def run_world(players: Iterable[object], loops: int) -> dict[str, object]:
    speed_distribution: list[int] = []
    mesos_distribution: list[int] = []
    activity_mix = Counter()

    for player in players:
        style = getattr(player, "play_style", "solo_grinder")
        level = getattr(player, "level", 1)
        mesos = getattr(player, "mesos", 0)
        activity_mix[style] += 1
        speed_distribution.append(level + loops)
        mesos_distribution.append(mesos)

    return {
        "progression_speed_distribution": _bucket(speed_distribution),
        "mesos_distribution": _bucket(mesos_distribution),
        "activity_mix": dict(sorted(activity_mix.items())),
    }
