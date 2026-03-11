from __future__ import annotations

import json
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
RUNS_DIR = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs"
PYTHON_SIM_PATH = RUNS_DIR / "python_simulation_latest.json"
ECONOMY_PRESSURE_PATH = RUNS_DIR / "economy_pressure_metrics_latest.json"
CHANNEL_ROUTING_PATH = RUNS_DIR / "channel_routing_metrics_latest.json"
RUNTIME_POLICY_BUNDLE_PATH = ROOT_DIR / "offline_ops" / "runtime_policy_bundle.lua"
OUTPUT_PATH = RUNS_DIR / "liveops_override_metrics_latest.json"


def _load_json(path: Path) -> dict[str, object]:
    return json.loads(path.read_text(encoding="utf-8"))


def _clamp(value: float, floor: float = 0.0, ceiling: float = 1.0) -> float:
    return max(floor, min(ceiling, value))


def build_liveops_override_metrics(
    python_data: dict[str, object] | None = None,
    economy_metrics: dict[str, object] | None = None,
    routing_metrics: dict[str, object] | None = None,
) -> dict[str, object]:
    sim = python_data or _load_json(PYTHON_SIM_PATH)
    economy = economy_metrics or _load_json(ECONOMY_PRESSURE_PATH)
    routing = routing_metrics or _load_json(CHANNEL_ROUTING_PATH)

    routing_model = dict(dict(sim.get("world", {})).get("channel_routing_model", {}))
    adaptive_policies = dict(routing_model.get("adaptive_policies", {}))
    policy_actions = {
        "soft_rerouting": len(list(adaptive_policies.get("soft_rerouting", []))),
        "spawn_redistribution": len(list(adaptive_policies.get("spawn_redistribution", []))),
        "dynamic_channel_balancing": len(list(adaptive_policies.get("dynamic_channel_balancing", []))),
    }
    total_override_actions = sum(policy_actions.values())

    intervention_profiles = list(economy.get("economy_intervention_profiles", []))
    active_profiles = [profile for profile in intervention_profiles if profile.get("active")]
    rollback_safe_profiles = [profile for profile in active_profiles if profile.get("rollback_safe")]

    policy_text = RUNTIME_POLICY_BUNDLE_PATH.read_text(encoding="utf-8") if RUNTIME_POLICY_BUNDLE_PATH.exists() else ""
    required_policy_planes = [
        "lineage =",
        "rollback =",
        "evaluation =",
        "selection =",
        "pressureThresholds =",
        "containment =",
        "routing =",
        "savePolicy =",
        "exploitResponse =",
    ]
    present_policy_planes = [token for token in required_policy_planes if token in policy_text]
    policy_plane_coverage = _clamp(len(present_policy_planes) / max(1, len(required_policy_planes)))

    rollback_readiness = (
        len(rollback_safe_profiles) >= 1
        and policy_plane_coverage >= 0.9
        and bool(policy_text)
    )

    rejection_reasons: list[str] = []
    if len(active_profiles) == 0:
        rejection_reasons.append("no active rollback-safe intervention profile")
    if len(rollback_safe_profiles) == 0:
        rejection_reasons.append("active intervention profiles are not rollback-safe")
    if policy_plane_coverage < 0.9:
        rejection_reasons.append(
            f"runtime policy plane coverage below floor: {policy_plane_coverage:.4f} < 0.9000"
        )
    if total_override_actions == 0:
        rejection_reasons.append("override plane produced no adaptive actions")
    if str(routing.get("status")) != "allow":
        rejection_reasons.append("routing guard rejected during live-ops safety evaluation")
    if str(economy.get("status")) != "allow":
        rejection_reasons.append("economy guard rejected during live-ops safety evaluation")

    score = (
        policy_plane_coverage * 0.35
        + _clamp(len(rollback_safe_profiles) / 2.0) * 0.3
        + _clamp(total_override_actions / 6.0) * 0.2
        + (1.0 if str(routing.get("status")) == "allow" else 0.0) * 0.075
        + (1.0 if str(economy.get("status")) == "allow" else 0.0) * 0.075
    )

    return {
        "override_plane_score": round(_clamp(score), 4),
        "rollback_readiness": rollback_readiness,
        "policy_plane_coverage": round(policy_plane_coverage, 4),
        "policy_planes_required": required_policy_planes,
        "policy_planes_present": present_policy_planes,
        "adaptive_override_actions": {
            "total": total_override_actions,
            **policy_actions,
        },
        "intervention_profiles": {
            "total": len(intervention_profiles),
            "active": len(active_profiles),
            "active_rollback_safe": len(rollback_safe_profiles),
            "active_profile_ids": [str(profile.get("profile_id")) for profile in active_profiles],
        },
        "status": "reject" if rejection_reasons else "allow",
        "reasons": rejection_reasons,
    }


def write_liveops_override_metrics(
    python_data: dict[str, object] | None = None,
    economy_metrics: dict[str, object] | None = None,
    routing_metrics: dict[str, object] | None = None,
    output_path: Path = OUTPUT_PATH,
) -> dict[str, object]:
    payload = build_liveops_override_metrics(
        python_data=python_data,
        economy_metrics=economy_metrics,
        routing_metrics=routing_metrics,
    )
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return payload


if __name__ == "__main__":
    write_liveops_override_metrics()
    print(OUTPUT_PATH)
