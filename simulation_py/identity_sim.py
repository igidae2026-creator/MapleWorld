from __future__ import annotations

import json
import math
from collections import Counter
from functools import lru_cache
from pathlib import Path
from typing import Iterable


ROOT_DIR = Path(__file__).resolve().parents[1]
REGION_PACK_PATH = ROOT_DIR / "data" / "expansions" / "identity" / "starter_world_identity_pack.json"
QUEST_PACK_PATH = ROOT_DIR / "data" / "expansions" / "quests" / "early_quest_arcs.json"
BOSS_PACK_PATH = ROOT_DIR / "data" / "expansions" / "bosses" / "early_chase_boss_pack.json"
STRATEGY_PACK_PATH = ROOT_DIR / "data" / "expansions" / "strategy" / "early_strategy_routes.json"


@lru_cache(maxsize=1)
def _load_pack(path: Path) -> dict[str, object]:
    return json.loads(path.read_text(encoding="utf-8"))


def _entropy(distribution: dict[str, float]) -> float:
    total = sum(distribution.values()) or 1.0
    weights = [value / total for value in distribution.values() if value > 0]
    return -sum(weight * math.log(weight, 2) for weight in weights)


def _round4(value: float) -> float:
    return round(float(value), 4)


def build_region_identity(players: Iterable[object]) -> dict[str, object]:
    pack = _load_pack(REGION_PACK_PATH)
    regions = list(pack.get("regions", []))
    rhythms = {str(region.get("combat_rhythm", "")) for region in regions}
    rewards = {
        reward
        for region in regions
        for reward in list(region.get("reward_identity", []))
    }
    traversal = {str(region.get("traversal_tone", "")) for region in regions}

    early_players = [player for player in players if getattr(player, "level", 1) <= 30]
    region_population: Counter[str] = Counter()
    for player in early_players:
        level = int(getattr(player, "level", 1))
        for region in regions:
            band = dict(region.get("level_band", {}))
            if int(band.get("min", 1)) <= level <= int(band.get("max", 30)):
                region_population[str(region.get("region_id", "unknown"))] += 1
                break

    return {
        "pack_id": pack.get("pack_id"),
        "region_count": len(regions),
        "combat_rhythm_diversity": len({value for value in rhythms if value}),
        "reward_identity_diversity": len({value for value in rewards if value}),
        "traversal_tone_diversity": len({value for value in traversal if value}),
        "region_population": dict(sorted(region_population.items())),
        "regions": regions,
    }


def build_quest_scaffold(players: Iterable[object]) -> dict[str, object]:
    pack = _load_pack(QUEST_PACK_PATH)
    arcs = list(pack.get("arcs", []))
    pattern_caps = dict(pack.get("pattern_caps", {}))

    stage_rows: list[dict[str, object]] = []
    pattern_counter: Counter[str] = Counter()
    total_reward_density = 0.0
    total_minutes = 0.0
    total_quests = 0
    band_progression: list[float] = []
    kill_fetch_total = 0.0

    for arc in arcs:
        quests = list(arc.get("quests", []))
        stage = str(arc.get("stage", "unknown"))
        level_band = dict(arc.get("level_band", {}))
        avg_density = 0.0
        avg_minutes = 0.0
        if quests:
            avg_density = sum(float(quest.get("reward_density", 0.0)) for quest in quests) / len(quests)
            avg_minutes = sum(float(quest.get("estimated_minutes", 0.0)) for quest in quests) / len(quests)
        stage_rows.append(
            {
                "stage": stage,
                "level_band": level_band,
                "quest_count": len(quests),
                "avg_reward_density": _round4(avg_density),
                "avg_minutes": _round4(avg_minutes),
            }
        )
        band_progression.append(avg_density)
        for quest in quests:
            pattern = str(quest.get("pattern", "unknown"))
            pattern_counter[pattern] += 1
            total_reward_density += float(quest.get("reward_density", 0.0))
            total_minutes += float(quest.get("estimated_minutes", 0.0))
            total_quests += 1
            objective_mix = dict(quest.get("objective_mix", {}))
            kill_fetch_total += float(objective_mix.get("kill", 0.0)) + float(objective_mix.get("delivery", 0.0))

    early_players = [player for player in players if getattr(player, "level", 1) <= 30]
    stage_player_split = {
        "onboarding": sum(1 for player in early_players if int(getattr(player, "level", 1)) <= 10),
        "commitment": sum(1 for player in early_players if 11 <= int(getattr(player, "level", 1)) <= 20),
        "mastery_transition": sum(1 for player in early_players if 21 <= int(getattr(player, "level", 1)) <= 30),
    }

    distribution = {
        key: (value / max(1, total_quests))
        for key, value in sorted(pattern_counter.items())
    }
    dominant_share = max(distribution.values()) if distribution else 1.0
    progression_smoothness = 1.0
    if len(band_progression) > 1:
        deltas = [abs(right - left) for left, right in zip(band_progression, band_progression[1:])]
        progression_smoothness = max(0.0, 1.0 - (sum(deltas) / len(deltas)))

    drought_threshold = float(pattern_caps.get("drought_minutes_threshold", 22.0))
    avg_minutes = total_minutes / max(1, total_quests)

    return {
        "pack_id": pack.get("pack_id"),
        "stage_rows": stage_rows,
        "stage_player_split": stage_player_split,
        "quest_reward_density": _round4(total_reward_density / max(1, total_quests)),
        "progression_smoothness": _round4(progression_smoothness),
        "questline_drought_detected": avg_minutes > drought_threshold,
        "questline_drought_margin": _round4(avg_minutes - drought_threshold),
        "pattern_distribution": {key: _round4(value) for key, value in distribution.items()},
        "single_pattern_concentration": _round4(dominant_share),
        "kill_fetch_combined_share": _round4(kill_fetch_total / max(1, total_quests)),
        "pattern_caps": pattern_caps,
    }


def build_boss_chase_identity() -> dict[str, object]:
    pack = _load_pack(BOSS_PACK_PATH)
    bosses = list(pack.get("bosses", []))
    risk_caps = dict(pack.get("risk_caps", {}))

    separation_values: list[float] = []
    clarity_values: list[float] = []
    item_shares: Counter[str] = Counter()
    total_item_weight = 0.0

    for boss in bosses:
        field_floor = float(boss.get("field_reward_floor", 0.0))
        boss_ceiling = float(boss.get("boss_reward_ceiling", 0.0))
        clarity_values.append(max(0.0, boss_ceiling - field_floor))

        chase_items = list(boss.get("chase_items", []))
        if chase_items:
            desirability = [float(item.get("desirability", 0.0)) for item in chase_items]
            separation_values.append(max(desirability) - min(desirability))

        for item in chase_items:
            item_id = str(item.get("item_id", "unknown"))
            weight = float(item.get("drop_rate", 0.0)) * float(item.get("desirability", 0.0))
            item_shares[item_id] += weight
            total_item_weight += weight

    overconcentration = 0.0
    if total_item_weight > 0:
        overconcentration = max(value / total_item_weight for value in item_shares.values())

    return {
        "pack_id": pack.get("pack_id"),
        "boss_count": len(bosses),
        "boss_desirability_separation": _round4(sum(separation_values) / max(1, len(separation_values))),
        "field_vs_boss_reward_clarity": _round4(sum(clarity_values) / max(1, len(clarity_values))),
        "chase_item_overconcentration_risk": _round4(overconcentration),
        "risk_caps": risk_caps,
        "bosses": bosses,
    }


def _pick_archetype_for_player(player: object, fallback_index: int, archetypes: list[dict[str, object]]) -> str:
    explicit = str(getattr(player, "archetype", "")).strip().lower()
    if explicit:
        return explicit
    style = str(getattr(player, "play_style", ""))
    style_map = {
        "party_grinder": "vanguard",
        "quest_player": "arcanist",
        "solo_grinder": "ranger",
    }
    if style in style_map:
        return style_map[style]
    if not archetypes:
        return "unknown"
    return str(archetypes[fallback_index % len(archetypes)].get("archetype", "unknown"))


def build_strategy_expression(players: Iterable[object]) -> dict[str, object]:
    pack = _load_pack(STRATEGY_PACK_PATH)
    archetypes = list(pack.get("archetypes", []))
    anti_monopoly = dict(pack.get("anti_monopoly", {}))
    archetype_by_id = {str(row.get("archetype", "")): row for row in archetypes}

    route_counter: Counter[str] = Counter()
    archetype_counter: Counter[str] = Counter()
    route_alignment_scores: list[float] = []

    for index, player in enumerate(players):
        if int(getattr(player, "level", 1)) > 30:
            continue
        archetype = _pick_archetype_for_player(player, index, archetypes)
        archetype_counter[archetype] += 1
        routing = archetype_by_id.get(archetype, {})
        weights = dict(routing.get("route_weights", {}))
        if not weights:
            continue
        route = max(weights, key=weights.get)
        route_counter[route] += 1
        route_alignment_scores.append(float(weights[route]))

    route_distribution = {
        key: (value / max(1, sum(route_counter.values())))
        for key, value in sorted(route_counter.items())
    }
    archetype_distribution = {
        key: (value / max(1, sum(archetype_counter.values())))
        for key, value in sorted(archetype_counter.items())
    }

    strategy_concentration = max(route_distribution.values()) if route_distribution else 1.0
    route_entropy = _entropy(route_distribution) if route_distribution else 0.0
    class_expression = 0.0
    if archetype_distribution:
        class_expression = min(1.0, (_entropy(archetype_distribution) / math.log(max(2, len(archetype_distribution)), 2)))
    alignment_score = sum(route_alignment_scores) / max(1, len(route_alignment_scores))

    return {
        "pack_id": pack.get("pack_id"),
        "route_distribution": {key: _round4(value) for key, value in route_distribution.items()},
        "archetype_distribution": {key: _round4(value) for key, value in archetype_distribution.items()},
        "early_route_diversity": _round4(route_entropy),
        "class_archetype_expression": _round4(class_expression),
        "low_level_strategy_concentration": _round4(strategy_concentration),
        "route_alignment_score": _round4(alignment_score),
        "anti_monopoly": anti_monopoly,
    }
