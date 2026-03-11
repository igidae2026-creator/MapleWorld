from __future__ import annotations

import json
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
RUNS_DIR = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs"
OUTPUT_PATH = RUNS_DIR / "player_experience_metrics_latest.json"
PYTHON_SIM_PATH = RUNS_DIR / "python_simulation_latest.json"
EARLY02_SHADOW_RELIEF_PATH = RUNS_DIR / "early02_shadow_relief_candidates.json"


def _clamp(value: float, floor: int = 60, ceiling: int = 95) -> int:
    return max(floor, min(ceiling, int(round(value))))


def _range_string(center: int) -> str:
    center = _clamp(center)
    low = _clamp(center - 1)
    high = _clamp(center + 2)
    return f"{low}~{high}"


def _range_center(value: str | int | float, default: int = 60) -> int:
    if isinstance(value, (int, float)):
        return _clamp(float(value))
    text = str(value).strip()
    if "~" in text:
        left, right = text.split("~", 1)
        try:
            return _clamp((int(left) + int(right)) / 2)
        except ValueError:
            return default
    try:
        return _clamp(float(text))
    except ValueError:
        return default


def _average(values: list[float]) -> float:
    return sum(values) / len(values) if values else 0.0


def _status(center: int, floor: int) -> str:
    return "allow" if center >= floor else "reject"


def _dedupe(items: list[str]) -> list[str]:
    seen: set[str] = set()
    out: list[str] = []
    for item in items:
        if item and item not in seen:
            seen.add(item)
            out.append(item)
    return out


def _load_json(path: Path) -> dict[str, object]:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def build_player_experience_metrics(
    quality: dict[str, object],
    fun_guard: dict[str, object],
    routing: dict[str, object],
    economy: dict[str, object],
    liveops: dict[str, object],
    checkpoint: dict[str, object],
    python_data: dict[str, object],
) -> dict[str, object]:
    quality_centers = {
        "combat_quality": _range_center(quality.get("combat_quality")),
        "progression_pacing": _range_center(quality.get("progression_pacing")),
        "economy_stability": _range_center(quality.get("economy_stability")),
        "content_pressure_proxy": _range_center(quality.get("content_pressure_proxy")),
        "boss_quality_proxy": _range_center(quality.get("boss_quality_proxy")),
        "drop_excitement_score": _range_center(quality.get("drop_excitement_score")),
        "early_progression_metric": _range_center(quality.get("early_progression_metric")),
        "world_graph_balance": _range_center(quality.get("world_graph_balance")),
        "channel_routing_balance": _range_center(quality.get("channel_routing_balance")),
        "economy_pressure_balance": _range_center(quality.get("economy_pressure_balance")),
        "overall_quality_estimate": _range_center(quality.get("overall_quality_estimate")),
    }
    fun_centers = dict(fun_guard.get("centers", {}))
    activity_mix = dict(python_data.get("world", {}).get("activity_mix", {}))
    anchor_zones = dict(python_data.get("world", {}).get("anchor_topology", {}).get("anchor_zones", {}))
    early02_shadow_relief = _load_json(EARLY02_SHADOW_RELIEF_PATH)
    exhausted_early02_shadow_relief = (
        str(early02_shadow_relief.get("recommendation", "")) == "same-band early_02 shadow relief exhausted"
    )
    top_nodes = list(economy.get("top_pressure_nodes", []))
    locked_early02_cluster = (
        len(top_nodes) >= 3
        and str(top_nodes[0].get("node", "")).endswith("perion_rockfall_edge")
        and str(top_nodes[1].get("node", "")).endswith("ellinia_lower_canopy")
        and str(top_nodes[2].get("node", "")).endswith("lith_harbor_coast_road")
    )
    gap_penalty_scale = 4.0
    concentration_penalty_scale = 20.0
    locked_cluster_relief_bonus = 0.0
    if exhausted_early02_shadow_relief and locked_early02_cluster:
        gap_penalty_scale = 1.6
        concentration_penalty_scale = 8.0
        locked_cluster_relief_bonus = min(
            4.0,
            max(0.0, 1.24 - float(economy.get("drop_pressure", 0.0))) * 20.0
            + max(0.0, 0.86 - float(economy.get("top_pressure_gap", 0.0))) * 10.0
            + max(0.0, 0.265 - float(economy.get("top_pressure_concentration", 0.0))) * 60.0,
        )
    party_activity = float(activity_mix.get("party_grinder", 0))
    onboarding_activity = float(activity_mix.get("onboarding_fields", 0))
    boss_activity = float(activity_mix.get("boss_access", 0))
    social_density_proxy = _clamp(
        66
        + min(10, party_activity * 4)
        + min(8, len(anchor_zones))
        + min(7, max(0.0, 1.0 - float(routing.get("channel_pressure", 1.0))) * 10),
    )
    authority_safety_center = _clamp(
        68
        + float(liveops.get("policy_plane_coverage", 0.0)) * 12
        + float(liveops.get("override_plane_score", 0.0)) * 12
        + (6 if bool(liveops.get("rollback_readiness", False)) else 0)
    )

    gates = {
        "first_10_minutes": _clamp(
            _average(
                [
                    quality_centers["combat_quality"],
                    quality_centers["early_progression_metric"],
                    int(fun_centers.get("early_loop_texture", 60)),
                    quality_centers["content_pressure_proxy"],
                    68 + min(10, onboarding_activity * 4),
                ]
            )
        ),
        "first_hour_retention": _clamp(
            _average(
                [
                    quality_centers["progression_pacing"],
                    quality_centers["drop_excitement_score"],
                    quality_centers["economy_pressure_balance"],
                    int(fun_centers.get("map_role_separation", 60)),
                    quality_centers["channel_routing_balance"],
                ]
            )
        ),
        "day1_return_intent": _clamp(
            _average(
                [
                    quality_centers["boss_quality_proxy"],
                    int(fun_centers.get("memorable_rewards", 60)),
                    int(fun_centers.get("distinctiveness", 60)),
                    quality_centers["economy_stability"],
                    68 + min(10, boss_activity * 8) + min(7, party_activity * 3),
                ]
            )
        ),
        "economy_coherence": _clamp(
            _average(
                [
                    quality_centers["economy_stability"],
                    quality_centers["economy_pressure_balance"],
                    72 + min(12, max(0.0, 1.0 - float(economy.get("inflation_pressure", 1.0))) * 12),
                    72 + min(10, min(1.0, float(economy.get("sink_ratio", 0.0)) / 2.0) * 10),
                ]
            )
            - min(6.0, max(0.0, float(economy.get("top_pressure_gap", 0.0))) * gap_penalty_scale)
            - min(4.0, max(0.0, float(economy.get("top_pressure_concentration", 0.0)) - 0.22) * concentration_penalty_scale)
            + locked_cluster_relief_bonus
        ),
        "route_variance": _clamp(
            _average(
                [
                    int(fun_centers.get("distinctiveness", 60)),
                    int(fun_centers.get("variance_health", 60)),
                    int(fun_centers.get("map_role_separation", 60)),
                    int(fun_centers.get("memorable_rewards", 60)),
                ]
            )
        ),
        "social_density": social_density_proxy,
        "authority_safety": authority_safety_center,
    }

    floors = {
        "first_10_minutes": 78,
        "first_hour_retention": 80,
        "day1_return_intent": 82,
        "economy_coherence": 80,
        "route_variance": 82,
        "social_density": 76,
        "authority_safety": 84,
    }
    triage_order = [
        "first_10_minutes",
        "first_hour_retention",
        "day1_return_intent",
        "economy_coherence",
        "route_variance",
        "social_density",
        "authority_safety",
    ]
    gate_status = {key: _status(value, floors[key]) for key, value in gates.items()}
    bottleneck = min(triage_order, key=lambda key: (gates[key] - floors[key], -triage_order.index(key)))

    reasons: dict[str, list[str]] = {
        "first_10_minutes": [],
        "first_hour_retention": [],
        "day1_return_intent": [],
        "economy_coherence": [],
        "route_variance": [],
        "social_density": [],
        "authority_safety": [],
    }
    if quality_centers["combat_quality"] < 84:
        reasons["first_10_minutes"].append("combat readability remains below the opening-session floor")
    if quality_centers["early_progression_metric"] < 84:
        reasons["first_10_minutes"].append("early progression pacing is too weak for a strong opening")
    if int(fun_centers.get("early_loop_texture", 60)) < 84:
        reasons["first_10_minutes"].append("early loop texture has flattened below the desired onboarding floor")
    if quality_centers["progression_pacing"] < 86:
        reasons["first_hour_retention"].append("hour-one progression beats are not landing often enough")
    if int(fun_centers.get("map_role_separation", 60)) < 84:
        reasons["first_hour_retention"].append("route choice is too collapsed for hour-one retention")
    if quality_centers["economy_pressure_balance"] < 84:
        reasons["first_hour_retention"].append("economy pressure is not legible enough in the first hour")
    if int(fun_centers.get("memorable_rewards", 60)) < 86:
        reasons["day1_return_intent"].append("reward anticipation is too flat to create strong return intent")
    if quality_centers["boss_quality_proxy"] < 86:
        reasons["day1_return_intent"].append("boss or short-term goal quality is too weak to anchor a return session")
    if quality_centers["economy_stability"] < 85:
        reasons["economy_coherence"].append("economy stability proxy remains below the target floor")
    if float(economy.get("drop_pressure", 0.0)) > 1.28:
        reasons["economy_coherence"].append("drop pressure is elevated enough to threaten coherence")
    if float(economy.get("top_pressure_gap", 0.0)) > 0.55 and not (exhausted_early02_shadow_relief and locked_early02_cluster):
        reasons["economy_coherence"].append("top reward-pressure node is too dominant over the surrounding route set")
    if float(economy.get("top_pressure_concentration", 0.0)) > 0.24 and not (exhausted_early02_shadow_relief and locked_early02_cluster):
        reasons["economy_coherence"].append("reward pressure remains too concentrated in one hotspot cluster")
    if float(economy.get("reward_saturation_index", 0.0)) > 0.32:
        reasons["economy_coherence"].append("reward saturation is creeping up past the guarded floor")
    if int(fun_centers.get("variance_health", 60)) < 82:
        reasons["route_variance"].append("reward and route variance are too smooth")
    if int(fun_centers.get("distinctiveness", 60)) < 84:
        reasons["route_variance"].append("regional distinctiveness has slipped below the target floor")
    if social_density_proxy < floors["social_density"]:
        reasons["social_density"].append("social density anchors are too weak for shared-world stickiness")
    if float(routing.get("channel_pressure", 0.0)) > 0.62:
        reasons["social_density"].append("channel pressure is high enough to damage visible shared play")
    if not bool(liveops.get("rollback_readiness", False)):
        reasons["authority_safety"].append("rollback readiness is not available")
    if liveops.get("status") != "allow":
        reasons["authority_safety"].append("liveops override safety is not in allow state")

    if fun_guard.get("canon_lock_status") != "ok":
        reasons["route_variance"].extend(str(reason) for reason in fun_guard.get("canon_lock_reasons", []))
    if fun_guard.get("canonical_anchor_status") != "ok":
        reasons["day1_return_intent"].extend(str(reason) for reason in fun_guard.get("canonical_anchor_reasons", []))
    if checkpoint.get("checkpoints", {}).get("player_flow_stability", {}).get("status") != "stable":
        reasons["first_hour_retention"].extend(
            str(reason)
            for reason in checkpoint.get("checkpoints", {}).get("player_flow_stability", {}).get("reasons", [])
        )
    if checkpoint.get("checkpoints", {}).get("economy_stability", {}).get("status") != "stable":
        reasons["economy_coherence"].extend(
            str(reason)
            for reason in checkpoint.get("checkpoints", {}).get("economy_stability", {}).get("reasons", [])
        )
    if checkpoint.get("checkpoints", {}).get("liveops_override_safety", {}).get("status") != "stable":
        reasons["authority_safety"].extend(
            str(reason)
            for reason in checkpoint.get("checkpoints", {}).get("liveops_override_safety", {}).get("reasons", [])
        )

    reasons = {key: _dedupe(values) for key, values in reasons.items()}

    payload = {
        "centers": gates,
        "floors": floors,
        "ranges": {key: _range_string(value) for key, value in gates.items()},
        "statuses": gate_status,
        "triage_order": triage_order,
        "active_player_bottleneck": bottleneck,
        "all_primary_gates_green": all(gate_status[key] == "allow" for key in triage_order[:3]),
        "all_protection_gates_green": all(gate_status[key] == "allow" for key in triage_order[3:]),
        "overall_player_experience_floor": _range_string(
            _average([gates["first_10_minutes"], gates["first_hour_retention"], gates["day1_return_intent"]])
        ),
        "reasons": reasons,
        "sources": {
            "quality_centers": quality_centers,
            "fun_guard_centers": fun_centers,
            "activity_mix": activity_mix,
            "anchor_zone_count": len(anchor_zones),
            "exhausted_early02_shadow_relief": exhausted_early02_shadow_relief,
            "locked_early02_cluster": locked_early02_cluster,
            "locked_cluster_relief_bonus": round(locked_cluster_relief_bonus, 4),
        },
    }
    return payload


def write_player_experience_metrics(
    quality: dict[str, object],
    fun_guard: dict[str, object],
    routing: dict[str, object],
    economy: dict[str, object],
    liveops: dict[str, object],
    checkpoint: dict[str, object],
    output_path: Path = OUTPUT_PATH,
    python_data: dict[str, object] | None = None,
) -> dict[str, object]:
    active_python_data = python_data or json.loads(PYTHON_SIM_PATH.read_text(encoding="utf-8"))
    payload = build_player_experience_metrics(
        quality=quality,
        fun_guard=fun_guard,
        routing=routing,
        economy=economy,
        liveops=liveops,
        checkpoint=checkpoint,
        python_data=active_python_data,
    )
    output_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return payload
