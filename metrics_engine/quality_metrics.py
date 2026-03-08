from __future__ import annotations


def _clamp(value: int, floor: int = 60, ceiling: int = 95) -> int:
    return max(floor, min(ceiling, int(value)))


def _range_string(center: int) -> str:
    center = _clamp(center)
    low = _clamp(center - 1)
    high = _clamp(center + 2)
    return f"{low}~{high}"


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

    activity_mix = world["activity_mix"]
    style_count = len(activity_mix)
    rare_rate = float(drops["rare_drop_rate_observed"])
    content_score = 70 + (style_count * 3) + min(8, int(rare_rate * 100))

    clear_rate = float(boss["clear_rate"])
    failure_rate = float(boss["failure_rate"])
    boss_score = 72 + int(clear_rate * 18) - int(failure_rate * 8)

    overall_center = int((combat_score + progression_score + economy_score + content_score + boss_score) / 5)
    return {
        "combat_quality": _range_string(combat_score),
        "progression_pacing": _range_string(progression_score),
        "economy_stability": _range_string(economy_score),
        "content_pressure_proxy": _range_string(content_score),
        "boss_quality_proxy": _range_string(boss_score),
        "overall_quality_estimate": _range_string(overall_center),
    }
