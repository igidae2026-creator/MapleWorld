from __future__ import annotations

import csv
import json
import subprocess
import sys
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
RUNS_DIR = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs"
REPORT_DIR = RUNS_DIR / "graph_reports"

QUALITY_PATH = RUNS_DIR / "quality_metrics_latest.json"
FUN_PATH = RUNS_DIR / "fun_guard_metrics_latest.json"
EXPANSION_PATH = RUNS_DIR / "expansion_metrics_latest.json"
WORLD_GRAPH_LATEST_PATH = RUNS_DIR / "world_graph_metrics_latest.json"

BASE_QUALITY_PATH = RUNS_DIR / "quality_metrics_baseline_pre_expansion.json"
BASE_FUN_PATH = RUNS_DIR / "fun_guard_metrics_baseline_pre_expansion.json"

WORLD_GRAPH_METRICS_OUT = REPORT_DIR / "world_graph_metrics.json"
GRAPH_UTILIZATION_REPORT_OUT = REPORT_DIR / "graph_utilization_report.md"
GRAPH_BALANCE_COMPARISON_OUT = REPORT_DIR / "graph_balance_comparison.json"
GRAPH_SOAK_ITERATIONS_OUT = REPORT_DIR / "graph_soak_iterations.csv"


def _run(command: list[str]) -> None:
    subprocess.run(command, cwd=ROOT_DIR, check=True)


def _load(path: Path) -> dict[str, object]:
    return json.loads(path.read_text(encoding="utf-8"))


def _center(score_range: str) -> float:
    left, _, right = str(score_range).partition("~")
    return (float(left) + float(right)) / 2.0


def _capture_current() -> tuple[dict[str, object], dict[str, object], dict[str, object], dict[str, object]]:
    _run(["lua", "simulation_lua/run_all.lua"])
    _run([sys.executable, "simulation_py/run_all.py"])
    _run([sys.executable, "metrics_engine/run_quality_eval.py"])
    quality = _load(QUALITY_PATH)
    fun = _load(FUN_PATH)
    expansion = _load(EXPANSION_PATH)
    graph = _load(WORLD_GRAPH_LATEST_PATH)
    return quality, fun, expansion, graph


def _write_graph_report(graph: dict[str, object]) -> None:
    lines = [
        "# Graph Utilization Report",
        "",
        f"- status: {graph['status']}",
        f"- node_utilization: {graph['node_utilization']}",
        f"- content_density: {graph['content_density']}",
        f"- exploration_flow: {graph['exploration_flow']}",
        f"- path_entropy: {graph['path_entropy']}",
        f"- travel_friction: {graph['travel_friction']}",
        f"- node_count: {graph['counts']['nodes']}",
        f"- edge_count: {graph['counts']['edges']}",
        "",
        "## Risk Flags",
        f"- dead_zones: {len(graph['dead_zones'])}",
        f"- overcrowded_nodes: {len(graph['overcrowded_nodes'])}",
        f"- exploration_bottlenecks: {len(graph['exploration_bottlenecks'])}",
    ]

    if graph["dead_zones"]:
        lines.append("")
        lines.append("## Dead Zones")
        for row in graph["dead_zones"][:10]:
            lines.append(f"- {row['node_id']} util={row['utilization']}")

    if graph["overcrowded_nodes"]:
        lines.append("")
        lines.append("## Overcrowded")
        for row in graph["overcrowded_nodes"][:10]:
            lines.append(f"- {row['node_id']} util={row['utilization']}")

    if graph["exploration_bottlenecks"]:
        lines.append("")
        lines.append("## Bottlenecks")
        for row in graph["exploration_bottlenecks"][:10]:
            lines.append(f"- {row['node_id']} flow_share={row['flow_share']}")

    if graph["reasons"]:
        lines.append("")
        lines.append("## Reasons")
        for reason in graph["reasons"]:
            lines.append(f"- {reason}")

    GRAPH_UTILIZATION_REPORT_OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _write_comparison(before_quality: dict[str, object], before_fun: dict[str, object], after_quality: dict[str, object], after_graph: dict[str, object]) -> None:
    comparison = {
        "before": {
            "quality_overall_center": _center(str(before_quality["overall_quality_estimate"])),
            "progression_center": _center(str(before_quality["progression_pacing"])),
            "map_role_separation": str(before_fun.get("map_role_separation", "")),
            "reward_entropy": float(before_fun["reward_identity_diversity_guard"]["entropy"]),
            "strategy_mob_dominant_share": float(before_fun["strategy_diversity_guard"]["categories"]["mob_combat"]["dominant_share"]),
        },
        "after": {
            "quality_overall_center": _center(str(after_quality["overall_quality_estimate"])),
            "progression_center": _center(str(after_quality["progression_pacing"])),
            "world_graph_balance": str(after_quality.get("world_graph_balance", "")),
            "node_utilization": float(after_graph["node_utilization"]),
            "content_density": float(after_graph["content_density"]),
            "exploration_flow": float(after_graph["exploration_flow"]),
            "path_entropy": float(after_graph["path_entropy"]),
            "travel_friction": float(after_graph["travel_friction"]),
            "dead_zone_count": len(after_graph["dead_zones"]),
            "overcrowded_count": len(after_graph["overcrowded_nodes"]),
            "bottleneck_count": len(after_graph["exploration_bottlenecks"]),
        },
    }
    GRAPH_BALANCE_COMPARISON_OUT.write_text(json.dumps(comparison, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def _run_soak(iterations: int = 150) -> dict[str, object]:
    rows: list[dict[str, object]] = []
    failures: list[str] = []

    for idx in range(1, iterations + 1):
        _run([sys.executable, "simulation_py/run_all.py"])
        _run([sys.executable, "metrics_engine/run_quality_eval.py"])

        quality = _load(QUALITY_PATH)
        fun = _load(FUN_PATH)
        expansion = _load(EXPANSION_PATH)
        graph = _load(WORLD_GRAPH_LATEST_PATH)

        row = {
            "iteration": idx,
            "node_utilization": float(graph["node_utilization"]),
            "content_density": float(graph["content_density"]),
            "exploration_flow": float(graph["exploration_flow"]),
            "path_entropy": float(graph["path_entropy"]),
            "travel_friction": float(graph["travel_friction"]),
            "dead_zone_count": len(graph["dead_zones"]),
            "overcrowded_count": len(graph["overcrowded_nodes"]),
            "bottleneck_count": len(graph["exploration_bottlenecks"]),
            "world_graph_status": str(graph["status"]),
            "fun_guard_veto": str(fun["patch_veto"]),
            "expansion_veto": str(expansion["expansion_veto"]),
            "overall_quality_center": _center(str(quality["overall_quality_estimate"])),
        }
        rows.append(row)

        if row["world_graph_status"] != "allow":
            failures.append(f"iteration {idx}: world_graph_status={row['world_graph_status']}")
        if row["fun_guard_veto"] != "allow":
            failures.append(f"iteration {idx}: fun_guard_veto={row['fun_guard_veto']}")
        if row["expansion_veto"] != "allow":
            failures.append(f"iteration {idx}: expansion_veto={row['expansion_veto']}")

    with GRAPH_SOAK_ITERATIONS_OUT.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)

    return {
        "iterations": iterations,
        "stable": not failures,
        "failures": failures,
        "node_utilization_min": min(float(row["node_utilization"]) for row in rows),
        "node_utilization_max": max(float(row["node_utilization"]) for row in rows),
        "path_entropy_min": min(float(row["path_entropy"]) for row in rows),
        "path_entropy_max": max(float(row["path_entropy"]) for row in rows),
        "travel_friction_min": min(float(row["travel_friction"]) for row in rows),
        "travel_friction_max": max(float(row["travel_friction"]) for row in rows),
    }


def main() -> int:
    REPORT_DIR.mkdir(parents=True, exist_ok=True)

    if not BASE_QUALITY_PATH.exists() or not BASE_FUN_PATH.exists():
        raise FileNotFoundError("Missing baseline files for graph comparison")

    before_quality = _load(BASE_QUALITY_PATH)
    before_fun = _load(BASE_FUN_PATH)

    after_quality, after_fun, after_expansion, after_graph = _capture_current()

    WORLD_GRAPH_METRICS_OUT.write_text(json.dumps(after_graph, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    _write_graph_report(after_graph)
    _write_comparison(before_quality, before_fun, after_quality, after_graph)

    soak_report = _run_soak(iterations=150)
    (REPORT_DIR / "graph_soak_report.json").write_text(json.dumps(soak_report, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    regression = {
        "world_graph_status": after_graph["status"],
        "fun_guard_veto": after_fun["patch_veto"],
        "expansion_veto": after_expansion["expansion_veto"],
        "graph_soak_stable": soak_report["stable"],
        "status": "pass"
        if after_graph["status"] == "allow"
        and after_fun["patch_veto"] == "allow"
        and after_expansion["expansion_veto"] == "allow"
        and soak_report["stable"]
        else "fail",
    }
    (REPORT_DIR / "graph_regression.json").write_text(json.dumps(regression, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    print(WORLD_GRAPH_METRICS_OUT)
    print(GRAPH_UTILIZATION_REPORT_OUT)
    print(GRAPH_BALANCE_COMPARISON_OUT)
    print(GRAPH_SOAK_ITERATIONS_OUT)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
