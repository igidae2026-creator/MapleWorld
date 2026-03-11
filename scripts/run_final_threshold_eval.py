from __future__ import annotations

import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT_DIR = Path(__file__).resolve().parents[1]
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from offline_ops.autonomy.event_log import append_event
from offline_ops.autonomy.job_queue import enqueue_job, list_jobs

STATE_DIR = ROOT_DIR / "offline_ops" / "codex_state"
OUTPUT_PATH = STATE_DIR / "final_threshold_eval.json"
THRESHOLD_STATUS_PATH = STATE_DIR / "thresholds" / "latest_status.json"
GOVERNANCE_STATUS_PATH = STATE_DIR / "governance" / "coverage_conflict_status.json"
CHECKPOINT_STABILITY_PATH = STATE_DIR / "simulation_runs" / "checkpoint_stability_latest.json"
PLAYER_METRICS_PATH = STATE_DIR / "simulation_runs" / "player_experience_metrics_latest.json"
ECONOMY_PRESSURE_PATH = STATE_DIR / "simulation_runs" / "economy_pressure_metrics_latest.json"
ROUTING_METRICS_PATH = STATE_DIR / "simulation_runs" / "channel_routing_metrics_latest.json"
LIVEOPS_PATH = STATE_DIR / "simulation_runs" / "liveops_override_metrics_latest.json"
THRESHOLD_AUX_STATUS_PATH = STATE_DIR / "thresholds" / "metaos_aux" / "latest" / "latest_status.json"
THRESHOLD_AUX_LONG_SOAK_PATH = STATE_DIR / "thresholds" / "metaos_aux" / "latest" / "long_soak_report.json"
THRESHOLD_AUX_REGRESSION_PATH = STATE_DIR / "thresholds" / "metaos_aux" / "latest" / "regression_watch.json"
CHECKPOINT_HISTORY_PATH = STATE_DIR / "simulation_runs" / "checkpoint_reports" / "checkpoint_history.jsonl"
AUTONOMY_EVENTS_PATH = ROOT_DIR / "offline_ops" / "autonomy" / "events.jsonl"
DESIGN_GRAPH_INDEX_PATH = ROOT_DIR / "data" / "design_graph" / "index.json"
MSW_RUNTIME_DIR = ROOT_DIR / "msw_runtime"
SHARED_RULES_DIR = ROOT_DIR / "shared_rules"
CONTENT_BUILD_DIR = ROOT_DIR / "content_build"
GOAL_PATH = ROOT_DIR / "GOAL.md"
CONSTITUTION_PATH = ROOT_DIR / "METAOS_CONSTITUTION.md"


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _load_json(path: Path, default: Any) -> Any:
    if not path.exists():
        return default
    return json.loads(path.read_text(encoding="utf-8"))


def _read_jsonl_count(path: Path) -> int:
    if not path.exists():
        return 0
    return sum(1 for line in path.read_text(encoding="utf-8").splitlines() if line.strip())


def _contains_all(path: Path, needles: list[str]) -> bool:
    if not path.exists():
        return False
    text = path.read_text(encoding="utf-8")
    return all(needle in text for needle in needles)


def _repair_template(criterion: str) -> dict[str, Any]:
    mapping = {
        "closed_loop_completion": "repair loop closure, state logging, or next-task continuation",
        "quality_gate_fail_closed": "repair fail-closed gate, veto, or validator path",
        "append_only_lineage_replayability": "repair append-only logs, checkpoint history, or replay lineage",
        "msw_constraint_preservation": "repair MSW authority/topology boundary enforcement",
        "progression_routing_stability": "repair player flow, route variance, social density, or congestion routing",
        "economy_control_stability": "repair map-scoped economy coherence and sink/faucet pressure",
        "liveops_rollback_stability": "repair intervention plane, rollback readiness, or replay boundary",
        "fault_input_absorption": "repair fault hold/reject/recover and intake promotion routing",
        "long_soak_steady_state": "repair soak stability and steady/noop dominance",
        "human_lift_negligible": "repair default output quality until human lift is near zero",
        "scoped_intake_and_promotion": "repair scope/authority/policy intake and promotion path",
    }
    return {
        "criterion": criterion,
        "repair_action": mapping[criterion],
        "job_type": "repair_final_threshold_gap",
        "priority": 30,
    }


def _enqueue_missing_repairs(repairs: list[dict[str, Any]]) -> list[dict[str, Any]]:
    queued = list_jobs("queued")
    running = list_jobs("running")
    seen = {
        str(job.get("payload", {}).get("criterion", ""))
        for job in queued + running
        if str(job.get("job_type", "")) == "repair_final_threshold_gap"
    }
    created: list[dict[str, Any]] = []
    for repair in repairs:
        criterion = str(repair["criterion"])
        if criterion in seen:
            continue
        job = enqueue_job(
            "repair_final_threshold_gap",
            {
                "criterion": criterion,
                "repair_action": repair["repair_action"],
            },
            priority=int(repair.get("priority", 30)),
        )
        created.append({"criterion": criterion, "job_id": job["job_id"]})
        seen.add(criterion)
    return created


def build_final_threshold_eval() -> dict[str, Any]:
    threshold = _load_json(THRESHOLD_STATUS_PATH, {})
    governance = _load_json(GOVERNANCE_STATUS_PATH, {})
    checkpoint = _load_json(CHECKPOINT_STABILITY_PATH, {})
    player = _load_json(PLAYER_METRICS_PATH, {})
    economy = _load_json(ECONOMY_PRESSURE_PATH, {})
    routing = _load_json(ROUTING_METRICS_PATH, {})
    liveops = _load_json(LIVEOPS_PATH, {})
    aux_status = _load_json(THRESHOLD_AUX_STATUS_PATH, {})
    aux_long_soak = _load_json(THRESHOLD_AUX_LONG_SOAK_PATH, {})
    aux_regression = _load_json(THRESHOLD_AUX_REGRESSION_PATH, {})
    design_graph_index = _load_json(DESIGN_GRAPH_INDEX_PATH, {"index": {}})

    threshold_values = dict(threshold.get("thresholds", {}))
    threshold_components = dict(threshold.get("components", {}))
    checkpoint_checks = dict(checkpoint.get("checkpoints", {}))
    player_statuses = dict(player.get("statuses", {}))
    player_ranges = dict(player.get("ranges", {}))
    economy_detections = dict(economy.get("detections", {}))
    liveops_profiles = dict(liveops.get("intervention_profiles", {}))
    aux_human_lift = dict(aux_status.get("human_lift", {}))

    quality_lift_if_human_intervenes = float(aux_human_lift.get("max_quality_lift", 1.0) or 1.0)

    criteria: list[dict[str, Any]] = []

    def add(name: str, passed: bool, evidence: list[str]) -> None:
        criteria.append({"criterion": name, "passed": passed, "evidence": evidence})

    add(
        "closed_loop_completion",
        bool(dict(threshold.get("status", {})).get("execution_threshold_met"))
        and bool(dict(threshold.get("status", {})).get("autonomy_threshold_met")),
        [
            f"execution={threshold_values.get('execution', 0)}",
            f"autonomy={threshold_values.get('autonomy', 0)}",
            f"recent_outcomes={dict(threshold_components.get('operational', {})).get('recent_outcome_window', 0)}",
        ],
    )
    add(
        "quality_gate_fail_closed",
        str(dict(checkpoint_checks.get("meta_stability", {})).get("status", "")) == "stable"
        and int(dict(threshold_components.get("operational", {})).get("recent_failure_count", 0)) >= 1,
        [
            f"meta_stability={dict(checkpoint_checks.get('meta_stability', {})).get('status', 'missing')}",
            f"recent_failure_count={dict(threshold_components.get('operational', {})).get('recent_failure_count', 0)}",
            f"patch_veto={dict(dict(checkpoint_checks.get('meta_stability', {})).get('details', {})).get('patch_veto', 'missing')}",
        ],
    )
    add(
        "append_only_lineage_replayability",
        _read_jsonl_count(AUTONOMY_EVENTS_PATH) > 0
        and _read_jsonl_count(CHECKPOINT_HISTORY_PATH) > 0
        and THRESHOLD_STATUS_PATH.exists(),
        [
            f"autonomy_events={_read_jsonl_count(AUTONOMY_EVENTS_PATH)}",
            f"checkpoint_history={_read_jsonl_count(CHECKPOINT_HISTORY_PATH)}",
            f"threshold_ledger_exists={(STATE_DIR / 'thresholds' / 'threshold_ledger.jsonl').exists()}",
        ],
    )
    add(
        "msw_constraint_preservation",
        str(governance.get("status", "")) == "pass"
        and _contains_all(GOAL_PATH, ["MapleStory Worlds constraints"])
        and _contains_all(
            CONSTITUTION_PATH,
            ["no external backend", "server-authoritative gameplay", "room, world, channel, and instance boundaries"],
        )
        and MSW_RUNTIME_DIR.exists()
        and SHARED_RULES_DIR.exists()
        and CONTENT_BUILD_DIR.exists(),
        [
            f"governance_status={governance.get('status', 'missing')}",
            f"msw_runtime_dir={MSW_RUNTIME_DIR.exists()}",
            f"shared_rules_dir={SHARED_RULES_DIR.exists()}",
            f"content_build_dir={CONTENT_BUILD_DIR.exists()}",
        ],
    )
    add(
        "progression_routing_stability",
        all(str(player_statuses.get(key, "")) == "allow" for key in ("first_10_minutes", "first_hour_retention", "day1_return_intent", "route_variance", "social_density"))
        and str(routing.get("status", "")) == "allow"
        and bool(dict(checkpoint_checks.get("player_flow_stability", {})).get("stable")),
        [
            f"first_10_minutes={player_ranges.get('first_10_minutes', 'missing')}",
            f"first_hour_retention={player_ranges.get('first_hour_retention', 'missing')}",
            f"route_variance={player_ranges.get('route_variance', 'missing')}",
            f"social_density={player_ranges.get('social_density', 'missing')}",
            f"channel_routing_status={routing.get('status', 'missing')}",
        ],
    )
    add(
        "economy_control_stability",
        str(player_statuses.get("economy_coherence", "")) == "allow"
        and str(dict(checkpoint_checks.get("economy_stability", {})).get("status", "")) == "stable"
        and not any(bool(values) for values in economy_detections.values()),
        [
            f"economy_coherence={player_ranges.get('economy_coherence', 'missing')}",
            f"economy_checkpoint={dict(checkpoint_checks.get('economy_stability', {})).get('status', 'missing')}",
            f"currency_velocity_proxy={economy.get('currency_velocity_proxy', 'missing')}",
            f"sink_ratio={dict(dict(checkpoint_checks.get('economy_stability', {})).get('details', {})).get('sink_ratio', 'missing')}",
        ],
    )
    add(
        "liveops_rollback_stability",
        str(liveops.get("status", "")) == "allow"
        and bool(liveops.get("rollback_readiness"))
        and bool(dict(checkpoint_checks.get("liveops_override_safety", {})).get("stable")),
        [
            f"liveops_status={liveops.get('status', 'missing')}",
            f"rollback_readiness={liveops.get('rollback_readiness', False)}",
            f"active_rollback_safe={liveops_profiles.get('active_rollback_safe', 0)}",
        ],
    )
    add(
        "fault_input_absorption",
        float(dict(threshold_components.get("autonomy", {})).get("policy_rejection_path", 0.0)) >= 1.0
        and float(dict(threshold_components.get("autonomy", {})).get("external_promotion_path", 0.0)) >= 1.0,
        [
            f"policy_rejection_path={dict(threshold_components.get('autonomy', {})).get('policy_rejection_path', 0.0)}",
            f"external_promotion_path={dict(threshold_components.get('autonomy', {})).get('external_promotion_path', 0.0)}",
        ],
    )
    add(
        "long_soak_steady_state",
        bool(aux_long_soak.get("long_soak_ok"))
        and bool(aux_regression.get("regression_free"))
        and float(dict(aux_status.get("threshold_progress", {})).get("steady_state_cycles", 0) or 0) >= 6,
        [
            f"long_soak_ok={aux_long_soak.get('long_soak_ok', False)}",
            f"regression_free={aux_regression.get('regression_free', False)}",
            f"steady_state_cycles={dict(aux_status.get('threshold_progress', {})).get('steady_state_cycles', 0)}",
        ],
    )
    add(
        "human_lift_negligible",
        quality_lift_if_human_intervenes <= 0.01,
        [
            f"mean_quality_lift={aux_human_lift.get('mean_quality_lift', 'missing')}",
            f"max_quality_lift={aux_human_lift.get('max_quality_lift', 'missing')}",
        ],
    )
    add(
        "scoped_intake_and_promotion",
        str(governance.get("status", "")) == "pass"
        and bool(dict(design_graph_index.get("index", {})).get("external_material_autonomy"))
        and float(dict(threshold_components.get("autonomy", {})).get("external_promotion_path", 0.0)) >= 1.0,
        [
            f"external_material_autonomy={bool(dict(design_graph_index.get('index', {})).get('external_material_autonomy'))}",
            f"governance_status={governance.get('status', 'missing')}",
            f"external_promotion_path={dict(threshold_components.get('autonomy', {})).get('external_promotion_path', 0.0)}",
        ],
    )

    failed_criteria = [item["criterion"] for item in criteria if not item["passed"]]
    blocking_evidence = [
        {"criterion": item["criterion"], "evidence": item["evidence"]}
        for item in criteria
        if not item["passed"]
    ]
    next_required_repairs = [_repair_template(criterion) for criterion in failed_criteria]
    enqueued_repairs = _enqueue_missing_repairs(next_required_repairs) if failed_criteria else []

    payload = {
        "generated_at_utc": _utc_now(),
        "artifact": str(OUTPUT_PATH.relative_to(ROOT_DIR)),
        "final_threshold_ready": len(failed_criteria) == 0,
        "failed_criteria": failed_criteria,
        "blocking_evidence": blocking_evidence,
        "next_required_repairs": next_required_repairs,
        "quality_lift_if_human_intervenes": round(quality_lift_if_human_intervenes, 4),
        "criteria": criteria,
        "supporting_artifacts": {
            "threshold_status": str(THRESHOLD_STATUS_PATH.relative_to(ROOT_DIR)),
            "governance_status": str(GOVERNANCE_STATUS_PATH.relative_to(ROOT_DIR)),
            "checkpoint_stability": str(CHECKPOINT_STABILITY_PATH.relative_to(ROOT_DIR)),
            "player_metrics": str(PLAYER_METRICS_PATH.relative_to(ROOT_DIR)),
            "economy_pressure": str(ECONOMY_PRESSURE_PATH.relative_to(ROOT_DIR)),
            "routing_metrics": str(ROUTING_METRICS_PATH.relative_to(ROOT_DIR)),
            "liveops_override": str(LIVEOPS_PATH.relative_to(ROOT_DIR)),
            "aux_threshold_status": str(THRESHOLD_AUX_STATUS_PATH.relative_to(ROOT_DIR)),
            "aux_long_soak": str(THRESHOLD_AUX_LONG_SOAK_PATH.relative_to(ROOT_DIR)),
            "aux_regression_watch": str(THRESHOLD_AUX_REGRESSION_PATH.relative_to(ROOT_DIR)),
        },
        "enqueued_repairs": enqueued_repairs,
    }
    return payload


def main() -> int:
    payload = build_final_threshold_eval()
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    append_event(
        "final_threshold_evaluated",
        {
            "final_threshold_ready": payload["final_threshold_ready"],
            "failed_criteria": payload["failed_criteria"],
            "quality_lift_if_human_intervenes": payload["quality_lift_if_human_intervenes"],
        },
    )
    if payload["enqueued_repairs"]:
        append_event("final_threshold_repairs_enqueued", {"repairs": payload["enqueued_repairs"]})
    print(OUTPUT_PATH)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
