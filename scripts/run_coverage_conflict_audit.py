from __future__ import annotations

import csv
import json
from datetime import datetime, timezone
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT_DIR / "offline_ops" / "codex_state" / "governance"
STATUS_PATH = OUTPUT_DIR / "coverage_conflict_status.json"
LEDGER_PATH = OUTPUT_DIR / "coverage_conflict_history.jsonl"

GOAL_PATH = ROOT_DIR / "GOAL.md"
CONSTITUTION_PATH = ROOT_DIR / "METAOS_CONSTITUTION.md"
LAYER3_PATH = ROOT_DIR / "CHECKLIST_LAYER3_REPO매핑.md"
PATCH_METHOD_PATH = ROOT_DIR / "CHECKLIST_METHOD_패치.md"
COVERAGE_PATH = ROOT_DIR / "COVERAGE_AUDIT.csv"
CONFLICT_PATH = ROOT_DIR / "CONFLICT_LOG.csv"
PLAYER_EXPERIENCE_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs" / "player_experience_metrics_latest.json"
THRESHOLD_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "thresholds" / "latest_status.json"
FAILURE_LOG_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "bottleneck_loop" / "failures.log"

MODULE_PATHS = {
    "governance": ["GOAL.md", "METAOS_CONSTITUTION.md", "AGENTS.md"],
    "evaluation": ["metrics_engine/player_experience_metrics.py", "offline_ops/codex_state/simulation_runs/player_experience_metrics_latest.json"],
    "autonomous_execution": ["auto_continue.sh", "ai_evolution_offline/codex/run_bottleneck_loop.sh", "offline_ops/autonomy/supervisor.py"],
    "runtime_boundary": ["msw_runtime", "shared_rules", "content_build", "offline_ops"],
    "patch_governance": ["CHECKLIST_METHOD_패치.md", "COVERAGE_AUDIT.csv", "CONFLICT_LOG.csv"],
    "outer_intake_promotion": ["offline_ops/autonomy/policy.py", "offline_ops/autonomy/supervisor.py", "data/design_graph/index.json"],
}


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def _exists(rel_path: str) -> bool:
    return (ROOT_DIR / rel_path).exists()


def build_status() -> dict[str, object]:
    coverage_rows = _read_csv(COVERAGE_PATH)
    conflict_rows = _read_csv(CONFLICT_PATH)
    player = json.loads(PLAYER_EXPERIENCE_PATH.read_text(encoding="utf-8"))
    threshold = json.loads(THRESHOLD_PATH.read_text(encoding="utf-8")) if THRESHOLD_PATH.exists() else {}
    failures = FAILURE_LOG_PATH.read_text(encoding="utf-8") if FAILURE_LOG_PATH.exists() else ""

    coverage_partial = [row for row in coverage_rows if str(row.get("status", "")).strip() == "partial"]
    open_conflicts = [row for row in conflict_rows if str(row.get("status", "")).strip() == "open"]

    goal_text = GOAL_PATH.read_text(encoding="utf-8")
    constitution_text = CONSTITUTION_PATH.read_text(encoding="utf-8")
    patch_text = PATCH_METHOD_PATH.read_text(encoding="utf-8")
    layer3_text = LAYER3_PATH.read_text(encoding="utf-8")

    l0_checks = {
        "goal_exists": GOAL_PATH.exists(),
        "constitution_exists": CONSTITUTION_PATH.exists(),
        "msw_native_rule_visible": "MapleStory Worlds" in goal_text,
    }
    l1_checks = {
        "authority_order": "Authority flows in this order" in constitution_text,
        "outer_autonomy_law": "Outer-Autonomy Law" in constitution_text,
    }
    l2_checks = {
        "active_bottleneck": str(player.get("active_player_bottleneck", "")),
        "all_statuses_allow": all(str(player["statuses"].get(key, "")) == "allow" for key in player.get("statuses", {})),
        "all_primary_gates_green": bool(player.get("all_primary_gates_green")),
        "all_protection_gates_green": bool(player.get("all_protection_gates_green")),
    }
    l3_checks = {name: all(_exists(path) for path in paths) for name, paths in MODULE_PATHS.items()}
    l5_checks = {
        "top_first_order_present": "update `COVERAGE_AUDIT.csv`" in patch_text,
        "weak_patch_rejections_visible": "reason=invalid_decision" in failures or "reason=post_patch_regression" in failures,
    }
    a1_checks = {
        "row_count": len(coverage_rows),
        "partial_gap_count": len(coverage_partial),
        "dedicated_audit_present": _exists("scripts/run_coverage_conflict_audit.py"),
    }
    a2_checks = {
        "row_count": len(conflict_rows),
        "open_conflict_count": len(open_conflicts),
        "tracks_player_vs_structure": any("PlayerFeelVsStructureScores" == row.get("topic") for row in conflict_rows),
        "tracks_patch_vs_practice": any("PatchGovernanceVsExistingPractice" == row.get("topic") for row in conflict_rows),
    }

    layer_status = {
        "L0_rule_cards": {"status": "pass" if all(bool(v) for v in l0_checks.values()) else "fail", "checks": l0_checks},
        "L1_constitution": {"status": "pass" if all(bool(v) for v in l1_checks.values()) else "fail", "checks": l1_checks},
        "L2_goal_floors": {
            "status": "pass" if bool(l2_checks["all_statuses_allow"]) and bool(l2_checks["all_primary_gates_green"]) and bool(l2_checks["all_protection_gates_green"]) else "fail",
            "checks": l2_checks,
        },
        "L3_module_responsibility": {"status": "pass" if all(bool(v) for v in l3_checks.values()) else "fail", "checks": l3_checks},
        "L4_repo_mapping": {
            "status": "pass" if "metrics_engine/player_experience_metrics.py" in layer3_text else "fail",
            "checks": {name: paths for name, paths in MODULE_PATHS.items()},
        },
        "L5_patch_method": {"status": "pass" if all(bool(v) for v in l5_checks.values()) else "fail", "checks": l5_checks},
        "A1_coverage_audit": {
            "status": "pass" if int(a1_checks["row_count"]) >= 10 and bool(a1_checks["dedicated_audit_present"]) else "fail",
            "checks": a1_checks,
        },
        "A2_conflict_log": {
            "status": "pass" if int(a2_checks["open_conflict_count"]) >= 3 and bool(a2_checks["tracks_player_vs_structure"]) and bool(a2_checks["tracks_patch_vs_practice"]) else "fail",
            "checks": a2_checks,
        },
    }

    payload = {
        "generated_at_utc": _utc_now(),
        "status": "pass" if all(str(item["status"]) == "pass" for item in layer_status.values()) else "fail",
        "layer_status": layer_status,
        "summary": {
            "coverage_partial_count": len(coverage_partial),
            "open_conflict_count": len(open_conflicts),
            "execution_threshold": dict(threshold.get("thresholds", {})).get("execution"),
            "autonomy_threshold": dict(threshold.get("thresholds", {})).get("autonomy"),
            "final_threshold": dict(threshold.get("thresholds", {})).get("final"),
        },
    }
    return payload


def main() -> int:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    payload = build_status()
    STATUS_PATH.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    with LEDGER_PATH.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(payload, sort_keys=True) + "\n")
    print(STATUS_PATH)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
