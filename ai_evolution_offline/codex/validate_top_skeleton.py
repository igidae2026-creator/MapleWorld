#!/usr/bin/env python3

from __future__ import annotations

import csv
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]

GOAL_PATH = ROOT / "GOAL.md"
CONSTITUTION_PATH = ROOT / "METAOS_CONSTITUTION.md"
RULE_CARDS_PATH = ROOT / "RULE_CARDS.jsonl"
LAYER1_PATH = ROOT / "CHECKLIST_LAYER1_목표조건.md"
LAYER2_PATH = ROOT / "CHECKLIST_LAYER2_모듈책임.md"
LAYER3_PATH = ROOT / "CHECKLIST_LAYER3_REPO매핑.md"
PATCH_METHOD_PATH = ROOT / "CHECKLIST_METHOD_패치.md"
COVERAGE_PATH = ROOT / "COVERAGE_AUDIT.csv"
CONFLICT_PATH = ROOT / "CONFLICT_LOG.csv"
KOREAN_PLAYER_FEEL_STANDARD_PATH = ROOT / "docs" / "standards" / "KOREAN_PLAYER_FEEL_STANDARD.md"
DOCUMENTATION_MAP_PATH = ROOT / "docs" / "standards" / "DOCUMENTATION_MAP.md"
PLAYER_EXPERIENCE_PATH = ROOT / "offline_ops" / "codex_state" / "simulation_runs" / "player_experience_metrics_latest.json"
GOVERNANCE_STATUS_PATH = ROOT / "offline_ops" / "codex_state" / "governance" / "coverage_conflict_status.json"
FINAL_THRESHOLD_EVAL_PATH = ROOT / "offline_ops" / "codex_state" / "final_threshold_eval.json"
REPO_SURFACE_STATUS_PATH = ROOT / "offline_ops" / "codex_state" / "governance" / "repo_surface_status.json"


def _check(condition: bool, code: str, detail: str) -> dict[str, object]:
    return {
        "code": code,
        "status": "PASS" if condition else "FAIL",
        "detail": detail,
    }


def _read_jsonl(path: Path) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        text = line.strip()
        if not text:
            continue
        rows.append(json.loads(text))
    return rows


def _read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def main() -> int:
    checks: list[dict[str, object]] = []

    required_files = [
        GOAL_PATH,
        CONSTITUTION_PATH,
        RULE_CARDS_PATH,
        LAYER1_PATH,
        LAYER2_PATH,
        LAYER3_PATH,
        PATCH_METHOD_PATH,
        COVERAGE_PATH,
        CONFLICT_PATH,
        KOREAN_PLAYER_FEEL_STANDARD_PATH,
        DOCUMENTATION_MAP_PATH,
        FINAL_THRESHOLD_EVAL_PATH,
        REPO_SURFACE_STATUS_PATH,
    ]
    for path in required_files:
        checks.append(_check(path.exists(), "required_file", f"{path.name} exists"))

    if not all(item["status"] == "PASS" for item in checks):
        payload = {"status": "FAIL", "checks": checks}
        print(json.dumps(payload, ensure_ascii=True, indent=2))
        return 1

    goal_text = GOAL_PATH.read_text(encoding="utf-8")
    constitution_text = CONSTITUTION_PATH.read_text(encoding="utf-8")
    layer1_text = LAYER1_PATH.read_text(encoding="utf-8")
    layer2_text = LAYER2_PATH.read_text(encoding="utf-8")
    layer3_text = LAYER3_PATH.read_text(encoding="utf-8")
    patch_text = PATCH_METHOD_PATH.read_text(encoding="utf-8")
    rule_cards = _read_jsonl(RULE_CARDS_PATH)
    coverage_rows = _read_csv(COVERAGE_PATH)
    conflict_rows = _read_csv(CONFLICT_PATH)
    final_eval = json.loads(FINAL_THRESHOLD_EVAL_PATH.read_text(encoding="utf-8"))

    checks.extend(
        [
            _check("L0  RULE_CARDS" in goal_text and "A2  CONFLICT_LOG" in goal_text, "goal_declares_skeleton", "GOAL.md declares fixed top skeleton"),
            _check("Authority flows in this order" in constitution_text, "constitution_authority_order", "constitution defines authority order"),
            _check("player-experience floor" in layer1_text or "player-experience" in layer1_text, "layer1_player_floor", "Layer 1 defines player-experience floor"),
            _check("Player Experience Evaluation Module" in layer2_text, "layer2_eval_module", "Layer 2 maps evaluation responsibility"),
            _check("metrics_engine/player_experience_metrics.py" in layer3_text, "layer3_player_metric_mapping", "Layer 3 maps player-experience metric file"),
            _check("update `GOAL.md`" in patch_text and "update `METAOS_CONSTITUTION.md`" in patch_text, "patch_order_top_first", "patch method requires top-first governance update"),
            _check(len(rule_cards) >= 8, "rule_card_count", "top-level rule inventory has minimum expected seed count"),
            _check(
                any(row.get("status") == "partial" for row in coverage_rows) or GOVERNANCE_STATUS_PATH.exists(),
                "coverage_gap_visible",
                "coverage audit exposes remaining gaps or is enforced by a dedicated governance audit artifact",
            ),
            _check(len(conflict_rows) >= 3, "conflict_rows_present", "conflict log contains active tracked conflicts"),
            _check(
                all(
                    key in final_eval
                    for key in (
                        "final_threshold_ready",
                        "failed_criteria",
                        "blocking_evidence",
                        "next_required_repairs",
                        "quality_lift_if_human_intervenes",
                    )
                ),
                "final_threshold_bundle_contract",
                "final threshold bundle artifact exists with the required contract",
            ),
            _check(
                "Korean Player-Feel Rule" in goal_text and "game-literate Korean player" in goal_text,
                "goal_korean_player_feel_rule",
                "GOAL.md anchors Korean player-feel authority",
            ),
            _check(
                "Korean player-facing standard" in layer1_text or "Korean player-feel authority" in layer1_text,
                "layer1_korean_player_feel_mapping",
                "Layer 1 maps Korean player-feel objective authority",
            ),
            _check(
                "docs/standards/DOCUMENTATION_MAP.md" in layer3_text and "Documentation Authority" in layer3_text,
                "layer3_documentation_authority_mapping",
                "Layer 3 maps documentation authority files",
            ),
            _check(
                DOCUMENTATION_MAP_PATH.exists()
                and "Top Authority" in DOCUMENTATION_MAP_PATH.read_text(encoding="utf-8")
                and "Legacy Or Session-Bound Material" in DOCUMENTATION_MAP_PATH.read_text(encoding="utf-8"),
                "documentation_map_authority_split",
                "documentation map classifies authority and legacy docs",
            ),
            _check(
                REPO_SURFACE_STATUS_PATH.exists()
                and json.loads(REPO_SURFACE_STATUS_PATH.read_text(encoding="utf-8")).get("status") == "pass",
                "repo_surface_audit_passes",
                "repo surface audit confirms MSW runtime, offline control, evaluation, and doc buckets are intact",
            ),
        ]
    )

    if PLAYER_EXPERIENCE_PATH.exists():
        player_payload = json.loads(PLAYER_EXPERIENCE_PATH.read_text(encoding="utf-8"))
        checks.extend(
            [
                _check("active_player_bottleneck" in player_payload, "player_bottleneck_visible", "player bottleneck is machine-visible"),
                _check(player_payload.get("active_player_bottleneck") in player_payload.get("triage_order", []), "player_bottleneck_ranked", "active player bottleneck belongs to triage order"),
            ]
        )
    else:
        checks.append(_check(False, "player_metrics_missing", "player experience metrics file exists"))

    status = "PASS" if all(item["status"] == "PASS" for item in checks) else "FAIL"
    payload = {"status": status, "checks": checks}
    print(json.dumps(payload, ensure_ascii=True, indent=2))
    return 0 if status == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
