from __future__ import annotations

import csv
from collections import Counter, defaultdict
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
DROP_TABLE_PATH = ROOT_DIR / "data" / "balance" / "drops" / "drop_table.csv"


def _load_drop_rows() -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    with DROP_TABLE_PATH.open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            rows.append(
                {
                    "item_id": str(row.get("item_id", "")),
                    "drop_rate": float(row.get("drop_rate", 0.0) or 0.0),
                    "rarity_band": str(row.get("rarity_band", "common")).lower(),
                    "reward_identity": str(row.get("reward_identity", "currency")),
                }
            )
    return rows


def _boss_tier_for_level(level: int) -> str:
    if level <= 35:
        return "tier_early"
    if level <= 80:
        return "tier_mid"
    return "tier_late"


def _build_region_map_index(world_graph: dict[str, object]) -> tuple[dict[str, str], dict[str, str]]:
    edges = list(world_graph.get("edges", []))
    map_to_region: dict[str, str] = {}
    map_to_route: dict[str, str] = {}

    # Pull route role from map nodes.
    nodes = list(world_graph.get("nodes", []))
    for node in nodes:
        if str(node.get("node_type")) == "map":
            map_to_route[str(node.get("node_id", ""))] = str(node.get("role", "safe"))

    for edge in edges:
        if str(edge.get("edge_type")) != "contains":
            continue
        src = str(edge.get("from", ""))
        dst = str(edge.get("to", ""))
        if src.startswith("region:") and dst.startswith("map:"):
            map_to_region[dst] = src

    return map_to_region, map_to_route


def _adaptive_drop_multiplier(
    inflation_pressure: float,
    drop_pressure: float,
    scarcity_index: float,
    farming_loop_risk: float,
) -> float:
    reduction = (
        max(0.0, inflation_pressure - 0.10) * 0.55
        + max(0.0, drop_pressure - 1.00) * 0.30
        + max(0.0, farming_loop_risk - 0.45) * 0.35
    )
    relief = max(0.0, scarcity_index - 0.50) * 0.22
    return max(0.68, min(1.08, 1.0 - reduction + relief))


def _sink_amplification(inflation_pressure: float, farming_loop_risk: float) -> float:
    gain = max(0.0, inflation_pressure - 0.10) * 1.35 + max(0.0, farming_loop_risk - 0.40) * 0.55
    return max(0.90, min(1.60, 1.0 + gain))


def _scarcity_balance_factor(scarcity_index: float, reward_saturation_index: float) -> float:
    if scarcity_index < 0.30:
        return max(0.82, 1.0 - (0.30 - scarcity_index) * 0.55)
    if reward_saturation_index > 0.72:
        return max(0.80, 1.0 - (reward_saturation_index - 0.72) * 0.50)
    return min(1.12, 1.0 + (scarcity_index - 0.48) * 0.16)


def _reward_distribution_smoothing(route_pressure: dict[str, float]) -> float:
    if not route_pressure:
        return 1.0
    values = list(route_pressure.values())
    spread = max(values) - min(values)
    return max(0.82, min(1.08, 1.0 - spread * 0.18))


def _regional_pressure_redistribution(region_pressure: dict[str, float]) -> dict[str, float]:
    if not region_pressure:
        return {}
    average = sum(region_pressure.values()) / max(1, len(region_pressure))
    out: dict[str, float] = {}
    for key, value in region_pressure.items():
        # bring heavy regions down slightly and light regions up slightly
        out[key] = round(max(0.75, min(1.25, 1.0 - (value - average) * 0.14)), 4)
    return out


def _boss_field_separation_preservation(drop_rows: list[dict[str, object]]) -> float:
    boss = sum(float(row["drop_rate"]) for row in drop_rows if str(row["rarity_band"]) == "boss")
    field = sum(float(row["drop_rate"]) for row in drop_rows if str(row["rarity_band"]) != "boss")
    if field <= 0:
        return 1.0
    ratio = boss / field
    # desired small but meaningful boss premium band
    if ratio < 0.02:
        return 1.08
    if ratio > 0.09:
        return 0.88
    return 1.0


def _anti_loop_dampening(route_pressure: dict[str, float], routing_hotspot_score: float) -> float:
    if not route_pressure:
        return 1.0
    peak = max(route_pressure.values())
    return max(0.74, min(1.02, 1.0 - max(0.0, peak - 1.10) * 0.30 - max(0.0, routing_hotspot_score - 1.0) * 0.28))


def _propagate_reward_pressure(world_graph: dict[str, object], map_pressure: dict[str, float]) -> dict[str, float]:
    nodes = [str(node.get("node_id", "")) for node in list(world_graph.get("nodes", []))]
    edges = list(world_graph.get("edges", []))

    pressure = {node: 0.0 for node in nodes}
    for map_id, value in map_pressure.items():
        if map_id in pressure:
            pressure[map_id] = float(value)

    # one-step and two-step attenuation propagation using friction and progression weights
    adjacency: dict[str, list[tuple[str, float]]] = defaultdict(list)
    for edge in edges:
        src = str(edge.get("from", ""))
        dst = str(edge.get("to", ""))
        friction = float(edge.get("friction", 0.25))
        progression_weight = float(edge.get("progression_weight", 0.5))
        attenuation = max(0.12, min(0.92, (1.0 - friction) * (0.42 + progression_weight * 0.38)))
        adjacency[src].append((dst, attenuation))

    for _ in range(2):
        updates: dict[str, float] = defaultdict(float)
        for src, value in pressure.items():
            if value <= 0.0:
                continue
            for dst, attenuation in adjacency.get(src, []):
                updates[dst] += value * attenuation * 0.22
        for node, delta in updates.items():
            pressure[node] = min(2.5, pressure.get(node, 0.0) + delta)

    return {k: round(v, 4) for k, v in sorted(pressure.items()) if v > 0.0}


def _intervention_profiles(
    inflation_pressure: float,
    farming_loop_risk: float,
    reward_saturation_index: float,
) -> list[dict[str, object]]:
    return [
        {
            "profile_id": "profile_guarded_stability",
            "trigger": {
                "inflation_pressure_max": 0.14,
                "farming_loop_risk_max": 0.46,
                "reward_saturation_index_max": 0.72,
            },
            "actions": {
                "dynamic_drop_adjustment": 0.98,
                "sink_amplification": 1.10,
                "scarcity_balancing": 1.02,
                "anti_loop_dampening": 0.94,
            },
            "rollback_safe": True,
            "active": inflation_pressure <= 0.14 and farming_loop_risk <= 0.46 and reward_saturation_index <= 0.72,
        },
        {
            "profile_id": "profile_inflation_crush",
            "trigger": {
                "inflation_pressure_min": 0.15,
            },
            "actions": {
                "dynamic_drop_adjustment": 0.90,
                "sink_amplification": 1.35,
                "scarcity_balancing": 0.95,
                "anti_loop_dampening": 0.88,
            },
            "rollback_safe": True,
            "active": inflation_pressure > 0.15,
        },
        {
            "profile_id": "profile_hotspot_breaker",
            "trigger": {
                "farming_loop_risk_min": 0.47,
                "reward_saturation_index_min": 0.70,
            },
            "actions": {
                "dynamic_drop_adjustment": 0.86,
                "sink_amplification": 1.22,
                "scarcity_balancing": 0.92,
                "anti_loop_dampening": 0.82,
                "regional_reward_redistribution": 1.18,
            },
            "rollback_safe": True,
            "active": farming_loop_risk > 0.47 and reward_saturation_index > 0.70,
        },
    ]


def build_economy_pressure_model(
    economy: dict[str, object],
    world: dict[str, object],
    loops: int,
) -> dict[str, object]:
    drop_rows = _load_drop_rows()
    world_graph = dict(world.get("world_graph_model", {}))
    routing = dict(world.get("channel_routing_model", {}))

    total_mesos_created = float(economy.get("total_mesos_created", 0.0) or 0.0)
    total_mesos_removed = float(economy.get("total_mesos_removed", 0.0) or 0.0)
    sink_ratio = total_mesos_removed / max(1.0, total_mesos_created)

    # Economy pressure foundation
    inflation_pressure = max(0.0, (1.0 / max(0.05, sink_ratio)) - 0.10)
    routing_pressure = {str(k): float(v) for k, v in dict(routing.get("post_adaptation_pressure", {})).items()}
    drop_pressure = max(routing_pressure.values()) if routing_pressure else 0.0

    item_generation = sum(float(row["drop_rate"]) for row in drop_rows) * max(1, loops)
    rare_item_generation = sum(
        float(row["drop_rate"]) for row in drop_rows if str(row["rarity_band"]) in {"rare", "elite", "boss"}
    ) * max(1, loops)
    reward_scarcity_index = max(0.0, min(1.0, 1.0 - (rare_item_generation / max(0.01, item_generation))))

    identity_totals: dict[str, float] = {}
    for row in drop_rows:
        identity = str(row["reward_identity"]).strip() or "currency"
        identity_totals[identity] = identity_totals.get(identity, 0.0) + float(row["drop_rate"])
    max_identity = max(identity_totals.values()) if identity_totals else 0.0
    total_identity = sum(identity_totals.values()) if identity_totals else 1.0
    reward_saturation_index = max_identity / max(0.001, total_identity)

    item_desirability_gradient = max(
        0.0,
        min(
            1.0,
            (rare_item_generation / max(0.01, item_generation))
            * (1.0 - reward_saturation_index + 0.2),
        ),
    )

    # Route, region, and boss-tier tracking.
    map_to_region, map_to_route = _build_region_map_index(world_graph)
    route_totals: Counter[str] = Counter()
    region_totals: Counter[str] = Counter()
    for map_id, pressure in routing_pressure.items():
        route_totals[map_to_route.get(map_id, "safe")] += pressure
        region_totals[map_to_region.get(map_id, "region:unknown")] += pressure

    boss_tier_sources: Counter[str] = Counter()
    for node in list(world_graph.get("nodes", [])):
        if str(node.get("node_type")) != "boss":
            continue
        tier = _boss_tier_for_level(int(node.get("min_level", 30)))
        boss_tier_sources[tier] += float(node.get("desirability_hint", 0.75))

    farming_loop_risk = max(0.0, min(1.0, (drop_pressure - 0.95) * 0.9 + (reward_saturation_index - 0.55) * 1.1))
    sink_effectiveness = max(0.0, min(1.8, sink_ratio))
    currency_velocity_proxy = max(0.0, (total_mesos_created / max(1.0, total_mesos_removed)) * (1.0 + drop_pressure * 0.08))

    drop_multiplier = _adaptive_drop_multiplier(
        inflation_pressure,
        drop_pressure,
        reward_scarcity_index,
        farming_loop_risk,
    )
    sink_amplification = _sink_amplification(inflation_pressure, farming_loop_risk)
    scarcity_balancing = _scarcity_balance_factor(reward_scarcity_index, reward_saturation_index)
    reward_distribution_smoothing = _reward_distribution_smoothing(dict(route_totals))
    regional_reward_redistribution = _regional_pressure_redistribution(dict(region_totals))
    boss_field_separation_preservation = _boss_field_separation_preservation(drop_rows)
    anti_loop_dampening = _anti_loop_dampening(dict(route_totals), drop_pressure)

    adjusted_item_generation = (
        item_generation
        * drop_multiplier
        * scarcity_balancing
        * reward_distribution_smoothing
        * boss_field_separation_preservation
        * anti_loop_dampening
    )
    adjusted_mesos_removed = total_mesos_removed * sink_amplification

    # Source/sink tracking by region, route, and boss tier
    mesos_sources_by_region = {
        region: round(total_mesos_created * (value / max(0.001, sum(region_totals.values()))), 4)
        for region, value in sorted(region_totals.items())
    }
    mesos_sinks_by_region = {
        region: round(adjusted_mesos_removed * (value / max(0.001, sum(region_totals.values()))), 4)
        for region, value in sorted(region_totals.items())
    }
    item_sources_by_route = {
        route: round(item_generation * (value / max(0.001, sum(route_totals.values()))), 4)
        for route, value in sorted(route_totals.items())
    }
    item_sinks_by_route = {
        route: round(adjusted_item_generation * (value / max(0.001, sum(route_totals.values()))), 4)
        for route, value in sorted(route_totals.items())
    }
    item_sources_by_boss_tier = {
        tier: round(item_generation * 0.20 * (value / max(0.001, sum(boss_tier_sources.values()))), 4)
        for tier, value in sorted(boss_tier_sources.items())
    }

    node_reward_pressure = _propagate_reward_pressure(world_graph, routing_pressure)
    intervention_profiles = _intervention_profiles(
        inflation_pressure,
        farming_loop_risk,
        reward_saturation_index,
    )

    return {
        "economy_flow": {
            "mesos_generation": round(total_mesos_created, 4),
            "mesos_removed": round(total_mesos_removed, 4),
            "item_generation": round(item_generation, 4),
            "adjusted_item_generation": round(adjusted_item_generation, 4),
            "adjusted_mesos_removed": round(adjusted_mesos_removed, 4),
            "sink_ratio": round(sink_ratio, 4),
            "sink_effectiveness": round(sink_effectiveness, 4),
            "currency_velocity_proxy": round(currency_velocity_proxy, 4),
        },
        "sink_source_tracking": {
            "mesos_sources_by_region": mesos_sources_by_region,
            "mesos_sinks_by_region": mesos_sinks_by_region,
            "item_sources_by_route": item_sources_by_route,
            "item_sinks_by_route": item_sinks_by_route,
            "item_sources_by_boss_tier": item_sources_by_boss_tier,
        },
        "reward_pressure_propagation": {
            "node_reward_pressure": node_reward_pressure,
            "regional_reward_redistribution": regional_reward_redistribution,
        },
        "adaptive_controls": {
            "dynamic_drop_adjustment": round(drop_multiplier, 4),
            "scarcity_balancing": round(scarcity_balancing, 4),
            "sink_amplification": round(sink_amplification, 4),
            "reward_distribution_smoothing": round(reward_distribution_smoothing, 4),
            "regional_reward_pressure_redistribution": regional_reward_redistribution,
            "boss_field_reward_separation_preservation": round(boss_field_separation_preservation, 4),
            "anti_loop_economy_dampening": round(anti_loop_dampening, 4),
            "rollback_safe_economy_intervention_profiles": intervention_profiles,
        },
        "pressure_context": {
            "inflation_pressure": round(inflation_pressure, 4),
            "drop_pressure": round(drop_pressure, 4),
            "reward_scarcity_index": round(reward_scarcity_index, 4),
            "item_desirability_gradient": round(item_desirability_gradient, 4),
            "reward_saturation_index": round(reward_saturation_index, 4),
            "farming_loop_risk": round(farming_loop_risk, 4),
        },
    }
