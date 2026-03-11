from __future__ import annotations

from collections import Counter, defaultdict
from typing import Iterable


def _style_role_weights(style: str) -> dict[str, float]:
    if style == "party_grinder":
        return {"high_risk_high_reward": 0.46, "alternative": 0.33, "safe": 0.21}
    if style == "quest_player":
        return {"alternative": 0.52, "safe": 0.30, "high_risk_high_reward": 0.18}
    return {"safe": 0.41, "alternative": 0.36, "high_risk_high_reward": 0.23}


def _active_band_for_level(level: int, map_nodes: list[dict[str, object]]) -> tuple[int, int]:
    candidates = sorted(
        {
            (int(node.get("min_level", 1)), int(node.get("max_level", 220)))
            for node in map_nodes
        }
    )
    for minimum, maximum in candidates:
        if minimum <= level <= maximum:
            return minimum, maximum
    return candidates[0] if candidates else (1, 220)


def _group_maps_by_region_and_band(graph: dict[str, object]) -> tuple[dict[str, str], dict[tuple[str, int, int], list[dict[str, object]]]]:
    nodes = list(graph.get("nodes", []))
    edges = list(graph.get("edges", []))

    map_nodes = [node for node in nodes if str(node.get("node_type")) == "map"]
    region_for_map: dict[str, str] = {}
    for edge in edges:
        if str(edge.get("edge_type")) != "contains":
            continue
        src = str(edge.get("from", ""))
        dst = str(edge.get("to", ""))
        if src.startswith("region:") and dst.startswith("map:"):
            region_for_map[dst] = src

    grouped: dict[tuple[str, int, int], list[dict[str, object]]] = defaultdict(list)
    for map_node in map_nodes:
        node_id = str(map_node.get("node_id", ""))
        region = region_for_map.get(node_id, "region:unknown")
        minimum = int(map_node.get("min_level", 1))
        maximum = int(map_node.get("max_level", 220))
        grouped[(region, minimum, maximum)].append(map_node)

    for key in list(grouped.keys()):
        grouped[key].sort(key=lambda row: (str(row.get("role", "safe")), str(row.get("node_id", ""))))

    return region_for_map, grouped


def _new_map_state(node: dict[str, object], base_channels: int) -> dict[str, object]:
    throughput_bias = float(node.get("throughput_bias", 1.0))
    reward_bias = float(node.get("reward_bias", 1.0))
    role = str(node.get("role", "safe"))
    target = max(3.0, 3.5 + throughput_bias * 4.5)
    spawn_capacity = max(2.0, 2.2 + throughput_bias * 3.8)
    return {
        "map_id": str(node.get("node_id", "")),
        "role": role,
        "throughput_bias": throughput_bias,
        "reward_bias": reward_bias,
        "target_concurrency": round(target, 4),
        "spawn_capacity": round(spawn_capacity, 4),
        "channel_loads": {f"ch_{idx + 1}": 0.0 for idx in range(base_channels)},
        "channel_count": base_channels,
        "visit_total": 0.0,
        "spawn_multiplier": 1.0,
    }


def _pick_map_for_player(
    maps: list[dict[str, object]],
    style: str,
    player_index: int,
    loop_index: int,
) -> dict[str, object] | None:
    if not maps:
        return None
    role_weights = _style_role_weights(style)
    ranked = sorted(
        maps,
        key=lambda node: (
            -(role_weights.get(str(node.get("role", "safe")), 0.2) * float(node.get("throughput_bias", 1.0))),
            str(node.get("node_id", "")),
        ),
    )
    # deterministic, but rotates choices to avoid static collapse
    offset = (player_index + loop_index) % min(3, len(ranked))
    return ranked[offset]


def _least_loaded_channel(channels: dict[str, float]) -> str:
    return min(channels.items(), key=lambda item: (float(item[1]), item[0]))[0]


def _map_pressure(state: dict[str, object]) -> float:
    return float(state["visit_total"]) / max(1.0, float(state["target_concurrency"]))


def build_channel_routing_model(
    players: Iterable[object],
    loops: int,
    world_graph: dict[str, object],
) -> dict[str, object]:
    region_for_map, grouped = _group_maps_by_region_and_band(world_graph)

    map_states: dict[str, dict[str, object]] = {}
    transitions: Counter[str] = Counter()
    player_unique_maps: dict[int, set[str]] = defaultdict(set)
    player_last_map: dict[int, str] = {}

    # initialize states lazily
    def ensure_state(node: dict[str, object]) -> dict[str, object]:
        map_id = str(node.get("node_id", ""))
        if map_id in map_states:
            return map_states[map_id]
        role = str(node.get("role", "safe"))
        base_channels = 2 if role in {"safe", "alternative"} else 1
        state = _new_map_state(node, base_channels)
        map_states[map_id] = state
        return state

    players_list = list(players)
    for player_index, player in enumerate(players_list):
        level = int(getattr(player, "level", 1))
        style = str(getattr(player, "play_style", "solo_grinder"))

        # choose grouped candidates near level
        candidate_groups = [
            (key, maps)
            for key, maps in grouped.items()
            if int(key[1]) <= level <= int(key[2])
        ]
        if not candidate_groups:
            # fallback to closest band
            band_min, band_max = _active_band_for_level(level, [node for group in grouped.values() for node in group])
            candidate_groups = [
                (key, maps)
                for key, maps in grouped.items()
                if int(key[1]) == band_min and int(key[2]) == band_max
            ]

        candidate_maps = [node for _, maps in sorted(candidate_groups, key=lambda row: (row[0][1], row[0][0])) for node in maps]

        for loop_index in range(loops):
            chosen = _pick_map_for_player(candidate_maps, style, player_index, loop_index)
            if chosen is None:
                continue
            state = ensure_state(chosen)
            channel_id = _least_loaded_channel(dict(state["channel_loads"]))
            load_unit = max(0.15, float(chosen.get("throughput_bias", 1.0)) * 0.62)

            state["channel_loads"][channel_id] = round(float(state["channel_loads"][channel_id]) + load_unit, 4)
            state["visit_total"] = round(float(state["visit_total"]) + load_unit, 4)

            map_id = str(state["map_id"])
            player_unique_maps[player_index].add(map_id)
            previous = player_last_map.get(player_index)
            if previous and previous != map_id:
                transitions[f"{previous}->{map_id}"] += 1
            player_last_map[player_index] = map_id

    # pre-adaptation metrics
    pre_pressure_by_map = {
        map_id: round(_map_pressure(state), 4)
        for map_id, state in sorted(map_states.items())
    }

    # policy 1: soft reroute overloaded traffic to nearby maps in same region
    soft_reroutes: list[dict[str, object]] = []
    maps_by_region: dict[str, list[str]] = defaultdict(list)
    for map_id in map_states:
        maps_by_region[region_for_map.get(map_id, "region:unknown")].append(map_id)
    for region_maps in maps_by_region.values():
        region_maps.sort()

    for map_id, state in sorted(map_states.items()):
        pressure = _map_pressure(state)
        if pressure <= 1.2:
            continue
        region = region_for_map.get(map_id, "region:unknown")
        alternatives = [
            candidate
            for candidate in maps_by_region.get(region, [])
            if candidate != map_id and _map_pressure(map_states[candidate]) < 0.95
        ]
        if not alternatives:
            continue
        destination = alternatives[0]
        excess = max(0.0, float(state["visit_total"]) - float(state["target_concurrency"]) * 1.05)
        reroute_amount = round(excess * 0.5, 4)
        if reroute_amount <= 0.0:
            continue
        state["visit_total"] = round(float(state["visit_total"]) - reroute_amount, 4)
        map_states[destination]["visit_total"] = round(float(map_states[destination]["visit_total"]) + reroute_amount, 4)
        soft_reroutes.append(
            {
                "from": map_id,
                "to": destination,
                "amount": reroute_amount,
            }
        )

    # policy 2: spawn redistribution based on post-reroute pressure
    spawn_redistribution: list[dict[str, object]] = []
    for map_id, state in sorted(map_states.items()):
        pressure = _map_pressure(state)
        if pressure > 1.0:
            multiplier = min(1.45, 1.0 + (pressure - 1.0) * 0.35)
        elif pressure < 0.65:
            multiplier = max(0.82, 1.0 - (0.65 - pressure) * 0.22)
        else:
            multiplier = 1.0
        state["spawn_multiplier"] = round(multiplier, 4)
        spawn_redistribution.append(
            {
                "map_id": map_id,
                "spawn_multiplier": state["spawn_multiplier"],
            }
        )

    # policy 3: dynamic channel balancing
    dynamic_channel_balancing: list[dict[str, object]] = []
    for map_id, state in sorted(map_states.items()):
        target = float(state["target_concurrency"])
        max_channel = max(float(value) for value in dict(state["channel_loads"]).values()) if state["channel_loads"] else 0.0
        if max_channel > target * 0.92:
            new_channel = f"ch_{int(state['channel_count']) + 1}"
            state["channel_count"] = int(state["channel_count"]) + 1
            # re-balance evenly to reduce pressure
            total = float(state["visit_total"])
            even = round(total / max(1, int(state["channel_count"])), 4)
            state["channel_loads"] = {f"ch_{idx + 1}": even for idx in range(int(state["channel_count"]))}
            dynamic_channel_balancing.append(
                {
                    "map_id": map_id,
                    "action": "open_channel",
                    "channel": new_channel,
                    "new_channel_count": int(state["channel_count"]),
                }
            )
        elif max_channel < target * 0.35 and int(state["channel_count"]) > 1:
            state["channel_count"] = int(state["channel_count"]) - 1
            total = float(state["visit_total"])
            even = round(total / max(1, int(state["channel_count"])), 4)
            state["channel_loads"] = {f"ch_{idx + 1}": even for idx in range(int(state["channel_count"]))}
            dynamic_channel_balancing.append(
                {
                    "map_id": map_id,
                    "action": "merge_channel",
                    "new_channel_count": int(state["channel_count"]),
                }
            )

    post_pressure_by_map = {
        map_id: round(_map_pressure(state), 4)
        for map_id, state in sorted(map_states.items())
    }

    unique_map_counts = [len(values) for values in player_unique_maps.values()]
    exploration_stagnation = 1.0
    if unique_map_counts:
        avg_unique = sum(unique_map_counts) / len(unique_map_counts)
        exploration_stagnation = max(0.0, 1.0 - (avg_unique / max(1.0, loops * 0.55)))

    return {
        "node_concurrency": {
            map_id: {
                "visit_total": round(float(state["visit_total"]), 4),
                "target_concurrency": round(float(state["target_concurrency"]), 4),
                "spawn_capacity": round(float(state["spawn_capacity"]), 4),
                "channel_count": int(state["channel_count"]),
                "channel_loads": {k: round(float(v), 4) for k, v in sorted(dict(state["channel_loads"]).items())},
                "spawn_multiplier": round(float(state["spawn_multiplier"]), 4),
                "reward_bias": round(float(state["reward_bias"]), 4),
                "role": str(state["role"]),
            }
            for map_id, state in sorted(map_states.items())
        },
        "pre_adaptation_pressure": pre_pressure_by_map,
        "post_adaptation_pressure": post_pressure_by_map,
        "transition_counts": {k: int(v) for k, v in sorted(transitions.items())},
        "exploration_stagnation_index": round(float(exploration_stagnation), 4),
        "adaptive_policies": {
            "soft_rerouting": soft_reroutes,
            "spawn_redistribution": spawn_redistribution,
            "dynamic_channel_balancing": dynamic_channel_balancing,
        },
    }
