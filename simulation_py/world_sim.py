from __future__ import annotations

import csv
from collections import Counter
from pathlib import Path
from typing import Iterable

from identity_sim import (
    build_boss_chase_identity,
    build_quest_scaffold,
    build_region_identity,
    build_strategy_expression,
)
from channel_routing import build_channel_routing_model
from world_graph import build_world_graph


ROOT_DIR = Path(__file__).resolve().parents[1]
MAP_ROLE_PATH = ROOT_DIR / "data" / "balance" / "maps" / "role_bands.csv"
ANCHOR_PATH = ROOT_DIR / "data" / "canon" / "canonical_anchors.json"


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
                    "reward_bias": float(row["reward_bias"]),
                    "reward_identity_tag": row["reward_identity_tag"],
                }
            )
    return rows


def _load_anchors() -> dict[str, object]:
    import json

    return json.loads(ANCHOR_PATH.read_text(encoding="utf-8"))


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
            "reward_pressure_proxy": row["reward_bias"],
            "reward_identity_tag": row["reward_identity_tag"],
        }
    for player in players:
        level = getattr(player, "level", 1)
        for row in role_bands:
            if int(row["min_level"]) <= level <= int(row["max_level"]):
                distribution[str(row["band_id"])]["population"] += 1
                break
    return dict(sorted(distribution.items()))


def _strategy_usage(players: Iterable[object]) -> dict[str, dict[str, float]]:
    mob_combat = Counter()
    skill_usage = Counter()
    map_farming = Counter()

    for player in players:
        style = getattr(player, "play_style", "solo_grinder")
        if style == "party_grinder":
            mob_combat.update({"party_pull": 0.34, "burst_window": 0.46, "objective_chain": 0.20})
            skill_usage.update({"aoe_cycle": 0.42, "buff_window": 0.33, "single_target": 0.25})
            map_farming.update({"contested_lane": 0.45, "alt_route": 0.31, "safe_loop": 0.24})
        elif style == "quest_player":
            mob_combat.update({"objective_chain": 0.51, "steady_grind": 0.21, "burst_window": 0.28})
            skill_usage.update({"single_target": 0.39, "utility_cast": 0.37, "aoe_cycle": 0.24})
            map_farming.update({"alt_route": 0.44, "safe_loop": 0.36, "contested_lane": 0.20})
        else:
            mob_combat.update({"steady_grind": 0.48, "burst_window": 0.29, "objective_chain": 0.23})
            skill_usage.update({"single_target": 0.41, "aoe_cycle": 0.33, "utility_cast": 0.26})
            map_farming.update({"safe_loop": 0.43, "alt_route": 0.31, "contested_lane": 0.26})

    return {
        "mob_combat": dict(sorted(mob_combat.items())),
        "skill_usage": dict(sorted(skill_usage.items())),
        "map_farming": dict(sorted(map_farming.items())),
    }


def _anchor_presence() -> dict[str, object]:
    anchors = _load_anchors()
    return {
        "recognized_anchor_zones": sorted(anchors.get("zones", {}).keys()),
        "anchor_zones": {
            zone_id: {
                "anchor_zone": bool(zone.get("anchor_zone")),
                "zone_identity": zone.get("zone_identity", ""),
            }
            for zone_id, zone in sorted(dict(anchors.get("zones", {})).items())
        },
    }


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

    world_graph_model = build_world_graph(player_list, loops)
    channel_routing_model = build_channel_routing_model(player_list, loops, world_graph_model)

    return {
        "progression_speed_distribution": _bucket(speed_distribution),
        "mesos_distribution": _bucket(mesos_distribution),
        "activity_mix": dict(sorted(activity_mix.items())),
        "map_role_distribution": _role_distribution(player_list),
        "strategy_usage": _strategy_usage(player_list),
        "anchor_topology": _anchor_presence(),
        "starter_region_identity": build_region_identity(player_list),
        "quest_progression_scaffold": build_quest_scaffold(player_list),
        "boss_chase_identity": build_boss_chase_identity(),
        "early_strategy_expression": build_strategy_expression(player_list),
        "world_graph_model": world_graph_model,
        "channel_routing_model": channel_routing_model,
    }
