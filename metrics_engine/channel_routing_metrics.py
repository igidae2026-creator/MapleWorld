from __future__ import annotations

import json
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
RUNS_DIR = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs"
OUTPUT_PATH = RUNS_DIR / "channel_routing_metrics_latest.json"


def _clamp(value: float, floor: float = 0.0, ceiling: float = 1.0) -> float:
    return max(floor, min(ceiling, value))


def _load_python_data() -> dict[str, object]:
    return json.loads((RUNS_DIR / "python_simulation_latest.json").read_text(encoding="utf-8"))


def build_channel_routing_metrics(python_data: dict[str, object] | None = None) -> dict[str, object]:
    payload = python_data or _load_python_data()
    world = dict(payload.get("world", {}))
    routing = dict(world.get("channel_routing_model", {}))

    node_concurrency = {
        str(k): dict(v)
        for k, v in dict(routing.get("node_concurrency", {})).items()
    }
    post_pressure = {
        str(k): float(v)
        for k, v in dict(routing.get("post_adaptation_pressure", {})).items()
    }
    transitions = {
        str(k): int(v)
        for k, v in dict(routing.get("transition_counts", {})).items()
    }
    policies = dict(routing.get("adaptive_policies", {}))

    if not node_concurrency:
        return {
            "node_concurrency": 0.0,
            "hotspot_score": 0.0,
            "channel_pressure": 0.0,
            "spawn_pressure": 0.0,
            "overcrowded_maps": [],
            "farming_hotspots": [],
            "exploration_stagnation": {"index": 1.0, "status": "reject"},
            "policy_actions": {
                "soft_rerouting": 0,
                "spawn_redistribution": 0,
                "dynamic_channel_balancing": 0,
            },
            "status": "reject",
            "reasons": ["channel routing model missing"],
        }

    # core metrics
    utilization_values: list[float] = []
    channel_pressures: list[float] = []
    spawn_pressures: list[float] = []
    map_totals: dict[str, float] = {}

    for map_id, row in sorted(node_concurrency.items()):
        visit_total = float(row.get("visit_total", 0.0))
        target = max(1.0, float(row.get("target_concurrency", 1.0)))
        spawn_capacity = max(0.1, float(row.get("spawn_capacity", 0.1)))
        channel_loads = {str(k): float(v) for k, v in dict(row.get("channel_loads", {})).items()}
        channel_count = max(1, int(row.get("channel_count", 1)))

        utilization = visit_total / target
        utilization_values.append(utilization)
        max_channel = max(channel_loads.values()) if channel_loads else 0.0
        channel_pressures.append(max_channel / max(0.1, target / channel_count))

        spawn_multiplier = max(0.1, float(row.get("spawn_multiplier", 1.0)))
        spawn_pressures.append(visit_total / max(0.1, spawn_capacity * spawn_multiplier))

        map_totals[map_id] = visit_total

    node_concurrency_metric = _clamp(sum(utilization_values) / max(1, len(utilization_values)))
    channel_pressure_metric = _clamp(sum(channel_pressures) / max(1, len(channel_pressures)))
    spawn_pressure_metric = _clamp(sum(spawn_pressures) / max(1, len(spawn_pressures)))

    # hotspot score = top map concentration weighted by reward bias + pressure
    total_visits = sum(map_totals.values()) or 1.0
    hotspot_components: list[float] = []
    for map_id, total in map_totals.items():
        share = total / total_visits
        reward_bias = float(node_concurrency[map_id].get("reward_bias", 1.0))
        pressure = post_pressure.get(map_id, 0.0)
        hotspot_components.append(share * (0.55 + reward_bias * 0.2 + pressure * 0.25))
    hotspot_score = _clamp(sum(hotspot_components))

    # detections
    overcrowded_maps: list[dict[str, object]] = []
    farming_hotspots: list[dict[str, object]] = []

    for map_id, row in sorted(node_concurrency.items()):
        pressure = post_pressure.get(map_id, 0.0)
        visit_total = float(row.get("visit_total", 0.0))
        target = float(row.get("target_concurrency", 1.0))
        reward_bias = float(row.get("reward_bias", 1.0))
        share = visit_total / total_visits

        if pressure > 1.22 and visit_total >= max(4.0, target * 0.9):
            overcrowded_maps.append(
                {
                    "map_id": map_id,
                    "pressure": round(pressure, 4),
                    "visit_total": round(visit_total, 4),
                }
            )
        if share > 0.135 and reward_bias >= 1.1 and pressure > 1.0:
            farming_hotspots.append(
                {
                    "map_id": map_id,
                    "visit_share": round(share, 4),
                    "reward_bias": round(reward_bias, 4),
                    "pressure": round(pressure, 4),
                }
            )

    stagnation_index = float(routing.get("exploration_stagnation_index", 1.0))
    transition_total = sum(transitions.values())
    stagnation_status = "allow"
    stagnation_reasons: list[str] = []
    if stagnation_index > 0.56:
        stagnation_status = "reject"
        stagnation_reasons.append(f"exploration stagnation index too high: {stagnation_index:.4f} > 0.5600")
    if transition_total < 10:
        stagnation_status = "reject"
        stagnation_reasons.append(f"transition count too low: {transition_total} < 10")

    policy_actions = {
        "soft_rerouting": len(list(policies.get("soft_rerouting", []))),
        "spawn_redistribution": len(list(policies.get("spawn_redistribution", []))),
        "dynamic_channel_balancing": len(list(policies.get("dynamic_channel_balancing", []))),
    }

    reasons: list[str] = []
    if len(overcrowded_maps) >= 4:
        reasons.append(f"overcrowded maps detected: {len(overcrowded_maps)}")
    if len(farming_hotspots) >= 3:
        reasons.append(f"farming hotspots detected: {len(farming_hotspots)}")
    reasons.extend(stagnation_reasons)
    if policy_actions["spawn_redistribution"] == 0:
        reasons.append("spawn redistribution policy produced no actions")

    return {
        "node_concurrency": round(node_concurrency_metric, 4),
        "hotspot_score": round(hotspot_score, 4),
        "channel_pressure": round(channel_pressure_metric, 4),
        "spawn_pressure": round(spawn_pressure_metric, 4),
        "overcrowded_maps": overcrowded_maps,
        "farming_hotspots": farming_hotspots,
        "exploration_stagnation": {
            "index": round(stagnation_index, 4),
            "transition_total": transition_total,
            "status": stagnation_status,
            "reasons": stagnation_reasons,
        },
        "policy_actions": policy_actions,
        "status": "reject" if reasons else "allow",
        "reasons": reasons,
    }


def write_channel_routing_metrics(
    python_data: dict[str, object] | None = None,
    output_path: Path = OUTPUT_PATH,
) -> dict[str, object]:
    payload = build_channel_routing_metrics(python_data)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return payload
