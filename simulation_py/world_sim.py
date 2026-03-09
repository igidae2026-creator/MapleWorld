from __future__ import annotations

import csv
from collections import Counter
from pathlib import Path
from typing import Iterable


ROOT_DIR = Path(__file__).resolve().parents[1]
MAP_ROLE_PATH = ROOT_DIR / "data" / "balance" / "maps" / "role_bands.csv"


def _bucket(values: list[int]) -> dict[str, int]:
    values = sorted(values)
    if not values:
        return {"low": 0, "mid": 0, "high": 0}
    return {
        "low": values[0],
        "mid": values[len(values) // 2],
        "high": values[-1],
    }


def _load_role_bands() -> list[dict[str, object]]:
    with MAP_ROLE_PATH.open(newline="", encoding="utf-8") as handle:
        rows = []
        for row in csv.DictReader(handle):
            rows.append(
                {
                    "band_id": row["band_id"],
                    "min_level": int(row["min_level"]),
                    "max_level": int(row["max_level"]),
                    "map_id": row["map_id"],
                    "role": row["role"],
                    "efficiency_profile": row["efficiency_profile"],
                    "throughput_bias": float(row["throughput_bias"]),
                }
            )
    return rows


def _role_distribution(players: Iterable[object]) -> dict[str, dict[str, object]]:
    role_bands = _load_role_bands()
    distribution: dict[str, dict[str, object]] = {}
    for row in role_bands:
        bucket = distribution.setdefault(
            str(row["band_id"]),
            {
                "recommended_levels": {
                    "min": int(row["min_level"]),
                    "max": int(row["max_level"]),
                },
                "roles": {},
                "population": 0,
            },
        )
        bucket["roles"][str(row["role"])] = {
            "map_id": row["map_id"],
            "efficiency_profile": row["efficiency_profile"],
            "throughput_proxy": row["throughput_bias"],
        }
    for player in players:
        level = getattr(player, "level", 1)
        for row in role_bands:
            if int(row["min_level"]) <= level <= int(row["max_level"]):
                distribution[str(row["band_id"])]["population"] += 1
                break
    return dict(sorted(distribution.items()))


def run_world(players: Iterable[object], loops: int) -> dict[str, object]:
    player_list = list(players)
    speed_distribution: list[int] = []
    mesos_distribution: list[int] = []
    activity_mix = Counter()

    for player in player_list:
        style = getattr(player, "play_style", "solo_grinder")
        stage = getattr(player, "progression_stage", "early")
        level = getattr(player, "level", 1)
        mesos = getattr(player, "mesos", 0)
        activity_mix[style] += 1
        if stage == "early":
            activity_mix["onboarding_fields"] += 1
        elif stage == "late":
            activity_mix["boss_access"] += 1
        speed_distribution.append(level + loops)
        mesos_distribution.append(mesos)

    return {
        "progression_speed_distribution": _bucket(speed_distribution),
        "mesos_distribution": _bucket(mesos_distribution),
        "activity_mix": dict(sorted(activity_mix.items())),
        "map_role_distribution": _role_distribution(player_list),
    }
