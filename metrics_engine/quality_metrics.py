from __future__ import annotations

from pathlib import Path

from channel_routing_metrics import build_channel_routing_metrics
from economy_pressure_metrics import build_economy_pressure_metrics
from mvp_stability import compute_drop_ladder_metrics, compute_early_progression_metrics, load_drop_rows
from world_graph_metrics import build_world_graph_metrics


def _clamp(value: int, floor: int = 60, ceiling: int = 95) -> int:
    return max(floor, min(ceiling, int(value)))


def _range_string(center: int) -> str:
    center = _clamp(center)
    low = _clamp(center - 1)
    high = _clamp(center + 2)
    return f"{low}~{high}"


ROOT_DIR = Path(__file__).resolve().parents[1]
LEVEL_CURVE_PATH = ROOT_DIR / "data" / "balance" / "progression" / "level_curve.csv"


def _load_level_curve_rows() -> list[dict[str, str]]:
    import csv

    with LEVEL_CURVE_PATH.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def build_quality_metrics(lua_data: dict[str, object], python_data: dict[str, object]) -> dict[str, str]:
    combat = lua_data["combat"]
    progression = lua_data["progression"]
    drops = lua_data["drops"]
    boss = lua_data["boss"]
    economy = python_data["economy"]
    world = python_data["world"]

    combat_score = 72 + int(float(combat["hit_rate_observed"]) * 12) + int(float(combat["crit_rate_observed"]) * 18)

    loops_to_target = int(progression["loops_to_target"])
    progression_score = 88 - min(18, max(0, loops_to_target - 6) * 2)

    inflation_signal = str(economy["net_inflation_signal"])
    economy_score = {
        "stable_low_positive": 85,
        "moderate_positive": 79,
        "high_positive": 72,
    }.get(inflation_signal, 70)
    if inflation_signal == "stable_low_positive":
        total_created = int(economy["total_mesos_created"])
        total_removed = int(economy["total_mesos_removed"])
        removal_ratio = total_removed / max(1, total_created)
        if removal_ratio >= 3.0:
            economy_score = 89
        elif removal_ratio >= 1.5:
            economy_score = 87

    activity_mix = world["activity_mix"]
    style_count = len(activity_mix)
    rare_rate = float(drops["rare_drop_rate_observed"])
    content_score = 70 + (style_count * 3) + min(8, int(rare_rate * 100))

    clear_rate = float(boss["clear_rate"])
    failure_rate = float(boss["failure_rate"])
    boss_score = 72 + int(clear_rate * 18) - int(failure_rate * 8)

    overall_center = int((combat_score + progression_score + economy_score + content_score + boss_score) / 5)
    drop_rows = load_drop_rows()
    ladder_metrics = compute_drop_ladder_metrics(drop_rows)
    early_progression = compute_early_progression_metrics(_load_level_curve_rows())
    world_graph = build_world_graph_metrics(python_data)
    channel_routing = build_channel_routing_metrics(python_data)
    economy_pressure = build_economy_pressure_metrics(python_data)
    graph_center = int(
        round(
            65
            + world_graph["node_utilization"] * 10
            + world_graph["content_density"] * 8
            + world_graph["exploration_flow"] * 8
            + world_graph["path_entropy"] * 8
            + (1.0 - world_graph["travel_friction"]) * 8
        )
    )
    routing_center = int(
        round(
            66
            + channel_routing["node_concurrency"] * 9
            + (1.0 - channel_routing["hotspot_score"]) * 8
            + (1.0 - channel_routing["channel_pressure"]) * 8
            + (1.0 - channel_routing["spawn_pressure"]) * 8
            + (1.0 - channel_routing["exploration_stagnation"]["index"]) * 8
        )
    )
    economy_pressure_center = int(
        round(
            66
            + max(0.0, 1.0 - economy_pressure["drop_pressure"]) * 7
            + max(0.0, 1.0 - economy_pressure["inflation_pressure"]) * 9
            + economy_pressure["reward_scarcity_index"] * 7
            + economy_pressure["item_desirability_gradient"] * 7
            + min(1.0, economy_pressure["adaptive_control"]["sink_amplification"] / 1.4) * 4
        )
    )
    return {
        "combat_quality": _range_string(combat_score),
        "progression_pacing": _range_string(progression_score),
        "economy_stability": _range_string(economy_score),
        "content_pressure_proxy": _range_string(content_score),
        "boss_quality_proxy": _range_string(boss_score),
        "world_graph_balance": _range_string(graph_center),
        "channel_routing_balance": _range_string(routing_center),
        "economy_pressure_balance": _range_string(economy_pressure_center),
        "drop_excitement_score": ladder_metrics["drop_excitement_score"],
        "early_progression_metric": early_progression["early_progression_metric"],
        "overall_quality_estimate": _range_string(overall_center),
    }
