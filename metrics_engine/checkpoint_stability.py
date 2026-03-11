from __future__ import annotations

import json
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
RUNS_DIR = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs"
QUALITY_PATH = RUNS_DIR / "quality_metrics_latest.json"
FUN_GUARD_PATH = RUNS_DIR / "fun_guard_metrics_latest.json"
EXPANSION_PATH = RUNS_DIR / "expansion_metrics_latest.json"
WORLD_GRAPH_PATH = RUNS_DIR / "world_graph_metrics_latest.json"
CHANNEL_ROUTING_PATH = RUNS_DIR / "channel_routing_metrics_latest.json"
ECONOMY_PRESSURE_PATH = RUNS_DIR / "economy_pressure_metrics_latest.json"
LIVEOPS_OVERRIDE_PATH = RUNS_DIR / "liveops_override_metrics_latest.json"
OUTPUT_PATH = RUNS_DIR / "checkpoint_stability_latest.json"

CHECKPOINT_ORDER = [
    "world_stability",
    "player_flow_stability",
    "economy_stability",
    "meta_stability",
    "content_scale_out_stability",
    "liveops_override_safety",
]


def _load_json(path: Path) -> dict[str, object]:
    return json.loads(path.read_text(encoding="utf-8"))


def _clamp(value: float, floor: float = 0.0, ceiling: float = 1.0) -> float:
    return max(floor, min(ceiling, value))


def _range_center(value: str) -> float:
    left, _, right = str(value).partition("~")
    return (float(left) + float(right)) / 2.0


def _checkpoint(stable: bool, score: float, reasons: list[str], details: dict[str, object]) -> dict[str, object]:
    return {
        "stable": bool(stable),
        "score": round(_clamp(score), 4),
        "status": "stable" if stable else "unstable",
        "reasons": reasons,
        "details": details,
    }


def build_checkpoint_stability(
    quality: dict[str, object] | None = None,
    fun_guard: dict[str, object] | None = None,
    expansion: dict[str, object] | None = None,
    world_graph: dict[str, object] | None = None,
    channel_routing: dict[str, object] | None = None,
    economy_pressure: dict[str, object] | None = None,
    liveops_override: dict[str, object] | None = None,
) -> dict[str, object]:
    quality = quality or _load_json(QUALITY_PATH)
    fun_guard = fun_guard or _load_json(FUN_GUARD_PATH)
    expansion = expansion or _load_json(EXPANSION_PATH)
    world_graph = world_graph or _load_json(WORLD_GRAPH_PATH)
    channel_routing = channel_routing or _load_json(CHANNEL_ROUTING_PATH)
    economy_pressure = economy_pressure or _load_json(ECONOMY_PRESSURE_PATH)
    liveops_override = liveops_override or _load_json(LIVEOPS_OVERRIDE_PATH)

    checkpoints: dict[str, dict[str, object]] = {}

    dead_zones = len(world_graph.get("dead_zones", []))
    overcrowded_nodes = len(world_graph.get("overcrowded_nodes", []))
    bottlenecks = len(world_graph.get("exploration_bottlenecks", []))
    path_entropy = float(world_graph.get("path_entropy", 0.0))
    exploration_flow = float(world_graph.get("exploration_flow", 0.0))
    travel_friction = float(world_graph.get("travel_friction", 1.0))

    world_reasons: list[str] = []
    if str(world_graph.get("status")) != "allow":
        world_reasons.append("world graph guard rejected")
    if dead_zones > 1:
        world_reasons.append(f"dead zone count too high: {dead_zones} > 1")
    if bottlenecks > 2:
        world_reasons.append(f"bottleneck count too high: {bottlenecks} > 2")
    if path_entropy < 0.62:
        world_reasons.append(f"path entropy below floor: {path_entropy:.4f} < 0.6200")
    world_score = (
        (1.0 if str(world_graph.get("status")) == "allow" else 0.0) * 0.25
        + _clamp(1.0 - (dead_zones / 4.0)) * 0.15
        + _clamp(1.0 - (overcrowded_nodes / 4.0)) * 0.1
        + _clamp(1.0 - (bottlenecks / 4.0)) * 0.1
        + _clamp(path_entropy / 0.8) * 0.2
        + _clamp(exploration_flow / 0.7) * 0.1
        + _clamp(1.0 - max(0.0, travel_friction - 0.4) / 0.4) * 0.1
    )
    checkpoints["world_stability"] = _checkpoint(
        stable=not world_reasons,
        score=world_score,
        reasons=world_reasons,
        details={
            "dead_zones": dead_zones,
            "overcrowded_nodes": overcrowded_nodes,
            "bottlenecks": bottlenecks,
            "path_entropy": round(path_entropy, 4),
            "exploration_flow": round(exploration_flow, 4),
            "travel_friction": round(travel_friction, 4),
        },
    )

    stagnation_index = float(dict(channel_routing.get("exploration_stagnation", {})).get("index", 1.0))
    progression_center = _range_center(str(quality.get("progression_pacing", "0~0")))
    overcrowded_maps = len(channel_routing.get("overcrowded_maps", []))
    hotspot_score = float(channel_routing.get("hotspot_score", 1.0))

    flow_reasons: list[str] = []
    if str(channel_routing.get("status")) != "allow":
        flow_reasons.append("channel routing guard rejected")
    if stagnation_index > 0.56:
        flow_reasons.append(f"exploration stagnation too high: {stagnation_index:.4f} > 0.5600")
    if progression_center < 78:
        flow_reasons.append(f"progression pacing center below floor: {progression_center:.1f} < 78.0")
    flow_score = (
        (1.0 if str(channel_routing.get("status")) == "allow" else 0.0) * 0.3
        + _clamp(1.0 - stagnation_index / 0.7) * 0.2
        + _clamp(1.0 - (overcrowded_maps / 6.0)) * 0.15
        + _clamp(1.0 - hotspot_score / 0.65) * 0.15
        + _clamp(progression_center / 90.0) * 0.2
    )
    checkpoints["player_flow_stability"] = _checkpoint(
        stable=not flow_reasons,
        score=flow_score,
        reasons=flow_reasons,
        details={
            "stagnation_index": round(stagnation_index, 4),
            "overcrowded_maps": overcrowded_maps,
            "hotspot_score": round(hotspot_score, 4),
            "progression_pacing_center": round(progression_center, 2),
        },
    )

    economy_guard = dict(fun_guard.get("economy_drift_guard", {}))
    sink_ratio = float(economy_guard.get("sink_ratio", 0.0))
    inflation_ratio = float(economy_guard.get("inflation_ratio", 1.0))
    inflation_pressure = float(economy_pressure.get("inflation_pressure", 1.0))

    economy_reasons: list[str] = []
    if str(economy_pressure.get("status")) != "allow":
        economy_reasons.append("economy pressure guard rejected")
    if str(economy_guard.get("status")) != "allow":
        economy_reasons.append("economy drift guard rejected")
    if sink_ratio < 0.75:
        economy_reasons.append(f"economy sink ratio below floor: {sink_ratio:.4f} < 0.7500")
    if inflation_ratio > 0.25:
        economy_reasons.append(f"economy inflation ratio above cap: {inflation_ratio:.4f} > 0.2500")
    economy_score = (
        (1.0 if str(economy_pressure.get("status")) == "allow" else 0.0) * 0.3
        + (1.0 if str(economy_guard.get("status")) == "allow" else 0.0) * 0.2
        + _clamp(sink_ratio / 1.2) * 0.2
        + _clamp(1.0 - inflation_ratio / 0.3) * 0.15
        + _clamp(1.0 - inflation_pressure / 0.3) * 0.15
    )
    checkpoints["economy_stability"] = _checkpoint(
        stable=not economy_reasons,
        score=economy_score,
        reasons=economy_reasons,
        details={
            "sink_ratio": round(sink_ratio, 4),
            "inflation_ratio": round(inflation_ratio, 4),
            "inflation_pressure": round(inflation_pressure, 4),
            "economy_guard_status": str(economy_guard.get("status", "unknown")),
        },
    )

    strategy_guard = dict(fun_guard.get("strategy_diversity_guard", {}))
    reward_guard = dict(fun_guard.get("reward_identity_diversity_guard", {}))
    overall_center = _range_center(str(quality.get("overall_quality_estimate", "0~0")))

    meta_reasons: list[str] = []
    if str(fun_guard.get("patch_veto")) != "allow":
        meta_reasons.append("fun guard patch veto active")
    if str(expansion.get("expansion_veto")) != "allow":
        meta_reasons.append("identity expansion veto active")
    if str(strategy_guard.get("status")) != "allow":
        meta_reasons.append("strategy diversity guard rejected")
    if str(reward_guard.get("status")) != "allow":
        meta_reasons.append("reward identity guard rejected")
    if overall_center < 78:
        meta_reasons.append(f"overall quality center below floor: {overall_center:.1f} < 78.0")
    meta_score = (
        (1.0 if str(fun_guard.get("patch_veto")) == "allow" else 0.0) * 0.3
        + (1.0 if str(expansion.get("expansion_veto")) == "allow" else 0.0) * 0.2
        + (1.0 if str(strategy_guard.get("status")) == "allow" else 0.0) * 0.15
        + (1.0 if str(reward_guard.get("status")) == "allow" else 0.0) * 0.15
        + _clamp(overall_center / 90.0) * 0.2
    )
    checkpoints["meta_stability"] = _checkpoint(
        stable=not meta_reasons,
        score=meta_score,
        reasons=meta_reasons,
        details={
            "overall_quality_center": round(overall_center, 2),
            "patch_veto": str(fun_guard.get("patch_veto")),
            "expansion_veto": str(expansion.get("expansion_veto")),
            "strategy_guard_status": str(strategy_guard.get("status", "unknown")),
            "reward_guard_status": str(reward_guard.get("status", "unknown")),
        },
    )

    bundle_a = dict(expansion.get("bundle_a_starter_world_identity", {}))
    bundle_b = dict(expansion.get("bundle_b_quest_progression_scaffolding", {}))
    bundle_c = dict(expansion.get("bundle_c_boss_chase_identity", {}))
    bundle_d = dict(expansion.get("bundle_d_strategy_expression", {}))
    content_density = float(world_graph.get("content_density", 0.0))
    node_count = int(dict(world_graph.get("counts", {})).get("nodes", 0))

    content_reasons: list[str] = []
    for label, bundle in (("A", bundle_a), ("B", bundle_b), ("C", bundle_c), ("D", bundle_d)):
        if str(bundle.get("status")) != "allow":
            content_reasons.append(f"expansion bundle {label} rejected")
    if content_density < 0.6:
        content_reasons.append(f"content density below floor: {content_density:.4f} < 0.6000")
    if node_count < 12:
        content_reasons.append(f"world graph node count below floor: {node_count} < 12")
    content_score = (
        (1.0 if str(bundle_a.get("status")) == "allow" else 0.0) * 0.15
        + (1.0 if str(bundle_b.get("status")) == "allow" else 0.0) * 0.15
        + (1.0 if str(bundle_c.get("status")) == "allow" else 0.0) * 0.15
        + (1.0 if str(bundle_d.get("status")) == "allow" else 0.0) * 0.15
        + _clamp(content_density / 0.9) * 0.2
        + _clamp(node_count / 20.0) * 0.2
    )
    checkpoints["content_scale_out_stability"] = _checkpoint(
        stable=not content_reasons,
        score=content_score,
        reasons=content_reasons,
        details={
            "bundle_status": {
                "A": str(bundle_a.get("status", "unknown")),
                "B": str(bundle_b.get("status", "unknown")),
                "C": str(bundle_c.get("status", "unknown")),
                "D": str(bundle_d.get("status", "unknown")),
            },
            "content_density": round(content_density, 4),
            "node_count": node_count,
        },
    )

    liveops_reasons = list(liveops_override.get("reasons", []))
    if str(liveops_override.get("status")) != "allow" and not liveops_reasons:
        liveops_reasons.append("live-ops override guard rejected")
    liveops_score = float(liveops_override.get("override_plane_score", 0.0))
    checkpoints["liveops_override_safety"] = _checkpoint(
        stable=str(liveops_override.get("status")) == "allow",
        score=liveops_score,
        reasons=liveops_reasons,
        details={
            "rollback_readiness": bool(liveops_override.get("rollback_readiness")),
            "policy_plane_coverage": float(liveops_override.get("policy_plane_coverage", 0.0)),
            "override_actions_total": int(dict(liveops_override.get("adaptive_override_actions", {})).get("total", 0)),
            "active_rollback_safe_profiles": int(
                dict(liveops_override.get("intervention_profiles", {})).get("active_rollback_safe", 0)
            ),
        },
    )

    stable_count = sum(1 for key in CHECKPOINT_ORDER if checkpoints[key]["stable"])
    overall_stability_index = sum(float(checkpoints[key]["score"]) for key in CHECKPOINT_ORDER) / len(CHECKPOINT_ORDER)
    all_stable = stable_count == len(CHECKPOINT_ORDER)

    return {
        "checkpoint_order": CHECKPOINT_ORDER,
        "checkpoints": checkpoints,
        "stability_metrics": {
            "checkpoint_pass_count": stable_count,
            "checkpoint_total": len(CHECKPOINT_ORDER),
            "checkpoint_stability_ratio": round(stable_count / len(CHECKPOINT_ORDER), 4),
            "overall_stability_index": round(overall_stability_index, 4),
        },
        "status": "stable" if all_stable else "unstable",
    }


def write_checkpoint_stability(
    quality: dict[str, object] | None = None,
    fun_guard: dict[str, object] | None = None,
    expansion: dict[str, object] | None = None,
    world_graph: dict[str, object] | None = None,
    channel_routing: dict[str, object] | None = None,
    economy_pressure: dict[str, object] | None = None,
    liveops_override: dict[str, object] | None = None,
    output_path: Path = OUTPUT_PATH,
) -> dict[str, object]:
    payload = build_checkpoint_stability(
        quality=quality,
        fun_guard=fun_guard,
        expansion=expansion,
        world_graph=world_graph,
        channel_routing=channel_routing,
        economy_pressure=economy_pressure,
        liveops_override=liveops_override,
    )
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return payload


if __name__ == "__main__":
    write_checkpoint_stability()
    print(OUTPUT_PATH)
