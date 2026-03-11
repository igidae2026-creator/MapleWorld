from __future__ import annotations

import csv
import json
import math
from collections import Counter
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
RUNS_DIR = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs"
DROP_TABLE_PATH = ROOT_DIR / "data" / "balance" / "drops" / "drop_table.csv"
LEVEL_CURVE_PATH = ROOT_DIR / "data" / "balance" / "progression" / "level_curve.csv"
EARLY_PROFILE_PATH = ROOT_DIR / "data" / "balance" / "progression" / "early_game_profile.json"
ANCHOR_PATH = ROOT_DIR / "data" / "canon" / "canonical_anchors.json"
LADDER_RULES_PATH = ROOT_DIR / "data" / "balance" / "drops" / "drop_ladder_rules.json"

REWARD_IDENTITIES = (
    "currency",
    "equipment",
    "craft",
    "rare",
    "collection",
    "cosmetic",
    "utility",
)

DROP_TIERS = (
    "tier0",
    "tier1",
    "tier2",
    "tier3",
    "tier4",
    "tier5",
)

DROP_TIER_LABELS = {
    "tier0": "junk",
    "tier1": "useful",
    "tier2": "progression",
    "tier3": "rare",
    "tier4": "chase",
    "tier5": "mythic",
}


def _clamp(value: float, floor: float, ceiling: float) -> float:
    return max(floor, min(ceiling, value))


def _read_csv_rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def _load_json(path: Path) -> dict[str, object]:
    return json.loads(path.read_text(encoding="utf-8"))


def _normalized(counter: Counter[str]) -> dict[str, float]:
    total = sum(counter.values())
    if total <= 0:
        return {}
    return {key: value / total for key, value in sorted(counter.items())}


def _weighted_entropy(counter: Counter[str]) -> float:
    distribution = _normalized(counter)
    if not distribution:
        return 0.0
    entropy = -sum(weight * math.log(weight, 2) for weight in distribution.values() if weight > 0)
    return entropy


def _range_string(center: int) -> str:
    low = max(60, min(95, center - 1))
    high = max(60, min(95, center + 2))
    return f"{low}~{high}"


def infer_reward_identity(row: dict[str, str], index: int = 0) -> str:
    explicit = str(row.get("reward_identity", "")).strip()
    if explicit in REWARD_IDENTITIES:
        return explicit

    rarity = str(row.get("rarity_band", "")).strip().lower()
    item_id = str(row.get("item_id", "")).strip().lower()
    equipment_keywords = ("sword", "axe", "spear", "bow", "claw", "wand", "staff", "overall")
    utility_keywords = ("glove", "shoe", "potion", "scroll")

    if rarity == "boss":
        cycle = ("rare", "collection", "cosmetic")
        return cycle[index % len(cycle)]
    if rarity == "elite":
        cycle = ("rare", "collection", "equipment")
        return cycle[index % len(cycle)]
    if rarity == "rare":
        cycle = ("rare", "equipment", "collection", "craft")
        return cycle[index % len(cycle)]
    if any(keyword in item_id for keyword in utility_keywords):
        cycle = ("utility", "craft", "equipment")
        return cycle[index % len(cycle)]
    if any(keyword in item_id for keyword in equipment_keywords):
        cycle = ("equipment", "currency", "utility", "craft")
        return cycle[index % len(cycle)]
    cycle = ("currency", "utility", "collection")
    return cycle[index % len(cycle)]


def infer_drop_tier(row: dict[str, str], index: int = 0) -> str:
    explicit = str(row.get("drop_tier", "")).strip()
    if explicit in DROP_TIERS:
        return explicit

    rarity = str(row.get("rarity_band", "")).strip().lower()
    drop_rate = float(row.get("drop_rate", 0.0) or 0.0)
    if rarity == "boss":
        return "tier5" if drop_rate <= 0.0039 else "tier4"
    if rarity == "elite":
        return "tier4" if index % 6 == 0 else "tier3"
    if rarity == "rare":
        return "tier3" if index % 3 == 0 else "tier2"
    if rarity == "uncommon":
        return "tier2" if index % 4 in (0, 1) else "tier1"
    return "tier1" if index % 5 == 0 else "tier0"


def load_drop_rows(path: Path = DROP_TABLE_PATH) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for index, row in enumerate(_read_csv_rows(path)):
        enriched = dict(row)
        enriched["drop_rate"] = float(row.get("drop_rate", 0.0) or 0.0)
        enriched["reward_identity"] = infer_reward_identity(row, index)
        enriched["drop_tier"] = infer_drop_tier(row, index)
        rows.append(enriched)
    return rows


def compute_reward_identity_guard(drop_rows: list[dict[str, object]]) -> dict[str, object]:
    weights: Counter[str] = Counter()
    for row in drop_rows:
        weights[str(row["reward_identity"])] += max(1, int(float(row["drop_rate"]) * 10000))
    entropy = _weighted_entropy(weights)
    threshold = 2.15
    normalized_entropy = entropy / math.log(len(REWARD_IDENTITIES), 2)
    score = int(round(70 + (normalized_entropy * 25)))
    return {
        "distribution": _normalized(weights),
        "entropy": round(entropy, 4),
        "normalized_entropy": round(normalized_entropy, 4),
        "threshold": threshold,
        "score": _range_string(score),
        "status": "reject" if entropy < threshold else "allow",
        "reason": None if entropy >= threshold else f"reward identity entropy below floor: {entropy:.3f} < {threshold:.2f}",
    }


def compute_strategy_diversity_guard(world_data: dict[str, object]) -> dict[str, object]:
    categories = dict(world_data.get("strategy_usage", {}))
    dominance_threshold = 0.68
    reasons: list[str] = []
    details: dict[str, dict[str, float]] = {}
    centers: list[int] = []

    for category, values in sorted(categories.items()):
        counter = Counter({key: float(value) for key, value in dict(values).items()})
        total = sum(counter.values()) or 1.0
        distribution = {key: round(value / total, 4) for key, value in sorted(counter.items())}
        dominant_strategy, dominant_share = max(distribution.items(), key=lambda item: item[1])
        entropy = -sum(share * math.log(share, 2) for share in distribution.values() if share > 0)
        normalized_entropy = entropy / math.log(max(2, len(distribution)), 2)
        centers.append(int(round(72 + (normalized_entropy * 21))))
        details[category] = {
            "dominant_strategy": dominant_strategy,
            "dominant_share": round(dominant_share, 4),
            "entropy": round(entropy, 4),
            "normalized_entropy": round(normalized_entropy, 4),
            "distribution": distribution,
        }
        if dominant_share > dominance_threshold:
            reasons.append(
                f"strategy dominance exceeded in {category}: {dominant_strategy}={dominant_share:.2f} > {dominance_threshold:.2f}"
            )

    average_center = int(round(sum(centers) / len(centers))) if centers else 60
    return {
        "dominance_threshold": dominance_threshold,
        "categories": details,
        "score": _range_string(average_center),
        "status": "reject" if reasons else "allow",
        "reasons": reasons,
    }


def compute_economy_drift_guard(python_data: dict[str, object], drop_rows: list[dict[str, object]]) -> dict[str, object]:
    economy = dict(python_data.get("economy", {}))
    total_mesos_created = float(economy.get("total_mesos_created", 0.0) or 0.0)
    total_mesos_removed = float(economy.get("total_mesos_removed", 0.0) or 0.0)
    sink_ratio = total_mesos_removed / max(1.0, total_mesos_created)
    item_generation = sum(float(row["drop_rate"]) for row in drop_rows)
    rare_generation = sum(float(row["drop_rate"]) for row in drop_rows if row["reward_identity"] == "rare")
    inflation_ratio = total_mesos_created / max(1.0, total_mesos_removed)

    reasons: list[str] = []
    if inflation_ratio > 1.2:
        reasons.append(f"economy inflation ratio exceeded: {inflation_ratio:.2f} > 1.20")
    if sink_ratio < 0.75:
        reasons.append(f"sink ratio below floor: {sink_ratio:.2f} < 0.75")
    if rare_generation / max(0.001, item_generation) > 0.22:
        reasons.append("rare item generation pressure exceeded 22% of total drop pressure")

    center = int(round(88 - min(24, abs(1.0 - sink_ratio) * 18) - min(18, max(0.0, inflation_ratio - 1.0) * 20)))
    return {
        "mesos_generation": int(total_mesos_created),
        "item_generation": round(item_generation, 4),
        "sink_ratio": round(sink_ratio, 4),
        "inflation_ratio": round(inflation_ratio, 4),
        "rare_generation_share": round(rare_generation / max(0.001, item_generation), 4),
        "score": _range_string(max(60, center)),
        "status": "reject" if reasons else "allow",
        "reasons": reasons,
    }


def compute_exploit_scenarios(
    python_data: dict[str, object],
    reward_guard: dict[str, object],
    strategy_guard: dict[str, object],
    economy_guard: dict[str, object],
) -> dict[str, object]:
    world = dict(python_data.get("world", {}))
    map_roles = dict(world.get("map_role_distribution", {}))
    repeated_maps = 0
    for band in map_roles.values():
        role_maps = {str(role.get("map_id", "")) for role in dict(band.get("roles", {})).values()}
        if len(role_maps) <= 1:
            repeated_maps += 1

    scenarios = {
        "infinite_farming_loops": round(
            min(
                1.0,
                repeated_maps * 0.22
                + max(0.0, 1.0 - float(strategy_guard["categories"].get("map_farming", {}).get("normalized_entropy", 0.0)))
                * 0.45,
            ),
            4,
        ),
        "reward_abuse_loops": round(
            min(
                1.0,
                max(0.0, 2.25 - float(reward_guard["entropy"])) * 0.3
                + max(0.0, 1.0 - float(economy_guard["sink_ratio"])) * 0.5,
            ),
            4,
        ),
        "progression_skipping": round(
            min(
                1.0,
                max(0.0, float(python_data.get("economy", {}).get("total_mesos_removed", 0.0)) / max(1.0, float(python_data.get("economy", {}).get("total_mesos_created", 1.0))) - 2.5)
                * 0.08
                + max(0.0, float(strategy_guard["categories"].get("mob_combat", {}).get("dominant_share", 0.0)) - 0.55),
            ),
            4,
        ),
    }
    max_score = max(scenarios.values()) if scenarios else 0.0
    threshold = 0.6
    return {
        "scenarios": scenarios,
        "max_score": max_score,
        "threshold": threshold,
        "status": "reject" if max_score > threshold else "allow",
        "reasons": [] if max_score <= threshold else [f"exploit scenario pressure exceeded: {max_score:.2f} > {threshold:.2f}"],
    }


def compute_drop_ladder_metrics(drop_rows: list[dict[str, object]]) -> dict[str, object]:
    rules = _load_json(LADDER_RULES_PATH)
    weighted_counts: Counter[str] = Counter()
    boss_weighted_counts: Counter[str] = Counter()
    field_weighted_counts: Counter[str] = Counter()

    for row in drop_rows:
        tier = str(row["drop_tier"])
        weight = max(1, int(float(row["drop_rate"]) * 10000))
        weighted_counts[tier] += weight
        if str(row.get("rarity_band", "")).lower() == "boss":
            boss_weighted_counts[tier] += weight
        else:
            field_weighted_counts[tier] += weight

    def weighted_average(counter: Counter[str]) -> float:
        total = sum(counter.values()) or 1
        return sum(DROP_TIERS.index(key) * value for key, value in counter.items()) / total

    field_avg = weighted_average(field_weighted_counts)
    boss_avg = weighted_average(boss_weighted_counts)
    mythic_share = weighted_counts["tier5"] / max(1, sum(weighted_counts.values()))
    early_low_tier_share = (
        field_weighted_counts["tier0"] + field_weighted_counts["tier1"] + field_weighted_counts["tier2"]
    ) / max(1, sum(field_weighted_counts.values()))

    reasons: list[str] = []
    if boss_avg < 4.0 or boss_avg <= field_avg + 1.5:
        reasons.append(f"boss ladder ceiling too low: boss_avg={boss_avg:.2f}, field_avg={field_avg:.2f}")
    if early_low_tier_share < 0.82:
        reasons.append(f"early field low-tier share below floor: {early_low_tier_share:.2f} < 0.82")
    if mythic_share > float(rules.get("mythic_share_cap", 0.02)):
        reasons.append(f"mythic share above cap: {mythic_share:.3f}")

    score = int(round(74 + min(11, boss_avg * 3.5) + min(6, early_low_tier_share * 8) - min(10, mythic_share * 200)))
    return {
        "ladder_schema": {tier: DROP_TIER_LABELS[tier] for tier in DROP_TIERS},
        "distribution": _normalized(weighted_counts),
        "field_distribution": _normalized(field_weighted_counts),
        "boss_distribution": _normalized(boss_weighted_counts),
        "field_average_tier": round(field_avg, 4),
        "boss_average_tier": round(boss_avg, 4),
        "mythic_share": round(mythic_share, 4),
        "early_low_tier_share": round(early_low_tier_share, 4),
        "drop_excitement_score": _range_string(score),
        "status": "reject" if reasons else "allow",
        "reasons": reasons,
    }


def compute_early_progression_metrics(level_rows: list[dict[str, str]]) -> dict[str, object]:
    profile = _load_json(EARLY_PROFILE_PATH)
    level_curve = {int(row["level"]): int(row["exp_required"]) for row in level_rows if row.get("level")}
    bands = []
    for band in profile.get("level_bands", []):
        minimum = int(band["min_level"])
        maximum = int(band["max_level"])
        levels = [level_curve[level] for level in range(minimum, maximum + 1) if level in level_curve]
        deltas = [right - left for left, right in zip(levels, levels[1:])]
        avg_delta = sum(deltas) / len(deltas) if deltas else 0.0
        delta_span = (max(deltas) - min(deltas)) if deltas else 0.0
        reward_cadence = float(band["reward_cadence_per_hour"])
        progression_speed = float(band["levels_per_hour"])
        progression_minutes = round((maximum - minimum + 1) / max(0.1, progression_speed) * 60, 1)
        flags = []
        if delta_span > max(240.0, avg_delta * 1.6):
            flags.append("power_spike_risk")
        if reward_cadence < 3.0:
            flags.append("reward_drought")
        if progression_speed < 1.8:
            flags.append("stagnation_zone")
        bands.append(
            {
                "band": f"{minimum}-{maximum}",
                "reward_cadence_per_hour": reward_cadence,
                "combat_pacing": band["combat_pacing"],
                "drop_tier_limit": band["drop_tier_limit"],
                "levels_per_hour": progression_speed,
                "minutes_to_clear_band": progression_minutes,
                "exp_delta_average": round(avg_delta, 2),
                "exp_delta_span": int(delta_span),
                "flags": flags,
            }
        )

    flagged = [flag for band in bands for flag in band["flags"]]
    score = int(round(86 - (len(flagged) * 6)))
    pacing_graph = " | ".join(
        f"{band['band']}:{'#' * max(1, int(round(band['levels_per_hour'])))}" for band in bands
    )
    return {
        "starter_anchors": list(profile.get("starter_anchors", [])),
        "bands": bands,
        "level_pacing_graph": pacing_graph,
        "reward_density": round(sum(band["reward_cadence_per_hour"] for band in bands) / max(1, len(bands)), 2),
        "progression_estimate_minutes": round(
            sum(float(band["minutes_to_clear_band"]) for band in bands),
            1,
        ),
        "issues": flagged,
        "early_progression_metric": _range_string(max(60, score)),
        "status": "reject" if len(flagged) >= 2 else "allow",
    }


def load_canonical_anchors(path: Path = ANCHOR_PATH) -> dict[str, object]:
    return _load_json(path)


def validate_canonical_anchors(
    anchors: dict[str, object],
    runtime_region_ids: set[str],
    runtime_boss_ids: set[str],
) -> dict[str, object]:
    reasons: list[str] = []
    zones = dict(anchors.get("zones", {}))
    missing: list[str] = []
    for zone_id, zone in sorted(zones.items()):
        zone_identity = str(zone.get("zone_identity", "")).strip()
        if not zone_identity:
            reasons.append(f"anchor zone missing zone_identity: {zone_id}")
        if not bool(zone.get("anchor_zone")):
            reasons.append(f"anchor zone not pinned: {zone_id}")
        kind = str(zone.get("kind", "region"))
        if kind == "boss":
            if zone_id not in runtime_boss_ids:
                missing.append(zone_id)
        elif kind == "region" and zone_id not in runtime_region_ids:
            missing.append(zone_id)
    if missing:
        reasons.append(f"canonical anchors missing: {', '.join(missing)}")
    return {
        "zones": zones,
        "missing": missing,
        "status": "reject" if reasons else "ok",
        "reasons": reasons,
    }
