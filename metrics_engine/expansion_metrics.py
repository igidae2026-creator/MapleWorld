from __future__ import annotations

import json
from pathlib import Path

from mvp_stability import compute_economy_drift_guard, load_drop_rows


ROOT_DIR = Path(__file__).resolve().parents[1]
RUNS_DIR = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs"
OUTPUT_PATH = RUNS_DIR / "expansion_metrics_latest.json"


def _clamp(value: int, floor: int = 0, ceiling: int = 100) -> int:
    return max(floor, min(ceiling, int(value)))


def _range(center: int) -> str:
    center = _clamp(center, 60, 98)
    return f"{_clamp(center - 1, 60, 98)}~{_clamp(center + 2, 60, 98)}"


def _load_python_latest() -> dict[str, object]:
    return json.loads((RUNS_DIR / "python_simulation_latest.json").read_text(encoding="utf-8"))


def build_expansion_metrics(python_data: dict[str, object] | None = None) -> dict[str, object]:
    payload = python_data or _load_python_latest()
    world = dict(payload.get("world", {}))

    region = dict(world.get("starter_region_identity", {}))
    quest = dict(world.get("quest_progression_scaffold", {}))
    boss = dict(world.get("boss_chase_identity", {}))
    strategy = dict(world.get("early_strategy_expression", {}))

    region_count = int(region.get("region_count", 0))
    rhythm_diversity = int(region.get("combat_rhythm_diversity", 0))
    reward_diversity = int(region.get("reward_identity_diversity", 0))
    traversal_diversity = int(region.get("traversal_tone_diversity", 0))
    bundle_a_reasons: list[str] = []
    if not 3 <= region_count <= 5:
        bundle_a_reasons.append(f"region count out of target range: {region_count} (expected 3~5)")
    if rhythm_diversity < 4:
        bundle_a_reasons.append(f"combat rhythm diversity below floor: {rhythm_diversity} < 4")
    if reward_diversity < 10:
        bundle_a_reasons.append(f"reward identity diversity below floor: {reward_diversity} < 10")
    if traversal_diversity < 4:
        bundle_a_reasons.append(f"traversal tone diversity below floor: {traversal_diversity} < 4")
    bundle_a_center = 71 + min(8, region_count * 2) + min(7, rhythm_diversity) + min(7, traversal_diversity)

    density = float(quest.get("quest_reward_density", 0.0))
    smoothness = float(quest.get("progression_smoothness", 0.0))
    drought = bool(quest.get("questline_drought_detected", True))
    concentration = float(quest.get("single_pattern_concentration", 1.0))
    kill_fetch_share = float(quest.get("kill_fetch_combined_share", 1.0))
    caps = dict(quest.get("pattern_caps", {}))
    max_pattern = float(caps.get("max_single_pattern_share", 0.34))
    max_kill_fetch = float(caps.get("max_kill_fetch_combined_share", 0.58))

    bundle_b_reasons: list[str] = []
    if density < 0.95 or density > 1.28:
        bundle_b_reasons.append(f"quest reward density out of band: {density:.3f}")
    if smoothness < 0.78:
        bundle_b_reasons.append(f"progression smoothness below floor: {smoothness:.3f} < 0.780")
    if drought:
        bundle_b_reasons.append("questline drought detected")
    if concentration > max_pattern:
        bundle_b_reasons.append(f"single quest pattern concentration too high: {concentration:.3f} > {max_pattern:.3f}")
    if kill_fetch_share > max_kill_fetch:
        bundle_b_reasons.append(f"kill/fetch combined share too high: {kill_fetch_share:.3f} > {max_kill_fetch:.3f}")
    bundle_b_center = 74 + min(9, int(density * 8)) + min(8, int(smoothness * 10)) + (0 if drought else 5)

    desirability_sep = float(boss.get("boss_desirability_separation", 0.0))
    reward_clarity = float(boss.get("field_vs_boss_reward_clarity", 0.0))
    overconcentration = float(boss.get("chase_item_overconcentration_risk", 1.0))
    risk_caps = dict(boss.get("risk_caps", {}))
    min_sep = float(risk_caps.get("min_desirability_separation", 0.14))
    max_item_share = float(risk_caps.get("max_single_item_share", 0.46))

    bundle_c_reasons: list[str] = []
    if desirability_sep < min_sep:
        bundle_c_reasons.append(f"boss desirability separation below floor: {desirability_sep:.3f} < {min_sep:.3f}")
    if reward_clarity < 0.28:
        bundle_c_reasons.append(f"field-vs-boss reward clarity below floor: {reward_clarity:.3f} < 0.280")
    if overconcentration > max_item_share:
        bundle_c_reasons.append(f"chase-item overconcentration risk too high: {overconcentration:.3f} > {max_item_share:.3f}")
    bundle_c_center = 75 + min(8, int(desirability_sep * 20)) + min(9, int(reward_clarity * 25)) - min(10, int(overconcentration * 15))

    route_diversity = float(strategy.get("early_route_diversity", 0.0))
    class_expression = float(strategy.get("class_archetype_expression", 0.0))
    strategy_concentration = float(strategy.get("low_level_strategy_concentration", 1.0))
    anti_monopoly = dict(strategy.get("anti_monopoly", {}))
    max_route_share = float(anti_monopoly.get("max_single_route_share", 0.47))
    min_route_entropy = float(anti_monopoly.get("min_route_entropy", 1.78))
    min_class_expression = float(anti_monopoly.get("min_archetype_expression_score", 0.68))

    bundle_d_reasons: list[str] = []
    if route_diversity < min_route_entropy:
        bundle_d_reasons.append(f"early route diversity below floor: {route_diversity:.3f} < {min_route_entropy:.3f}")
    if class_expression < min_class_expression:
        bundle_d_reasons.append(f"class/archetype expression below floor: {class_expression:.3f} < {min_class_expression:.3f}")
    if strategy_concentration > max_route_share:
        bundle_d_reasons.append(f"single-strategy concentration too high: {strategy_concentration:.3f} > {max_route_share:.3f}")
    bundle_d_center = 74 + min(8, int(route_diversity * 5)) + min(8, int(class_expression * 12)) - min(10, int(strategy_concentration * 10))

    economy_guard = compute_economy_drift_guard(payload, load_drop_rows())

    expansion_reasons: list[str] = []
    for group in (bundle_a_reasons, bundle_b_reasons, bundle_c_reasons, bundle_d_reasons):
        expansion_reasons.extend(group)
    if economy_guard["status"] != "allow":
        expansion_reasons.extend(str(reason) for reason in economy_guard["reasons"])

    result = {
        "bundle_a_starter_world_identity": {
            "region_count": region_count,
            "combat_rhythm_diversity": rhythm_diversity,
            "reward_identity_diversity": reward_diversity,
            "traversal_tone_diversity": traversal_diversity,
            "identity_strength": _range(bundle_a_center),
            "status": "reject" if bundle_a_reasons else "allow",
            "reasons": bundle_a_reasons,
        },
        "bundle_b_quest_progression_scaffolding": {
            "quest_reward_density": round(density, 4),
            "progression_smoothness": round(smoothness, 4),
            "questline_drought_detected": drought,
            "single_pattern_concentration": round(concentration, 4),
            "kill_fetch_combined_share": round(kill_fetch_share, 4),
            "questline_health": _range(bundle_b_center),
            "status": "reject" if bundle_b_reasons else "allow",
            "reasons": bundle_b_reasons,
        },
        "bundle_c_boss_chase_identity": {
            "boss_desirability_separation": round(desirability_sep, 4),
            "field_vs_boss_reward_clarity": round(reward_clarity, 4),
            "chase_item_overconcentration_risk": round(overconcentration, 4),
            "boss_chase_health": _range(bundle_c_center),
            "status": "reject" if bundle_c_reasons else "allow",
            "reasons": bundle_c_reasons,
        },
        "bundle_d_strategy_expression": {
            "early_route_diversity": round(route_diversity, 4),
            "class_archetype_expression": round(class_expression, 4),
            "low_level_strategy_concentration": round(strategy_concentration, 4),
            "strategy_expression_health": _range(bundle_d_center),
            "status": "reject" if bundle_d_reasons else "allow",
            "reasons": bundle_d_reasons,
        },
        "economy_stability_guard": economy_guard,
        "expansion_veto": "reject" if expansion_reasons else "allow",
        "reasons": expansion_reasons,
    }
    return result


def write_expansion_metrics(
    python_data: dict[str, object] | None = None,
    output_path: Path = OUTPUT_PATH,
) -> dict[str, object]:
    payload = build_expansion_metrics(python_data)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return payload
