from __future__ import annotations

import csv
import json
import subprocess
import sys
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
RUNS_DIR = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs"
REPORT_DIR = RUNS_DIR / "routing_reports"

QUALITY_PATH = RUNS_DIR / "quality_metrics_latest.json"
FUN_PATH = RUNS_DIR / "fun_guard_metrics_latest.json"
EXPANSION_PATH = RUNS_DIR / "expansion_metrics_latest.json"
WORLD_GRAPH_PATH = RUNS_DIR / "world_graph_metrics_latest.json"
CHANNEL_ROUTING_PATH = RUNS_DIR / "channel_routing_metrics_latest.json"
BASE_QUALITY_PATH = RUNS_DIR / "quality_metrics_baseline_pre_expansion.json"
BASE_FUN_PATH = RUNS_DIR / "fun_guard_metrics_baseline_pre_expansion.json"

CHANNEL_ROUTING_METRICS_OUT = REPORT_DIR / "channel_routing_metrics.json"
CONGESTION_REPORT_OUT = REPORT_DIR / "congestion_report.md"
ROUTING_BALANCE_COMPARISON_OUT = REPORT_DIR / "routing_balance_comparison.json"
ROUTING_SOAK_ITERATIONS_OUT = REPORT_DIR / "routing_soak_iterations.csv"


def _run(command: list[str]) -> None:
    subprocess.run(command, cwd=ROOT_DIR, check=True)


def _load(path: Path) -> dict[str, object]:
    return json.loads(path.read_text(encoding="utf-8"))


def _center(score_range: str) -> float:
    left, _, right = str(score_range).partition("~")
    return (float(left) + float(right)) / 2.0


def _capture_current() -> tuple[dict[str, object], dict[str, object], dict[str, object], dict[str, object], dict[str, object]]:
    _run(["lua", "simulation_lua/run_all.lua"])
    _run([sys.executable, "simulation_py/run_all.py"])
    _run([sys.executable, "metrics_engine/run_quality_eval.py"])
    return (
        _load(QUALITY_PATH),
        _load(FUN_PATH),
        _load(EXPANSION_PATH),
        _load(WORLD_GRAPH_PATH),
        _load(CHANNEL_ROUTING_PATH),
    )


def _write_congestion_report(payload: dict[str, object]) -> None:
    lines = [
        "# Congestion Report",
        "",
        f"- status: {payload['status']}",
        f"- node_concurrency: {payload['node_concurrency']}",
        f"- hotspot_score: {payload['hotspot_score']}",
        f"- channel_pressure: {payload['channel_pressure']}",
        f"- spawn_pressure: {payload['spawn_pressure']}",
        f"- exploration_stagnation_index: {payload['exploration_stagnation']['index']}",
        f"- overcrowded_maps: {len(payload['overcrowded_maps'])}",
        f"- farming_hotspots: {len(payload['farming_hotspots'])}",
        "",
        "## Policy Actions",
        f"- soft_rerouting: {payload['policy_actions']['soft_rerouting']}",
        f"- spawn_redistribution: {payload['policy_actions']['spawn_redistribution']}",
        f"- dynamic_channel_balancing: {payload['policy_actions']['dynamic_channel_balancing']}",
    ]
    if payload.get("reasons"):
        lines.append("")
        lines.append("## Reasons")
        for reason in payload["reasons"]:
            lines.append(f"- {reason}")
    CONGESTION_REPORT_OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _write_comparison(before_quality: dict[str, object], before_fun: dict[str, object], after_quality: dict[str, object], after_routing: dict[str, object]) -> None:
    payload = {
        "before": {
            "quality_overall_center": _center(str(before_quality["overall_quality_estimate"])),
            "progression_center": _center(str(before_quality["progression_pacing"])),
            "strategy_mob_dominant_share": float(before_fun["strategy_diversity_guard"]["categories"]["mob_combat"]["dominant_share"]),
            "reward_entropy": float(before_fun["reward_identity_diversity_guard"]["entropy"]),
        },
        "after": {
            "quality_overall_center": _center(str(after_quality["overall_quality_estimate"])),
            "progression_center": _center(str(after_quality["progression_pacing"])),
            "channel_routing_balance": str(after_quality.get("channel_routing_balance", "")),
            "node_concurrency": float(after_routing["node_concurrency"]),
            "hotspot_score": float(after_routing["hotspot_score"]),
            "channel_pressure": float(after_routing["channel_pressure"]),
            "spawn_pressure": float(after_routing["spawn_pressure"]),
            "exploration_stagnation_index": float(after_routing["exploration_stagnation"]["index"]),
            "overcrowded_maps": len(after_routing["overcrowded_maps"]),
            "farming_hotspots": len(after_routing["farming_hotspots"]),
        },
    }
    ROUTING_BALANCE_COMPARISON_OUT.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def _run_soak(iterations: int = 150) -> dict[str, object]:
    rows: list[dict[str, object]] = []
    failures: list[str] = []

    for idx in range(1, iterations + 1):
        _run([sys.executable, "simulation_py/run_all.py"])
        _run([sys.executable, "metrics_engine/run_quality_eval.py"])

        quality = _load(QUALITY_PATH)
        fun = _load(FUN_PATH)
        expansion = _load(EXPANSION_PATH)
        graph = _load(WORLD_GRAPH_PATH)
        routing = _load(CHANNEL_ROUTING_PATH)

        row = {
            "iteration": idx,
            "node_concurrency": float(routing["node_concurrency"]),
            "hotspot_score": float(routing["hotspot_score"]),
            "channel_pressure": float(routing["channel_pressure"]),
            "spawn_pressure": float(routing["spawn_pressure"]),
            "exploration_stagnation_index": float(routing["exploration_stagnation"]["index"]),
            "overcrowded_maps": len(routing["overcrowded_maps"]),
            "farming_hotspots": len(routing["farming_hotspots"]),
            "routing_status": str(routing["status"]),
            "graph_status": str(graph["status"]),
            "fun_guard_veto": str(fun["patch_veto"]),
            "expansion_veto": str(expansion["expansion_veto"]),
            "overall_quality_center": _center(str(quality["overall_quality_estimate"])),
        }
        rows.append(row)

        if row["routing_status"] != "allow":
            failures.append(f"iteration {idx}: routing_status={row['routing_status']}")
        if row["graph_status"] != "allow":
            failures.append(f"iteration {idx}: graph_status={row['graph_status']}")
        if row["fun_guard_veto"] != "allow":
            failures.append(f"iteration {idx}: fun_guard_veto={row['fun_guard_veto']}")
        if row["expansion_veto"] != "allow":
            failures.append(f"iteration {idx}: expansion_veto={row['expansion_veto']}")

    with ROUTING_SOAK_ITERATIONS_OUT.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)

    return {
        "iterations": iterations,
        "stable": not failures,
        "failures": failures,
        "node_concurrency_min": min(float(row["node_concurrency"]) for row in rows),
        "node_concurrency_max": max(float(row["node_concurrency"]) for row in rows),
        "hotspot_score_min": min(float(row["hotspot_score"]) for row in rows),
        "hotspot_score_max": max(float(row["hotspot_score"]) for row in rows),
        "channel_pressure_min": min(float(row["channel_pressure"]) for row in rows),
        "channel_pressure_max": max(float(row["channel_pressure"]) for row in rows),
        "spawn_pressure_min": min(float(row["spawn_pressure"]) for row in rows),
        "spawn_pressure_max": max(float(row["spawn_pressure"]) for row in rows),
    }


def main() -> int:
    REPORT_DIR.mkdir(parents=True, exist_ok=True)

    if not BASE_QUALITY_PATH.exists() or not BASE_FUN_PATH.exists():
        raise FileNotFoundError("Missing baseline files for routing comparison")

    before_quality = _load(BASE_QUALITY_PATH)
    before_fun = _load(BASE_FUN_PATH)

    quality, fun, expansion, graph, routing = _capture_current()

    CHANNEL_ROUTING_METRICS_OUT.write_text(json.dumps(routing, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    _write_congestion_report(routing)
    _write_comparison(before_quality, before_fun, quality, routing)

    soak = _run_soak(iterations=150)
    (REPORT_DIR / "routing_soak_report.json").write_text(json.dumps(soak, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    regression = {
        "routing_status": routing["status"],
        "graph_status": graph["status"],
        "fun_guard_veto": fun["patch_veto"],
        "expansion_veto": expansion["expansion_veto"],
        "routing_soak_stable": soak["stable"],
        "status": "pass"
        if routing["status"] == "allow"
        and graph["status"] == "allow"
        and fun["patch_veto"] == "allow"
        and expansion["expansion_veto"] == "allow"
        and soak["stable"]
        else "fail",
    }
    (REPORT_DIR / "routing_regression.json").write_text(json.dumps(regression, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    print(CHANNEL_ROUTING_METRICS_OUT)
    print(CONGESTION_REPORT_OUT)
    print(ROUTING_BALANCE_COMPARISON_OUT)
    print(ROUTING_SOAK_ITERATIONS_OUT)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
