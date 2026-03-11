from __future__ import annotations

import csv
import json
import subprocess
import sys
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
RUNS_DIR = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs"
REPORT_DIR = RUNS_DIR / "expansion_reports"
QUALITY_PATH = RUNS_DIR / "quality_metrics_latest.json"
FUN_PATH = RUNS_DIR / "fun_guard_metrics_latest.json"
EXPANSION_PATH = RUNS_DIR / "expansion_metrics_latest.json"
BASE_QUALITY_PATH = RUNS_DIR / "quality_metrics_baseline_pre_expansion.json"
BASE_FUN_PATH = RUNS_DIR / "fun_guard_metrics_baseline_pre_expansion.json"


def _run(command: list[str]) -> None:
    subprocess.run(command, cwd=ROOT_DIR, check=True)


def _load(path: Path) -> dict[str, object]:
    return json.loads(path.read_text(encoding="utf-8"))


def _center(value: str) -> float:
    left, _, right = str(value).partition("~")
    return (float(left) + float(right)) / 2.0


def _capture_after_snapshot() -> tuple[dict[str, object], dict[str, object], dict[str, object]]:
    _run(["lua", "simulation_lua/run_all.lua"])
    _run([sys.executable, "simulation_py/run_all.py"])
    _run([sys.executable, "metrics_engine/run_quality_eval.py"])
    return _load(QUALITY_PATH), _load(FUN_PATH), _load(EXPANSION_PATH)


def _build_comparison(
    base_quality: dict[str, object],
    base_fun: dict[str, object],
    after_quality: dict[str, object],
    after_fun: dict[str, object],
    after_expansion: dict[str, object],
) -> dict[str, object]:
    before_progression_center = _center(str(base_quality["progression_pacing"]))
    after_progression_center = _center(str(after_quality["progression_pacing"]))
    before_boss_center = _center(str(base_quality["boss_quality_proxy"]))
    after_boss_center = _center(str(after_quality["boss_quality_proxy"]))

    before = {
        "progression_smoothness": {
            "quality_progression_center": before_progression_center,
        },
        "reward_identity_clarity": {
            "entropy": float(base_fun["reward_identity_diversity_guard"]["entropy"]),
        },
        "boss_chase_desirability": {
            "boss_quality_center": before_boss_center,
            "field_vs_boss_tier_gap": float(base_fun["drop_ladder_metrics"]["boss_average_tier"]) - float(base_fun["drop_ladder_metrics"]["field_average_tier"]),
        },
        "economy_stability": {
            "sink_ratio": float(base_fun["economy_drift_guard"]["sink_ratio"]),
            "inflation_ratio": float(base_fun["economy_drift_guard"]["inflation_ratio"]),
        },
        "strategy_diversity": {
            "mob_entropy": float(base_fun["strategy_diversity_guard"]["categories"]["mob_combat"]["entropy"]),
            "mob_dominant_share": float(base_fun["strategy_diversity_guard"]["categories"]["mob_combat"]["dominant_share"]),
        },
    }

    bundle_b = dict(after_expansion["bundle_b_quest_progression_scaffolding"])
    bundle_c = dict(after_expansion["bundle_c_boss_chase_identity"])
    bundle_d = dict(after_expansion["bundle_d_strategy_expression"])

    after = {
        "progression_smoothness": {
            "quality_progression_center": after_progression_center,
            "quest_progression_smoothness": float(bundle_b["progression_smoothness"]),
        },
        "reward_identity_clarity": {
            "entropy": float(after_fun["reward_identity_diversity_guard"]["entropy"]),
        },
        "boss_chase_desirability": {
            "boss_quality_center": after_boss_center,
            "boss_desirability_separation": float(bundle_c["boss_desirability_separation"]),
            "field_vs_boss_reward_clarity": float(bundle_c["field_vs_boss_reward_clarity"]),
        },
        "economy_stability": {
            "sink_ratio": float(after_fun["economy_drift_guard"]["sink_ratio"]),
            "inflation_ratio": float(after_fun["economy_drift_guard"]["inflation_ratio"]),
        },
        "strategy_diversity": {
            "mob_entropy": float(after_fun["strategy_diversity_guard"]["categories"]["mob_combat"]["entropy"]),
            "mob_dominant_share": float(after_fun["strategy_diversity_guard"]["categories"]["mob_combat"]["dominant_share"]),
            "early_route_diversity": float(bundle_d["early_route_diversity"]),
            "low_level_strategy_concentration": float(bundle_d["low_level_strategy_concentration"]),
            "class_archetype_expression": float(bundle_d["class_archetype_expression"]),
        },
    }

    return {
        "before": before,
        "after": after,
        "expansion_guard": {
            "fun_guard_patch_veto": after_fun["patch_veto"],
            "expansion_veto": after_expansion["expansion_veto"],
        },
    }


def _run_soak(iterations: int = 120) -> dict[str, object]:
    rows: list[dict[str, object]] = []
    failures: list[str] = []

    for idx in range(1, iterations + 1):
        _run([sys.executable, "simulation_py/run_all.py"])
        _run([sys.executable, "metrics_engine/run_quality_eval.py"])
        quality = _load(QUALITY_PATH)
        fun_guard = _load(FUN_PATH)
        expansion = _load(EXPANSION_PATH)

        row = {
            "iteration": idx,
            "overall_quality_center": _center(str(quality["overall_quality_estimate"])),
            "progression_center": _center(str(quality["progression_pacing"])),
            "reward_entropy": float(fun_guard["reward_identity_diversity_guard"]["entropy"]),
            "economy_sink_ratio": float(fun_guard["economy_drift_guard"]["sink_ratio"]),
            "boss_desirability_separation": float(expansion["bundle_c_boss_chase_identity"]["boss_desirability_separation"]),
            "strategy_concentration": float(expansion["bundle_d_strategy_expression"]["low_level_strategy_concentration"]),
            "fun_guard_veto": str(fun_guard["patch_veto"]),
            "expansion_veto": str(expansion["expansion_veto"]),
        }
        rows.append(row)

        if row["fun_guard_veto"] != "allow":
            failures.append(f"iteration {idx}: fun guard veto={row['fun_guard_veto']}")
        if row["expansion_veto"] != "allow":
            failures.append(f"iteration {idx}: expansion veto={row['expansion_veto']}")

    csv_path = REPORT_DIR / "expansion_soak_iterations.csv"
    with csv_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)

    soak_report = {
        "iterations": iterations,
        "failures": failures,
        "stable": not failures,
        "metrics": {
            "overall_quality_center_start": rows[0]["overall_quality_center"],
            "overall_quality_center_end": rows[-1]["overall_quality_center"],
            "reward_entropy_min": min(row["reward_entropy"] for row in rows),
            "reward_entropy_max": max(row["reward_entropy"] for row in rows),
            "sink_ratio_min": min(row["economy_sink_ratio"] for row in rows),
            "sink_ratio_max": max(row["economy_sink_ratio"] for row in rows),
            "boss_desirability_min": min(row["boss_desirability_separation"] for row in rows),
            "boss_desirability_max": max(row["boss_desirability_separation"] for row in rows),
            "strategy_concentration_min": min(row["strategy_concentration"] for row in rows),
            "strategy_concentration_max": max(row["strategy_concentration"] for row in rows),
        },
        "artifacts": {
            "iteration_csv": str(csv_path),
        },
    }
    return soak_report


def _write_summary(
    comparison: dict[str, object],
    after_expansion: dict[str, object],
    soak_report: dict[str, object],
) -> None:
    summary_path = REPORT_DIR / "expansion_summary.md"
    lines = [
        "# Playable Identity Expansion Summary",
        "",
        "## Bundle Status",
        f"- Bundle A starter world identity: {after_expansion['bundle_a_starter_world_identity']['status']}",
        f"- Bundle B quest/progression scaffolding: {after_expansion['bundle_b_quest_progression_scaffolding']['status']}",
        f"- Bundle C boss/chase identity: {after_expansion['bundle_c_boss_chase_identity']['status']}",
        f"- Bundle D strategy expression: {after_expansion['bundle_d_strategy_expression']['status']}",
        "",
        "## Before vs After",
        f"- Progression smoothness (quality center): {comparison['before']['progression_smoothness']['quality_progression_center']} -> {comparison['after']['progression_smoothness']['quality_progression_center']}",
        f"- Quest progression smoothness (new): {comparison['after']['progression_smoothness']['quest_progression_smoothness']}",
        f"- Reward identity entropy: {comparison['before']['reward_identity_clarity']['entropy']} -> {comparison['after']['reward_identity_clarity']['entropy']}",
        f"- Boss desirability separation (new): {comparison['after']['boss_chase_desirability']['boss_desirability_separation']}",
        f"- Field-vs-boss clarity (new): {comparison['after']['boss_chase_desirability']['field_vs_boss_reward_clarity']}",
        f"- Economy sink ratio: {comparison['before']['economy_stability']['sink_ratio']} -> {comparison['after']['economy_stability']['sink_ratio']}",
        f"- Strategy concentration (new): {comparison['after']['strategy_diversity']['low_level_strategy_concentration']}",
        f"- Early route diversity (new): {comparison['after']['strategy_diversity']['early_route_diversity']}",
        "",
        "## Regression/Soak",
        f"- Fun guard patch veto: {comparison['expansion_guard']['fun_guard_patch_veto']}",
        f"- Expansion veto: {comparison['expansion_guard']['expansion_veto']}",
        f"- 120-iteration soak stable: {soak_report['stable']}",
        f"- Soak failures: {len(soak_report['failures'])}",
    ]
    summary_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    REPORT_DIR.mkdir(parents=True, exist_ok=True)

    if not BASE_QUALITY_PATH.exists() or not BASE_FUN_PATH.exists():
        raise FileNotFoundError("Baseline files missing. Expected pre-expansion baseline snapshots.")

    base_quality = _load(BASE_QUALITY_PATH)
    base_fun = _load(BASE_FUN_PATH)
    after_quality, after_fun, after_expansion = _capture_after_snapshot()

    comparison = _build_comparison(base_quality, base_fun, after_quality, after_fun, after_expansion)
    comparison_path = REPORT_DIR / "expansion_comparison.json"
    comparison_path.write_text(json.dumps(comparison, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    regression = {
        "fun_guard_patch_veto": after_fun["patch_veto"],
        "expansion_veto": after_expansion["expansion_veto"],
        "bundle_status": {
            "A": after_expansion["bundle_a_starter_world_identity"]["status"],
            "B": after_expansion["bundle_b_quest_progression_scaffolding"]["status"],
            "C": after_expansion["bundle_c_boss_chase_identity"]["status"],
            "D": after_expansion["bundle_d_strategy_expression"]["status"],
        },
        "status": "pass"
        if after_fun["patch_veto"] == "allow" and after_expansion["expansion_veto"] == "allow"
        else "fail",
    }
    regression_path = REPORT_DIR / "expansion_regression.json"
    regression_path.write_text(json.dumps(regression, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    soak_report = _run_soak(iterations=120)
    soak_path = REPORT_DIR / "expansion_soak_report.json"
    soak_path.write_text(json.dumps(soak_report, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    _write_summary(comparison, after_expansion, soak_report)
    print(str(regression_path))
    print(str(soak_path))
    print(str(comparison_path))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
