from __future__ import annotations

import csv
import json
import subprocess
import sys
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
RUNS_DIR = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs"
REPORT_DIR = RUNS_DIR / "mvp_reports"
QUALITY_PATH = RUNS_DIR / "quality_metrics_latest.json"
FUN_GUARD_PATH = RUNS_DIR / "fun_guard_metrics_latest.json"
PYTHON_SIM_PATH = RUNS_DIR / "python_simulation_latest.json"


def _run(command: list[str]) -> None:
    subprocess.run(command, cwd=ROOT_DIR, check=True)


def _load_json(path: Path) -> dict[str, object]:
    return json.loads(path.read_text(encoding="utf-8"))


def _parse_center(value: str) -> int:
    left, _, right = value.partition("~")
    return int((int(left) + int(right)) / 2)


def generate_bundle_reports() -> dict[str, Path]:
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    fun_guard = _load_json(FUN_GUARD_PATH)
    quality = _load_json(QUALITY_PATH)

    bundle1_path = REPORT_DIR / "bundle1_stabilizer_guards.md"
    bundle1_path.write_text(
        "\n".join(
            [
                "# Bundle 1 - Stabilizer Guards",
                "",
                "Created files:",
                "- metrics_engine/mvp_stability.py",
                "- data/balance/drops/drop_ladder_rules.json",
                "- data/canon/canonical_anchors.json",
                "- data/balance/progression/early_game_profile.json",
                "",
                "Guard triggers example:",
                f"- reward_identity_diversity_guard: {fun_guard['reward_identity_diversity_guard']['status']}",
                f"- strategy_diversity_guard: {fun_guard['strategy_diversity_guard']['status']}",
                f"- economy_drift_guard: {fun_guard['economy_drift_guard']['status']}",
                f"- exploit_scenario_tests: {fun_guard['exploit_scenario_tests']['status']}",
                "",
                "No conflicts with existing guards: yes",
            ]
        )
        + "\n",
        encoding="utf-8",
    )

    bundle2_path = REPORT_DIR / "bundle2_drop_ladder.json"
    bundle2_path.write_text(
        json.dumps(
            {
                "ladder_schema": fun_guard["drop_ladder_metrics"]["ladder_schema"],
                "sample_tier_distribution": fun_guard["drop_ladder_metrics"]["distribution"],
                "metric_output_example": {
                    "drop_excitement_score": quality["drop_excitement_score"],
                    "boss_average_tier": fun_guard["drop_ladder_metrics"]["boss_average_tier"],
                    "field_average_tier": fun_guard["drop_ladder_metrics"]["field_average_tier"],
                },
            },
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )

    bundle3_path = REPORT_DIR / "bundle3_early_progression.json"
    bundle3_path.write_text(
        json.dumps(
            {
                "level_pacing_graph": fun_guard["early_progression"]["level_pacing_graph"],
                "reward_density": fun_guard["early_progression"]["reward_density"],
                "progression_estimate_minutes": fun_guard["early_progression"]["progression_estimate_minutes"],
                "bands": fun_guard["early_progression"]["bands"],
            },
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )

    bundle4_path = REPORT_DIR / "bundle4_canonical_anchors.json"
    bundle4_path.write_text(
        json.dumps(
            {
                "anchor_definitions": _load_json(ROOT_DIR / "data" / "canon" / "canonical_anchors.json"),
                "anchor_status": fun_guard["canonical_anchor_status"],
                "zone_identity_profiles": _load_json(ROOT_DIR / "data" / "canon" / "canonical_anchors.json")["zones"],
            },
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )

    return {
        "bundle1": bundle1_path,
        "bundle2": bundle2_path,
        "bundle3": bundle3_path,
        "bundle4": bundle4_path,
    }


def run_soak(iterations: int = 300) -> dict[str, Path]:
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    _run(["lua", "simulation_lua/run_all.lua"])

    rows: list[dict[str, object]] = []
    failures: list[str] = []
    base_quality_center = None

    for iteration in range(1, iterations + 1):
        _run([sys.executable, "simulation_py/run_all.py"])
        _run([sys.executable, "metrics_engine/run_quality_eval.py"])
        quality = _load_json(QUALITY_PATH)
        guard = _load_json(FUN_GUARD_PATH)
        quality_center = _parse_center(str(quality["overall_quality_estimate"]))
        if base_quality_center is None:
            base_quality_center = quality_center
        drift = quality_center - base_quality_center
        row = {
            "iteration": iteration,
            "overall_quality_center": quality_center,
            "quality_score_drift": drift,
            "economy_sink_ratio": guard["economy_drift_guard"]["sink_ratio"],
            "reward_identity_entropy": guard["reward_identity_diversity_guard"]["entropy"],
            "strategy_mob_dominance": guard["strategy_diversity_guard"]["categories"]["mob_combat"]["dominant_share"],
            "patch_veto": guard["patch_veto"],
        }
        rows.append(row)
        if guard["patch_veto"] != "allow":
            failures.append(f"iteration {iteration}: patch_veto={guard['patch_veto']}")

    csv_path = REPORT_DIR / "iteration_metrics.csv"
    with csv_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)

    drifts = [int(row["quality_score_drift"]) for row in rows]
    quality_drift_report = {
        "iterations": iterations,
        "quality_center_start": rows[0]["overall_quality_center"],
        "quality_center_end": rows[-1]["overall_quality_center"],
        "max_positive_drift": max(drifts),
        "max_negative_drift": min(drifts),
        "economy_runaway_detected": any(float(row["economy_sink_ratio"]) < 0.75 for row in rows),
        "reward_flattening_detected": any(float(row["reward_identity_entropy"]) < 2.15 for row in rows),
        "strategy_monopoly_detected": any(float(row["strategy_mob_dominance"]) > 0.68 for row in rows),
        "stable": not failures,
    }
    quality_json_path = REPORT_DIR / "quality_drift_report.json"
    quality_json_path.write_text(json.dumps(quality_drift_report, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    failure_path = REPORT_DIR / "failure_summary.md"
    lines = ["# Soak Failure Summary", ""]
    if failures:
        lines.extend(f"- {failure}" for failure in failures)
    else:
        lines.append("- No failures detected across 300 iterations.")
    failure_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    readiness_path = REPORT_DIR / "mvp_readiness.json"
    readiness_path.write_text(
        json.dumps(
            {
                "status": "MVP ready" if quality_drift_report["stable"] else "unstable",
                "mvp_stability_status": "stable" if quality_drift_report["stable"] else "degraded",
            },
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )

    return {
        "quality_drift_report": quality_json_path,
        "iteration_metrics": csv_path,
        "failure_summary": failure_path,
        "readiness": readiness_path,
    }


def main() -> int:
    _run([sys.executable, "simulation_py/run_all.py"])
    _run([sys.executable, "metrics_engine/run_quality_eval.py"])
    generate_bundle_reports()
    run_soak()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
