from __future__ import annotations

import csv
from functools import lru_cache
from pathlib import Path
from typing import Iterable


ROOT_DIR = Path(__file__).resolve().parents[1]
SINKS_PATH = ROOT_DIR / "data" / "balance" / "economy" / "sinks.csv"


@lru_cache(maxsize=1)
def _load_boss_entry_sinks() -> tuple[dict[str, float], ...]:
    rows: list[dict[str, float]] = []
    with SINKS_PATH.open(encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle):
            if row.get("sink_id", "").startswith("boss_entry_ticket"):
                rows.append(
                    {
                        "level_band": float(row["level_band"]),
                        "meso_cost": float(row["meso_cost"]),
                        "sink_weight": float(row["sink_weight"]),
                    }
                )
    rows.sort(key=lambda row: row["level_band"])
    return tuple(rows)


def _boss_entry_removed(level: int, loops: int) -> int:
    sinks = _load_boss_entry_sinks()
    if not sinks:
        return 0

    # Use the short simulation horizon as a progression proxy so late-loop sinks can
    # affect players who are about to enter that band during the modeled window.
    projected_band = max(1.0, ((level + loops) + 9) // 10)
    selected = sinks[0]
    for sink in sinks:
        if projected_band >= sink["level_band"]:
            selected = sink

    estimated_boss_runs = max(0, loops // 3)
    return int(selected["meso_cost"] * selected["sink_weight"] * estimated_boss_runs)


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
        removed += _boss_entry_removed(getattr(player, "level", 1), loops)
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
