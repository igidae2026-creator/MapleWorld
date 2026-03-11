from __future__ import annotations

import json
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
RUNS_DIR = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs"
OUTPUT_PATH = RUNS_DIR / "economy_pressure_metrics_latest.json"


def _load_python_data() -> dict[str, object]:
    return json.loads((RUNS_DIR / "python_simulation_latest.json").read_text(encoding="utf-8"))


def build_economy_pressure_metrics(python_data: dict[str, object] | None = None) -> dict[str, object]:
    payload = python_data or _load_python_data()
    pressure_model = dict(payload.get("economy_pressure_model", {}))

    flow = dict(pressure_model.get("economy_flow", {}))
    controls = dict(pressure_model.get("adaptive_controls", {}))
    context = dict(pressure_model.get("pressure_context", {}))
    tracking = dict(pressure_model.get("sink_source_tracking", {}))
    propagation = dict(pressure_model.get("reward_pressure_propagation", {}))

    if not flow:
        return {
            "drop_pressure": 0.0,
            "inflation_pressure": 1.0,
            "reward_scarcity_index": 0.0,
            "item_desirability_gradient": 0.0,
            "farming_loop_risk": 1.0,
            "sink_effectiveness": 0.0,
            "currency_velocity_proxy": 0.0,
            "reward_saturation_index": 1.0,
            "detections": {
                "inflation_spikes": [],
                "farming_economy_loops": [],
                "reward_saturation": [],
                "scarcity_collapse": [],
                "route_based_reward_abuse": [],
                "boss_reward_overconcentration": [],
                "region_level_economy_imbalance": [],
            },
            "adaptive_control": {},
            "economy_intervention_profiles": [],
            "status": "reject",
            "reasons": ["economy pressure model missing"],
        }

    drop_pressure = float(context.get("drop_pressure", 0.0))
    inflation_pressure = float(context.get("inflation_pressure", 0.0))
    reward_scarcity_index = float(context.get("reward_scarcity_index", 0.0))
    item_desirability_gradient = float(context.get("item_desirability_gradient", 0.0))
    reward_saturation_index = float(context.get("reward_saturation_index", 1.0))
    farming_loop_risk = float(context.get("farming_loop_risk", 0.0))

    sink_effectiveness = float(flow.get("sink_effectiveness", 0.0))
    currency_velocity_proxy = float(flow.get("currency_velocity_proxy", 0.0))

    dynamic_drop = float(controls.get("dynamic_drop_adjustment", 1.0))
    scarcity_balancing = float(controls.get("scarcity_balancing", 1.0))
    sink_amplification = float(controls.get("sink_amplification", 1.0))
    reward_distribution_smoothing = float(controls.get("reward_distribution_smoothing", 1.0))
    boss_field_separation = float(controls.get("boss_field_reward_separation_preservation", 1.0))
    anti_loop_dampening = float(controls.get("anti_loop_economy_dampening", 1.0))
    intervention_profiles = list(controls.get("rollback_safe_economy_intervention_profiles", []))

    inflation_spikes: list[dict[str, object]] = []
    if inflation_pressure > 0.23:
        inflation_spikes.append({"metric": "inflation_pressure", "value": round(inflation_pressure, 4), "threshold": 0.23})
    if currency_velocity_proxy > 1.85:
        inflation_spikes.append({"metric": "currency_velocity_proxy", "value": round(currency_velocity_proxy, 4), "threshold": 1.85})

    farming_economy_loops: list[dict[str, object]] = []
    if farming_loop_risk > 0.62:
        farming_economy_loops.append({"metric": "farming_loop_risk", "value": round(farming_loop_risk, 4), "threshold": 0.62})
    if drop_pressure > 1.24 and anti_loop_dampening > 0.94:
        farming_economy_loops.append(
            {
                "metric": "anti_loop_dampening_under_response",
                "drop_pressure": round(drop_pressure, 4),
                "anti_loop_dampening": round(anti_loop_dampening, 4),
            }
        )

    reward_saturation: list[dict[str, object]] = []
    if reward_saturation_index > 0.80:
        reward_saturation.append({"metric": "reward_saturation_index", "value": round(reward_saturation_index, 4), "threshold": 0.76})
    if reward_distribution_smoothing > 1.02 and drop_pressure > 1.18:
        reward_saturation.append({"metric": "smoothing_over_relief", "value": round(reward_distribution_smoothing, 4)})

    scarcity_collapse: list[dict[str, object]] = []
    if reward_scarcity_index < 0.18:
        scarcity_collapse.append({"metric": "reward_scarcity_index", "value": round(reward_scarcity_index, 4), "threshold": 0.18})
    if item_desirability_gradient < 0.07:
        scarcity_collapse.append({"metric": "item_desirability_gradient", "value": round(item_desirability_gradient, 4), "threshold": 0.07})

    route_based_reward_abuse: list[dict[str, object]] = []
    route_sources = {str(k): float(v) for k, v in dict(tracking.get("item_sources_by_route", {})).items()}
    if route_sources:
        total_route = sum(route_sources.values()) or 1.0
        for route, value in sorted(route_sources.items()):
            share = value / total_route
            if share > 0.62:
                route_based_reward_abuse.append({"route": route, "share": round(share, 4), "threshold": 0.62})

    boss_reward_overconcentration: list[dict[str, object]] = []
    boss_sources = {str(k): float(v) for k, v in dict(tracking.get("item_sources_by_boss_tier", {})).items()}
    if boss_sources and len(boss_sources) > 1:
        total_boss = sum(boss_sources.values()) or 1.0
        for tier, value in sorted(boss_sources.items()):
            share = value / total_boss
            if share > 0.74:
                boss_reward_overconcentration.append({"boss_tier": tier, "share": round(share, 4), "threshold": 0.74})

    region_level_economy_imbalance: list[dict[str, object]] = []
    region_src = {str(k): float(v) for k, v in dict(tracking.get("mesos_sources_by_region", {})).items()}
    region_sink = {str(k): float(v) for k, v in dict(tracking.get("mesos_sinks_by_region", {})).items()}
    regional_rows: list[tuple[str, float, float, float]] = []
    for region in sorted(set(region_src) | set(region_sink)):
        src = region_src.get(region, 0.0)
        sink = region_sink.get(region, 0.0)
        ratio = src / max(1.0, sink)
        if (src + sink) >= 2500.0:
            regional_rows.append((region, src, sink, ratio))
    if regional_rows:
        avg_ratio = sum(row[3] for row in regional_rows) / len(regional_rows)
        for region, src, sink, ratio in regional_rows:
            ratio_delta = abs((ratio / max(0.0001, avg_ratio)) - 1.0)
            if ratio_delta > 0.45:
                region_level_economy_imbalance.append(
                    {
                        "region": region,
                        "source_to_sink_ratio": round(ratio, 4),
                        "ratio_delta_from_regional_mean": round(ratio_delta, 4),
                        "source": round(src, 4),
                        "sink": round(sink, 4),
                    }
                )

    reasons: list[str] = []
    if inflation_spikes:
        reasons.append(f"inflation spikes detected: {len(inflation_spikes)}")
    if farming_economy_loops:
        reasons.append(f"farming economy loops detected: {len(farming_economy_loops)}")
    if reward_saturation:
        reasons.append(f"reward saturation detected: {len(reward_saturation)}")
    if scarcity_collapse:
        reasons.append(f"scarcity collapse detected: {len(scarcity_collapse)}")
    if route_based_reward_abuse:
        reasons.append(f"route-based reward abuse detected: {len(route_based_reward_abuse)}")
    if boss_reward_overconcentration:
        reasons.append(f"boss reward overconcentration detected: {len(boss_reward_overconcentration)}")
    if region_level_economy_imbalance:
        reasons.append(f"region economy imbalance detected: {len(region_level_economy_imbalance)}")

    # control-health checks (must be active and bounded)
    if abs(dynamic_drop - 1.0) < 0.0001 and (drop_pressure > 1.12 or inflation_pressure > 0.16):
        reasons.append("dynamic drop adjustment inactive")
    if abs(sink_amplification - 1.0) < 0.0001 and (inflation_pressure > 0.16 or farming_loop_risk > 0.55):
        reasons.append("sink amplification inactive")
    if not intervention_profiles:
        reasons.append("rollback-safe intervention profiles missing")

    # include propagated pressure hot nodes for observability
    node_pressure = {str(k): float(v) for k, v in dict(propagation.get("node_reward_pressure", {})).items()}
    top_nodes = sorted(node_pressure.items(), key=lambda item: item[1], reverse=True)[:10]

    top_pressure_nodes = [{"node": node, "pressure": round(value, 4)} for node, value in top_nodes]
    regional_reward_redistribution = dict(propagation.get("regional_reward_redistribution", {}))

    return {
        "drop_pressure": round(drop_pressure, 4),
        "inflation_pressure": round(inflation_pressure, 4),
        "reward_scarcity_index": round(reward_scarcity_index, 4),
        "item_desirability_gradient": round(item_desirability_gradient, 4),
        "farming_loop_risk": round(farming_loop_risk, 4),
        "sink_effectiveness": round(sink_effectiveness, 4),
        "currency_velocity_proxy": round(currency_velocity_proxy, 4),
        "reward_saturation_index": round(reward_saturation_index, 4),
        "economy_flow": {
            "mesos_generation": round(float(flow.get("mesos_generation", 0.0)), 4),
            "mesos_removed": round(float(flow.get("mesos_removed", 0.0)), 4),
            "item_generation": round(float(flow.get("item_generation", 0.0)), 4),
            "adjusted_item_generation": round(float(flow.get("adjusted_item_generation", 0.0)), 4),
            "adjusted_mesos_removed": round(float(flow.get("adjusted_mesos_removed", 0.0)), 4),
        },
        "sink_source_tracking": tracking,
        "top_pressure_nodes": top_pressure_nodes,
        "regional_reward_redistribution": regional_reward_redistribution,
        "reward_pressure_propagation": {
            "top_pressure_nodes": top_pressure_nodes,
            "regional_reward_redistribution": regional_reward_redistribution,
        },
        "detections": {
            "inflation_spikes": inflation_spikes,
            "farming_economy_loops": farming_economy_loops,
            "reward_saturation": reward_saturation,
            "scarcity_collapse": scarcity_collapse,
            "route_based_reward_abuse": route_based_reward_abuse,
            "boss_reward_overconcentration": boss_reward_overconcentration,
            "region_level_economy_imbalance": region_level_economy_imbalance,
        },
        "adaptive_control": {
            "dynamic_drop_adjustments": round(dynamic_drop, 4),
            "scarcity_balancing": round(scarcity_balancing, 4),
            "sink_amplification": round(sink_amplification, 4),
            "reward_distribution_smoothing": round(reward_distribution_smoothing, 4),
            "boss_field_reward_separation_preservation": round(boss_field_separation, 4),
            "anti_loop_economy_dampening": round(anti_loop_dampening, 4),
        },
        "economy_intervention_profiles": intervention_profiles,
        "status": "reject" if reasons else "allow",
        "reasons": reasons,
    }


def write_economy_pressure_metrics(
    python_data: dict[str, object] | None = None,
    output_path: Path = OUTPUT_PATH,
) -> dict[str, object]:
    payload = build_economy_pressure_metrics(python_data)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return payload
