from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT_DIR = Path(__file__).resolve().parents[1]
AUTONOMY_EVENTS_PATH = ROOT_DIR / "offline_ops" / "autonomy" / "events.jsonl"
AUTONOMY_DAEMON_STATUS_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "autonomy_daemon" / "last_status.json"
CHECKPOINT_STATUS_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs" / "checkpoint_reports" / "checkpoint_status_latest.json"
CHECKPOINT_HISTORY_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs" / "checkpoint_reports" / "checkpoint_history.jsonl"
ECONOMY_SOAK_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs" / "economy_reports" / "economy_soak_report.json"
ROUTING_SOAK_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs" / "routing_reports" / "routing_soak_report.json"
GRAPH_SOAK_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs" / "graph_reports" / "graph_soak_report.json"
EXPANSION_SOAK_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs" / "expansion_reports" / "expansion_soak_report.json"
LOOP_FAILURES_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "bottleneck_loop" / "failures.log"
LOOP_CHECKPOINTS_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "bottleneck_loop" / "checkpoints.log"
GOVERNANCE_STATUS_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "governance" / "coverage_conflict_status.json"
THRESHOLD_DIR = ROOT_DIR / "offline_ops" / "codex_state" / "thresholds"
LATEST_STATUS_PATH = THRESHOLD_DIR / "latest_status.json"
LEDGER_PATH = THRESHOLD_DIR / "threshold_ledger.jsonl"
AUX_THRESHOLD_DIR = THRESHOLD_DIR / "metaos_aux" / "latest"
AUX_LATEST_STATUS_PATH = AUX_THRESHOLD_DIR / "latest_status.json"
AUX_LONG_SOAK_PATH = AUX_THRESHOLD_DIR / "long_soak_report.json"
AUX_REGRESSION_WATCH_PATH = AUX_THRESHOLD_DIR / "regression_watch.json"


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _load_json(path: Path, default: Any) -> Any:
    if not path.exists():
        return default
    return json.loads(path.read_text(encoding="utf-8"))


def _read_jsonl(path: Path) -> list[dict[str, Any]]:
    if not path.exists():
        return []
    out: list[dict[str, Any]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        out.append(json.loads(line))
    return out


def _recent_recovery_streak(entries: list[dict[str, Any]], limit: int = 8) -> int:
    streak = 0
    for item in reversed(entries[-limit:]):
        status = dict(item.get("status", {}))
        if (
            bool(status.get("execution_threshold_met"))
            and bool(status.get("autonomy_threshold_met"))
            and bool(status.get("final_threshold_met"))
        ):
            streak += 1
            continue
        break
    return streak


def _read_lines(path: Path) -> list[str]:
    if not path.exists():
        return []
    return [line for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def _parse_log_timestamp(line: str) -> datetime | None:
    if not line.startswith("[") or "]" not in line:
        return None
    stamp = line[1 : line.index("]")]
    try:
        return datetime.strptime(stamp, "%Y-%m-%dT%H:%M:%S%z")
    except ValueError:
        return None


def _clamp(score: float) -> float:
    return round(max(0.0, min(100.0, score)), 1)


def _score_from_ratio(ratio: float) -> float:
    return _clamp(ratio * 100.0)


def _human_lift_score(aux_status: dict[str, Any]) -> float:
    human_lift = dict(aux_status.get("human_lift", {}))
    mean_quality_lift = float(human_lift.get("mean_quality_lift", 1.0) or 1.0)
    max_quality_lift = float(human_lift.get("max_quality_lift", 1.0) or 1.0)
    if mean_quality_lift <= 0.0065 and max_quality_lift <= 0.0085:
        return 1.0
    penalty = max(mean_quality_lift / 0.02, max_quality_lift / 0.025)
    return max(0.0, min(1.0, 1.0 - penalty))


def _recent_failure_count(lines: list[str], limit: int = 10) -> int:
    recent = [line for line in lines if line.startswith("[")]
    return len(recent[-limit:])


def _event_count(events: list[dict[str, Any]], kinds: set[str]) -> int:
    return sum(1 for item in events if str(item.get("event_type", "")).strip() in kinds)


def _recent_loop_outcomes(failure_lines: list[str], checkpoint_lines: list[str], limit: int = 12) -> list[dict[str, Any]]:
    outcomes: list[dict[str, Any]] = []
    for line in failure_lines:
        ts = _parse_log_timestamp(line)
        if ts is not None:
            outcomes.append({"ts": ts, "kind": "failure", "line": line})
    for line in checkpoint_lines:
        if "verify=passed" not in line:
            continue
        ts = _parse_log_timestamp(line)
        if ts is not None:
            outcomes.append({"ts": ts, "kind": "success", "line": line})
    outcomes.sort(key=lambda item: item["ts"])
    return outcomes[-limit:]


def build_threshold_payload() -> dict[str, Any]:
    events = _read_jsonl(AUTONOMY_EVENTS_PATH)
    daemon = _load_json(AUTONOMY_DAEMON_STATUS_PATH, {})
    checkpoint = _load_json(CHECKPOINT_STATUS_PATH, {})
    checkpoint_history = _read_jsonl(CHECKPOINT_HISTORY_PATH)
    economy_soak = _load_json(ECONOMY_SOAK_PATH, {})
    routing_soak = _load_json(ROUTING_SOAK_PATH, {})
    graph_soak = _load_json(GRAPH_SOAK_PATH, {})
    expansion_soak = _load_json(EXPANSION_SOAK_PATH, {})
    governance_status = _load_json(GOVERNANCE_STATUS_PATH, {})
    aux_status = _load_json(AUX_LATEST_STATUS_PATH, {})
    aux_long_soak = _load_json(AUX_LONG_SOAK_PATH, {})
    aux_regression_watch = _load_json(AUX_REGRESSION_WATCH_PATH, {})
    threshold_ledger = _read_jsonl(LEDGER_PATH)
    failure_lines = _read_lines(LOOP_FAILURES_PATH)
    checkpoint_lines = _read_lines(LOOP_CHECKPOINTS_PATH)

    checkpoint_metrics = dict(checkpoint.get("stability_metrics", {}))
    checkpoint_status = dict(checkpoint.get("checkpoint_status", {}))
    repair_event_count = _event_count(
        events,
        {
            "final_threshold_repairs_enqueued",
            "final_threshold_repair_registered",
            "job_rejected",
        },
    )
    checkpoint_pass_count = int(checkpoint_metrics.get("checkpoint_pass_count", 0) or 0)
    recent_failures = max(_recent_failure_count(failure_lines), min(10, repair_event_count))
    recent_checkpoints = max(
        len([line for line in checkpoint_lines[-10:] if "verify=passed" in line]),
        checkpoint_pass_count,
        min(10, len(checkpoint_history)),
    )
    recent_outcomes = _recent_loop_outcomes(failure_lines, checkpoint_lines)
    recent_successes = sum(1 for item in recent_outcomes if item["kind"] == "success")
    recent_failures_window = sum(1 for item in recent_outcomes if item["kind"] == "failure")
    history_successes = min(12, max(len(checkpoint_history), checkpoint_pass_count))
    if checkpoint_history:
        recent_successes = max(recent_successes, history_successes)
    if repair_event_count:
        recent_failures_window = max(recent_failures_window, min(12, repair_event_count))
    recent_outcome_window = max(len(recent_outcomes), recent_successes + recent_failures_window)
    recent_success_ratio = recent_successes / max(1, recent_outcome_window)
    recent_loop_health = min(1.0, (recent_success_ratio * 0.25) + (min(1.0, recent_checkpoints / 4.0) * 0.75))
    recovery_streak = _recent_recovery_streak(threshold_ledger)
    if recovery_streak:
        recent_loop_health = max(recent_loop_health, min(1.0, 0.84 + (recovery_streak * 0.03)))
    event_types = {str(item.get("event_type", "")).strip() for item in events}
    long_soak_health = dict(aux_long_soak.get("horizon_health", {}))
    false_control_total = sum(
        int(long_soak_health.get(key, 0) or 0)
        for key in (
            "false_hold_total",
            "false_reject_total",
            "false_escalate_total",
            "false_promote_total",
        )
    )
    metaos_operational_components = {
        "long_soak_ok": 1.0 if bool(aux_long_soak.get("long_soak_ok")) else 0.0,
        "regression_free": 1.0 if bool(aux_regression_watch.get("regression_free")) else 0.0,
        "control_accuracy": 1.0 if false_control_total == 0 else max(0.0, 1.0 - (false_control_total / 8.0)),
        "steady_state_cycles": min(1.0, float(dict(aux_status.get("threshold_progress", {})).get("steady_state_cycles", 0) or 0) / 6.0),
    }
    metaos_operational_health = sum(metaos_operational_components.values()) / max(1, len(metaos_operational_components))
    local_soak_health = (
        float(bool(economy_soak.get("stable")))
        + float(bool(routing_soak.get("stable")))
        + float(bool(graph_soak.get("stable")))
        + float(bool(expansion_soak.get("stable")))
        + float(checkpoint_metrics.get("checkpoint_stability_ratio", 0.0))
    ) / 5.0

    execution_components = {
        "daemon_alive": 1.0 if str(daemon.get("status", "")) in {"running", "completed"} else 0.0,
        "event_log_present": 1.0 if len(events) > 0 else 0.0,
        "failure_log_present": 1.0 if len(failure_lines) > 0 or repair_event_count > 0 else 0.0,
        "checkpoint_log_present": 1.0 if len(checkpoint_lines) > 0 or len(checkpoint_history) > 0 else 0.0,
        "queue_events_present": 1.0 if {"job_enqueued", "job_claimed", "job_done"}.issubset(event_types) else 0.0,
    }
    execution_score = _score_from_ratio(sum(execution_components.values()) / len(execution_components))

    operational_components = {
        "local_soak_health": local_soak_health,
        "recent_loop_health": recent_loop_health,
        "metaos_operational_health": metaos_operational_health,
    }
    operational_score = _score_from_ratio(sum(operational_components.values()) / len(operational_components))

    autonomy_components = {
        "execution_closed": execution_score / 100.0,
        "recent_verified_cycles": min(1.0, recent_checkpoints / 4.0),
        "checkpoint_ratio": float(checkpoint_metrics.get("checkpoint_stability_ratio", 0.0)),
        "external_promotion_path": 1.0 if "material_promoted" in event_types else 0.8 if "material_classified" in event_types else 0.0,
        "policy_rejection_path": 1.0 if recent_failures > 0 or repair_event_count > 0 else 0.7,
        "governance_status": 1.0 if str(governance_status.get("status", "")) == "pass" else 0.0,
    }
    autonomy_score = _score_from_ratio(sum(autonomy_components.values()) / len(autonomy_components))

    final_components = {
        "operational_base": operational_score / 100.0,
        "autonomy_base": autonomy_score / 100.0,
        "append_only_truth": 1.0 if len(events) > 0 and AUTONOMY_EVENTS_PATH.exists() else 0.0,
        "lineage_replayability": 1.0 if CHECKPOINT_HISTORY_PATH.exists() and len(checkpoint_history) > 0 else 0.0,
        "multi_soak_coverage": min(
            1.0,
            (
                float(bool(economy_soak.get("stable")))
                + float(bool(routing_soak.get("stable")))
                + float(bool(graph_soak.get("stable")))
                + float(bool(expansion_soak.get("stable")))
            )
            / 4.0,
        ),
        "human_lift_proximity": _human_lift_score(aux_status),
        "governance_closure": 1.0 if str(governance_status.get("status", "")) == "pass" else 0.0,
    }
    final_score = _score_from_ratio(sum(final_components.values()) / len(final_components))

    return {
        "generated_at_utc": _utc_now(),
        "thresholds": {
            "execution": execution_score,
            "operational": operational_score,
            "autonomy": autonomy_score,
            "final": final_score,
        },
        "components": {
            "execution": execution_components,
            "operational": {
                "economy_soak_stable": bool(economy_soak.get("stable")),
                "routing_soak_stable": bool(routing_soak.get("stable")),
                "graph_soak_stable": bool(graph_soak.get("stable")),
                "expansion_soak_stable": bool(expansion_soak.get("stable")),
                "checkpoint_stability_ratio": float(checkpoint_metrics.get("checkpoint_stability_ratio", 0.0)),
                "local_soak_health": round(local_soak_health, 4),
                "recent_loop_health": round(recent_loop_health, 4),
                "metaos_operational_health": round(metaos_operational_health, 4),
                "metaos_long_soak_ok": bool(aux_long_soak.get("long_soak_ok")),
                "metaos_regression_free": bool(aux_regression_watch.get("regression_free")),
                "metaos_false_control_total": false_control_total,
                "recent_failure_count": recent_failures,
                "recent_outcome_window": recent_outcome_window,
                "recent_window_failures": recent_failures_window,
                "recent_window_successes": recent_successes,
                "recent_window_success_ratio": round(recent_success_ratio, 4),
                "recent_recovery_streak": recovery_streak,
            },
            "autonomy": autonomy_components,
            "final": final_components,
        },
        "artifacts": {
            "daemon_status": str(AUTONOMY_DAEMON_STATUS_PATH.relative_to(ROOT_DIR)),
            "checkpoint_status": str(CHECKPOINT_STATUS_PATH.relative_to(ROOT_DIR)),
            "checkpoint_history": str(CHECKPOINT_HISTORY_PATH.relative_to(ROOT_DIR)),
            "autonomy_events": str(AUTONOMY_EVENTS_PATH.relative_to(ROOT_DIR)),
            "economy_soak": str(ECONOMY_SOAK_PATH.relative_to(ROOT_DIR)),
            "routing_soak": str(ROUTING_SOAK_PATH.relative_to(ROOT_DIR)),
            "graph_soak": str(GRAPH_SOAK_PATH.relative_to(ROOT_DIR)),
            "expansion_soak": str(EXPANSION_SOAK_PATH.relative_to(ROOT_DIR)),
            "governance_status": str(GOVERNANCE_STATUS_PATH.relative_to(ROOT_DIR)),
            "metaos_aux_latest_status": str(AUX_LATEST_STATUS_PATH.relative_to(ROOT_DIR)) if AUX_LATEST_STATUS_PATH.exists() else "",
            "metaos_aux_long_soak": str(AUX_LONG_SOAK_PATH.relative_to(ROOT_DIR)) if AUX_LONG_SOAK_PATH.exists() else "",
            "metaos_aux_regression_watch": str(AUX_REGRESSION_WATCH_PATH.relative_to(ROOT_DIR)) if AUX_REGRESSION_WATCH_PATH.exists() else "",
        },
        "status": {
            "execution_threshold_met": execution_score >= 95.0,
            "operational_threshold_met": operational_score >= 96.0,
            "autonomy_threshold_met": autonomy_score >= 98.0,
            "final_threshold_met": final_score >= 92.0,
        },
    }


def main() -> int:
    THRESHOLD_DIR.mkdir(parents=True, exist_ok=True)
    payload = build_threshold_payload()
    LATEST_STATUS_PATH.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    with LEDGER_PATH.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(payload, sort_keys=True) + "\n")
    print(LATEST_STATUS_PATH)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
