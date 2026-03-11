from __future__ import annotations

import csv
import json
import subprocess
import sys
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
RUNS_DIR = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs"
REPORT_DIR = RUNS_DIR / "economy_reports"

QUALITY_PATH = RUNS_DIR / "quality_metrics_latest.json"
FUN_PATH = RUNS_DIR / "fun_guard_metrics_latest.json"
EXPANSION_PATH = RUNS_DIR / "expansion_metrics_latest.json"
GRAPH_PATH = RUNS_DIR / "world_graph_metrics_latest.json"
ROUTING_PATH = RUNS_DIR / "channel_routing_metrics_latest.json"
ECONOMY_PRESSURE_PATH = RUNS_DIR / "economy_pressure_metrics_latest.json"
BASE_QUALITY_PATH = RUNS_DIR / "quality_metrics_baseline_pre_expansion.json"
BASE_FUN_PATH = RUNS_DIR / "fun_guard_metrics_baseline_pre_expansion.json"

ECONOMY_PRESSURE_METRICS_OUT = REPORT_DIR / "economy_pressure_metrics.json"
ECONOMY_BALANCE_REPORT_OUT = REPORT_DIR / "economy_balance_report.md"
ECONOMY_BALANCE_COMPARISON_OUT = REPORT_DIR / "economy_balance_comparison.json"
ECONOMY_SOAK_ITERATIONS_OUT = REPORT_DIR / "economy_soak_iterations.csv"
ECONOMY_INTERVENTION_PROFILES_OUT = REPORT_DIR / "economy_intervention_profiles.json"
ECONOMY_FAILURE_SUMMARY_OUT = REPORT_DIR / "economy_failure_summary.md"


def _run(command: list[str]) -> None:
    subprocess.run(command, cwd=ROOT_DIR, check=True)


def _load(path: Path) -> dict[str, object]:
    return json.loads(path.read_text(encoding="utf-8"))


def _center(value: str) -> float:
    left, _, right = str(value).partition("~")
    return (float(left) + float(right)) / 2.0


def _capture_current() -> tuple[dict[str, object], dict[str, object], dict[str, object], dict[str, object], dict[str, object], dict[str, object]]:
    _run(["lua", "simulation_lua/run_all.lua"])
    _run([sys.executable, "simulation_py/run_all.py"])
    _run([sys.executable, "metrics_engine/run_quality_eval.py"])
    return (
        _load(QUALITY_PATH),
        _load(FUN_PATH),
        _load(EXPANSION_PATH),
        _load(GRAPH_PATH),
        _load(ROUTING_PATH),
        _load(ECONOMY_PRESSURE_PATH),
    )


def _write_report(metrics: dict[str, object]) -> None:
    lines = [
        "# Economy Balance Report",
        "",
        f"- status: {metrics['status']}",
        f"- drop_pressure: {metrics['drop_pressure']}",
        f"- inflation_pressure: {metrics['inflation_pressure']}",
        f"- reward_scarcity_index: {metrics['reward_scarcity_index']}",
        f"- item_desirability_gradient: {metrics['item_desirability_gradient']}",
        f"- farming_loop_risk: {metrics['farming_loop_risk']}",
        f"- sink_effectiveness: {metrics['sink_effectiveness']}",
        f"- currency_velocity_proxy: {metrics['currency_velocity_proxy']}",
        f"- reward_saturation_index: {metrics['reward_saturation_index']}",
        f"- dynamic_drop_adjustments: {metrics['adaptive_control']['dynamic_drop_adjustments']}",
        f"- sink_amplification: {metrics['adaptive_control']['sink_amplification']}",
        f"- scarcity_balancing: {metrics['adaptive_control']['scarcity_balancing']}",
        "",
        "## Detection Counts",
        f"- inflation_spikes: {len(metrics['detections']['inflation_spikes'])}",
        f"- farming_economy_loops: {len(metrics['detections']['farming_economy_loops'])}",
        f"- reward_saturation: {len(metrics['detections']['reward_saturation'])}",
        f"- scarcity_collapse: {len(metrics['detections']['scarcity_collapse'])}",
        f"- route_based_reward_abuse: {len(metrics['detections']['route_based_reward_abuse'])}",
        f"- boss_reward_overconcentration: {len(metrics['detections']['boss_reward_overconcentration'])}",
        f"- region_level_economy_imbalance: {len(metrics['detections']['region_level_economy_imbalance'])}",
    ]
    if metrics.get("reasons"):
        lines.append("")
        lines.append("## Reasons")
        for reason in metrics["reasons"]:
            lines.append(f"- {reason}")
    ECONOMY_BALANCE_REPORT_OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _write_intervention_profiles(metrics: dict[str, object]) -> None:
    payload = {
        "active_profiles": [
            profile for profile in metrics.get("economy_intervention_profiles", []) if profile.get("active")
        ],
        "all_profiles": metrics.get("economy_intervention_profiles", []),
    }
    ECONOMY_INTERVENTION_PROFILES_OUT.write_text(
        json.dumps(payload, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def _write_comparison(
    before_quality: dict[str, object],
    before_fun: dict[str, object],
    after_quality: dict[str, object],
    after: dict[str, object],
) -> None:
    payload = {
        "before": {
            "quality_overall_center": _center(str(before_quality["overall_quality_estimate"])),
            "progression_center": _center(str(before_quality["progression_pacing"])),
            "reward_entropy": float(before_fun["reward_identity_diversity_guard"]["entropy"]),
            "sink_ratio": float(before_fun["economy_drift_guard"]["sink_ratio"]),
            "inflation_ratio": float(before_fun["economy_drift_guard"]["inflation_ratio"]),
        },
        "after": {
            "quality_overall_center": _center(str(after_quality["overall_quality_estimate"])),
            "progression_center": _center(str(after_quality["progression_pacing"])),
            "economy_pressure_balance": str(after_quality.get("economy_pressure_balance", "")),
            "drop_pressure": float(after["drop_pressure"]),
            "inflation_pressure": float(after["inflation_pressure"]),
            "reward_scarcity_index": float(after["reward_scarcity_index"]),
            "item_desirability_gradient": float(after["item_desirability_gradient"]),
            "farming_loop_risk": float(after["farming_loop_risk"]),
            "sink_effectiveness": float(after["sink_effectiveness"]),
            "currency_velocity_proxy": float(after["currency_velocity_proxy"]),
            "reward_saturation_index": float(after["reward_saturation_index"]),
            "dynamic_drop_adjustments": float(after["adaptive_control"]["dynamic_drop_adjustments"]),
            "sink_amplification": float(after["adaptive_control"]["sink_amplification"]),
            "scarcity_balancing": float(after["adaptive_control"]["scarcity_balancing"]),
            "reward_distribution_smoothing": float(after["adaptive_control"]["reward_distribution_smoothing"]),
            "anti_loop_economy_dampening": float(after["adaptive_control"]["anti_loop_economy_dampening"]),
        },
    }
    ECONOMY_BALANCE_COMPARISON_OUT.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def _run_soak(iterations: int = 200) -> dict[str, object]:
    rows: list[dict[str, object]] = []
    failures: list[str] = []

    for idx in range(1, iterations + 1):
        _run([sys.executable, "simulation_py/run_all.py"])
        _run([sys.executable, "metrics_engine/run_quality_eval.py"])

        quality = _load(QUALITY_PATH)
        fun = _load(FUN_PATH)
        expansion = _load(EXPANSION_PATH)
        graph = _load(GRAPH_PATH)
        routing = _load(ROUTING_PATH)
        economy = _load(ECONOMY_PRESSURE_PATH)

        row = {
            "iteration": idx,
            "drop_pressure": float(economy["drop_pressure"]),
            "inflation_pressure": float(economy["inflation_pressure"]),
            "reward_scarcity_index": float(economy["reward_scarcity_index"]),
            "item_desirability_gradient": float(economy["item_desirability_gradient"]),
            "dynamic_drop_adjustments": float(economy["adaptive_control"]["dynamic_drop_adjustments"]),
            "sink_amplification": float(economy["adaptive_control"]["sink_amplification"]),
            "scarcity_balancing": float(economy["adaptive_control"]["scarcity_balancing"]),
            "economy_status": str(economy["status"]),
            "routing_status": str(routing["status"]),
            "graph_status": str(graph["status"]),
            "fun_guard_veto": str(fun["patch_veto"]),
            "expansion_veto": str(expansion["expansion_veto"]),
            "overall_quality_center": _center(str(quality["overall_quality_estimate"])),
        }
        rows.append(row)

        if row["economy_status"] != "allow":
            failures.append(f"iteration {idx}: economy_status={row['economy_status']}")
        if row["routing_status"] != "allow":
            failures.append(f"iteration {idx}: routing_status={row['routing_status']}")
        if row["graph_status"] != "allow":
            failures.append(f"iteration {idx}: graph_status={row['graph_status']}")
        if row["fun_guard_veto"] != "allow":
            failures.append(f"iteration {idx}: fun_guard_veto={row['fun_guard_veto']}")
        if row["expansion_veto"] != "allow":
            failures.append(f"iteration {idx}: expansion_veto={row['expansion_veto']}")

    with ECONOMY_SOAK_ITERATIONS_OUT.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)

    return {
        "iterations": iterations,
        "stable": not failures,
        "failures": failures,
        "drop_pressure_min": min(float(row["drop_pressure"]) for row in rows),
        "drop_pressure_max": max(float(row["drop_pressure"]) for row in rows),
        "inflation_pressure_min": min(float(row["inflation_pressure"]) for row in rows),
        "inflation_pressure_max": max(float(row["inflation_pressure"]) for row in rows),
        "scarcity_index_min": min(float(row["reward_scarcity_index"]) for row in rows),
        "scarcity_index_max": max(float(row["reward_scarcity_index"]) for row in rows),
    }


def _write_failure_summary(
    economy: dict[str, object],
    soak: dict[str, object],
    regression: dict[str, object],
) -> None:
    lines = [
        "# Economy Failure Summary",
        "",
        f"- regression_status: {regression['status']}",
        f"- economy_status: {economy['status']}",
        f"- soak_stable: {soak['stable']}",
        f"- soak_iterations: {soak['iterations']}",
        "",
        "## Detection Trigger Counts",
        f"- inflation_spikes: {len(economy['detections']['inflation_spikes'])}",
        f"- farming_economy_loops: {len(economy['detections']['farming_economy_loops'])}",
        f"- reward_saturation: {len(economy['detections']['reward_saturation'])}",
        f"- scarcity_collapse: {len(economy['detections']['scarcity_collapse'])}",
        f"- route_based_reward_abuse: {len(economy['detections']['route_based_reward_abuse'])}",
        f"- boss_reward_overconcentration: {len(economy['detections']['boss_reward_overconcentration'])}",
        f"- region_level_economy_imbalance: {len(economy['detections']['region_level_economy_imbalance'])}",
    ]
    if soak["failures"]:
        lines.extend(["", "## Soak Failures"])
        for failure in soak["failures"]:
            lines.append(f"- {failure}")
    else:
        lines.extend(["", "## Soak Failures", "- none"])

    if economy.get("reasons"):
        lines.extend(["", "## Economy Rejection Reasons"])
        for reason in economy["reasons"]:
            lines.append(f"- {reason}")

    ECONOMY_FAILURE_SUMMARY_OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    REPORT_DIR.mkdir(parents=True, exist_ok=True)

    if not BASE_QUALITY_PATH.exists() or not BASE_FUN_PATH.exists():
        raise FileNotFoundError("Missing baseline files for economy comparison")

    before_quality = _load(BASE_QUALITY_PATH)
    before_fun = _load(BASE_FUN_PATH)

    quality, fun, expansion, graph, routing, economy = _capture_current()

    ECONOMY_PRESSURE_METRICS_OUT.write_text(json.dumps(economy, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    _write_report(economy)
    _write_intervention_profiles(economy)
    _write_comparison(before_quality, before_fun, quality, economy)

    soak = _run_soak(iterations=200)
    (REPORT_DIR / "economy_soak_report.json").write_text(json.dumps(soak, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    regression = {
        "economy_status": economy["status"],
        "routing_status": routing["status"],
        "graph_status": graph["status"],
        "fun_guard_veto": fun["patch_veto"],
        "expansion_veto": expansion["expansion_veto"],
        "economy_soak_stable": soak["stable"],
        "status": "pass"
        if economy["status"] == "allow"
        and routing["status"] == "allow"
        and graph["status"] == "allow"
        and fun["patch_veto"] == "allow"
        and expansion["expansion_veto"] == "allow"
        and soak["stable"]
        else "fail",
    }
    (REPORT_DIR / "economy_regression.json").write_text(json.dumps(regression, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    _write_failure_summary(economy, soak, regression)

    print(ECONOMY_PRESSURE_METRICS_OUT)
    print(ECONOMY_BALANCE_REPORT_OUT)
    print(ECONOMY_BALANCE_COMPARISON_OUT)
    print(ECONOMY_SOAK_ITERATIONS_OUT)
    print(ECONOMY_INTERVENTION_PROFILES_OUT)
    print(ECONOMY_FAILURE_SUMMARY_OUT)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
