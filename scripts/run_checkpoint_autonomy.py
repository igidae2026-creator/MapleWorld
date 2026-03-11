from __future__ import annotations

import argparse
import csv
import json
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
RUNS_DIR = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs"
REPORT_DIR = RUNS_DIR / "checkpoint_reports"
CHECKPOINT_PATH = RUNS_DIR / "checkpoint_stability_latest.json"
SUMMARY_PATH = REPORT_DIR / "checkpoint_summary.json"
STATUS_PATH = REPORT_DIR / "checkpoint_status_latest.json"
ITERATION_CSV_PATH = REPORT_DIR / "checkpoint_iterations.csv"
HISTORY_JSONL_PATH = REPORT_DIR / "checkpoint_history.jsonl"

CHECKPOINT_ORDER = [
    "world_stability",
    "player_flow_stability",
    "economy_stability",
    "meta_stability",
    "content_scale_out_stability",
    "liveops_override_safety",
]


def _run(command: list[str]) -> None:
    subprocess.run(command, cwd=ROOT_DIR, check=True)


def _load(path: Path) -> dict[str, object]:
    return json.loads(path.read_text(encoding="utf-8"))


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def run_cycle() -> dict[str, object]:
    _run(["lua", "simulation_lua/run_all.lua"])
    _run([sys.executable, "simulation_py/run_all.py"])
    _run([sys.executable, "metrics_engine/run_quality_eval.py"])
    return _load(CHECKPOINT_PATH)


def main() -> int:
    parser = argparse.ArgumentParser(description="Run checkpoint-based autonomous MMO stability soak.")
    parser.add_argument("--max-cycles", type=int, default=24)
    parser.add_argument("--required-streak", type=int, default=3)
    parser.add_argument("--sleep-seconds", type=float, default=0.0)
    args = parser.parse_args()

    REPORT_DIR.mkdir(parents=True, exist_ok=True)

    streaks = {name: 0 for name in CHECKPOINT_ORDER}
    rows: list[dict[str, object]] = []
    history: list[dict[str, object]] = []

    finished_reason = "max_cycles_reached"
    stable_reached_at = None

    for cycle in range(1, args.max_cycles + 1):
        payload = run_cycle()
        checkpoints = dict(payload["checkpoints"])
        metrics = dict(payload["stability_metrics"])

        row = {
            "cycle": cycle,
            "at_utc": _utc_now(),
            "overall_status": str(payload["status"]),
            "pass_count": int(metrics["checkpoint_pass_count"]),
            "stability_ratio": float(metrics["checkpoint_stability_ratio"]),
            "overall_stability_index": float(metrics["overall_stability_index"]),
        }

        for name in CHECKPOINT_ORDER:
            stable = bool(checkpoints[name]["stable"])
            streaks[name] = streaks[name] + 1 if stable else 0
            row[f"{name}_stable"] = int(stable)
            row[f"{name}_score"] = float(checkpoints[name]["score"])
            row[f"{name}_streak"] = streaks[name]

        rows.append(row)
        history_entry = {
            "cycle": cycle,
            "at_utc": row["at_utc"],
            "status": payload["status"],
            "stability_metrics": metrics,
            "checkpoint_status": {
                name: {
                    "stable": bool(checkpoints[name]["stable"]),
                    "score": float(checkpoints[name]["score"]),
                    "streak": streaks[name],
                }
                for name in CHECKPOINT_ORDER
            },
        }
        history.append(history_entry)

        if all(streaks[name] >= args.required_streak for name in CHECKPOINT_ORDER):
            finished_reason = "all_checkpoints_stable"
            stable_reached_at = cycle
            break

        if args.sleep_seconds > 0:
            time.sleep(args.sleep_seconds)

    with ITERATION_CSV_PATH.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)

    with HISTORY_JSONL_PATH.open("w", encoding="utf-8") as handle:
        for entry in history:
            handle.write(json.dumps(entry, sort_keys=True) + "\n")

    latest = history[-1]
    status_payload = {
        "finished_reason": finished_reason,
        "stable_reached_at_cycle": stable_reached_at,
        "required_streak": args.required_streak,
        "checkpoint_order": CHECKPOINT_ORDER,
        "checkpoint_status": latest["checkpoint_status"],
        "stability_metrics": latest["stability_metrics"],
    }
    STATUS_PATH.write_text(json.dumps(status_payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    summary = {
        "cycles_executed": len(rows),
        "finished_reason": finished_reason,
        "stable_reached_at_cycle": stable_reached_at,
        "required_streak": args.required_streak,
        "checkpoint_status": latest["checkpoint_status"],
        "stability_metrics": latest["stability_metrics"],
        "artifacts": {
            "iterations_csv": str(ITERATION_CSV_PATH),
            "history_jsonl": str(HISTORY_JSONL_PATH),
            "status_json": str(STATUS_PATH),
        },
    }
    SUMMARY_PATH.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    print(SUMMARY_PATH)
    print(STATUS_PATH)
    print(ITERATION_CSV_PATH)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
