from __future__ import annotations

import csv
import fcntl
import itertools
import json
import subprocess
import sys
import time
from copy import deepcopy
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
ROLE_BANDS_PATH = ROOT_DIR / "data" / "balance" / "maps" / "role_bands.csv"
REPORT_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs" / "cross_band_rebalance_candidates.json"
LOCK_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs" / ".cross_band_rebalance.lock"
PLAYER_METRICS_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs" / "player_experience_metrics_latest.json"
ECONOMY_PRESSURE_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs" / "economy_pressure_metrics_latest.json"
QUALITY_EVAL_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs" / "quality_metrics_latest.json"
BLOCKED_MAPS = {"perion_rockfall_edge", "ellinia_lower_canopy", "lith_harbor_coast_road"}
THROUGHPUT_SPREAD_FLOOR = 0.12
REWARD_SPREAD_FLOOR = 0.14
TARGET_COUNT = 3
WAIT_FOR_FRESH_REPORT_SECONDS = 15.0
WAIT_FOR_FRESH_REPORT_POLL_SECONDS = 0.25
TARGET_THROUGHPUT_DELTAS = (0.01, 0.02)
TARGET_REWARD_DELTAS = (0.01, 0.02, 0.03)
ALTERNATIVE_THROUGHPUT_DELTAS = (0.00, 0.01)
ALTERNATIVE_REWARD_DELTAS = (0.01, 0.02, 0.03)


def _read_role_bands() -> tuple[list[str], list[dict[str, str]]]:
    with ROLE_BANDS_PATH.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        return list(reader.fieldnames or []), list(reader)


def _write_role_bands(fieldnames: list[str], rows: list[dict[str, str]]) -> None:
    with ROLE_BANDS_PATH.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def _load_json(path: Path) -> dict[str, object]:
    return json.loads(path.read_text(encoding="utf-8"))


def _run_simulation() -> tuple[dict[str, object], dict[str, object], dict[str, object]]:
    subprocess.run([sys.executable, "simulation_py/run_all.py"], cwd=ROOT_DIR, check=True, stdout=subprocess.DEVNULL)
    subprocess.run([sys.executable, "metrics_engine/run_quality_eval.py"], cwd=ROOT_DIR, check=True, stdout=subprocess.DEVNULL)
    return _load_json(PLAYER_METRICS_PATH), _load_json(ECONOMY_PRESSURE_PATH), _load_json(QUALITY_EVAL_PATH)


def _top_pressure_gap(economy: dict[str, object]) -> float:
    return float(economy.get("top_pressure_gap", 0.0))


def _top_pressure_concentration(economy: dict[str, object]) -> float:
    return float(economy.get("top_pressure_concentration", 0.0))


def _pressure_for_node(economy: dict[str, object], node: str) -> float:
    for item in list(economy.get("top_pressure_nodes", [])):
        if str(item.get("node", "")) == node:
            return float(item.get("pressure", 0.0))
    propagation = dict(economy.get("reward_pressure_propagation", {}))
    for item in list(propagation.get("top_pressure_nodes", [])):
        if str(item.get("node", "")) == node:
            return float(item.get("pressure", 0.0))
    return 0.0


def _range_center(value: object, default: int = 60) -> int:
    text = str(value).strip()
    if "~" in text:
        left, right = text.split("~", 1)
        try:
            return int(round((int(left) + int(right)) / 2))
        except ValueError:
            return default
    try:
        return int(round(float(text)))
    except ValueError:
        return default


def _report_is_fresh() -> bool:
    if not REPORT_PATH.exists():
        return False
    return REPORT_PATH.stat().st_mtime >= ROLE_BANDS_PATH.stat().st_mtime


def _candidate_targets(economy: dict[str, object], rows: list[dict[str, str]]) -> list[dict[str, str]]:
    by_map = {str(row.get("map_id", "")): row for row in rows}
    targets: list[dict[str, str]] = []
    seen_bands: set[str] = set()
    for item in list(economy.get("top_pressure_nodes", [])):
        node = str(item.get("node", "")).strip()
        if not node.startswith("map:"):
            continue
        map_id = node.split(":", 1)[1]
        if map_id in BLOCKED_MAPS or map_id not in by_map:
            continue
        row = by_map[map_id]
        band_id = str(row["band_id"])
        if band_id in seen_bands:
            continue
        alternative = next(
            (candidate for candidate in rows if candidate["band_id"] == band_id and candidate.get("role") == "alternative"),
            None,
        )
        if alternative is None or alternative["map_id"] == map_id:
            continue
        targets.append(
            {
                "band_id": band_id,
                "target_map": map_id,
                "alternative_map": str(alternative["map_id"]),
                "target_throughput": float(row["throughput_bias"]),
                "target_reward": float(row["reward_bias"]),
                "alternative_throughput": float(alternative["throughput_bias"]),
                "alternative_reward": float(alternative["reward_bias"]),
            }
        )
        seen_bands.add(band_id)
        if len(targets) >= TARGET_COUNT:
            break
    return targets


def _spreads(rows: list[dict[str, str]], band_id: str) -> dict[str, float]:
    band_rows = [row for row in rows if row["band_id"] == band_id]
    throughput = [float(row["throughput_bias"]) for row in band_rows]
    reward = [float(row["reward_bias"]) for row in band_rows]
    return {
        "throughput_spread": round(max(throughput) - min(throughput), 4),
        "reward_spread": round(max(reward) - min(reward), 4),
    }


def _rows_signature(rows: list[dict[str, str]]) -> list[tuple[tuple[str, str], ...]]:
    return [tuple(sorted(row.items())) for row in rows]


def main() -> int:
    LOCK_PATH.parent.mkdir(parents=True, exist_ok=True)
    with LOCK_PATH.open("w", encoding="utf-8") as lock_handle:
        try:
            fcntl.flock(lock_handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            deadline = time.monotonic() + WAIT_FOR_FRESH_REPORT_SECONDS
            while time.monotonic() < deadline:
                if _report_is_fresh():
                    print(REPORT_PATH)
                    return 0
                time.sleep(WAIT_FOR_FRESH_REPORT_POLL_SECONDS)
            raise RuntimeError("cross-band rebalance report is stale while another search holds the lock")

        fieldnames, original_rows = _read_role_bands()
        original_signature = _rows_signature(original_rows)
        baseline_player, baseline_economy, baseline_quality = _run_simulation()
        targets = _candidate_targets(baseline_economy, original_rows)

        report: dict[str, object] = {
            "evaluated_targets": targets,
            "candidate_count": 0,
            "best_candidate": None,
            "candidates": [],
            "recommendation": "cross-band rebalance exhausted",
            "baseline": {
                "economy_coherence": str(baseline_player["ranges"]["economy_coherence"]),
                "economy_coherence_center": int(baseline_player["centers"]["economy_coherence"]),
                "economy_pressure_balance": str(baseline_quality.get("economy_pressure_balance", "60~60")),
                "economy_pressure_balance_center": _range_center(baseline_quality.get("economy_pressure_balance", "60~60")),
                "drop_pressure": round(float(baseline_economy.get("drop_pressure", 0.0)), 4),
                "top_pressure_gap": round(_top_pressure_gap(baseline_economy), 4),
                "top_pressure_concentration": round(_top_pressure_concentration(baseline_economy), 4),
            },
        }
        if len(targets) < 2:
            REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
            REPORT_PATH.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
            print(REPORT_PATH)
            return 0

        candidates: list[dict[str, object]] = []
        last_written_rows = original_rows
        try:
            per_target_steps: list[list[dict[str, float | str]]] = []
            for target in targets:
                steps: list[dict[str, float | str]] = []
                for target_throughput_delta, target_reward_delta, alt_throughput_delta, alt_reward_delta in itertools.product(
                    TARGET_THROUGHPUT_DELTAS,
                    TARGET_REWARD_DELTAS,
                    ALTERNATIVE_THROUGHPUT_DELTAS,
                    ALTERNATIVE_REWARD_DELTAS,
                ):
                    candidate_target_throughput = round(float(target["target_throughput"]) - target_throughput_delta, 2)
                    candidate_target_reward = round(float(target["target_reward"]) - target_reward_delta, 2)
                    candidate_alt_throughput = round(float(target["alternative_throughput"]) + alt_throughput_delta, 2)
                    candidate_alt_reward = round(float(target["alternative_reward"]) + alt_reward_delta, 2)
                    if candidate_target_throughput <= 1.0 or candidate_target_reward <= candidate_target_throughput:
                        continue
                    if candidate_alt_reward <= candidate_alt_throughput or candidate_target_reward <= candidate_alt_reward:
                        continue
                    steps.append(
                        {
                            "band_id": str(target["band_id"]),
                            "target_map": str(target["target_map"]),
                            "alternative_map": str(target["alternative_map"]),
                            "target_throughput": candidate_target_throughput,
                            "target_reward": candidate_target_reward,
                            "alternative_throughput": candidate_alt_throughput,
                            "alternative_reward": candidate_alt_reward,
                        }
                    )
                per_target_steps.append(steps[:6])

            for combo_size in (2, len(per_target_steps)):
                if combo_size > len(per_target_steps):
                    continue
                for target_group in itertools.combinations(range(len(per_target_steps)), combo_size):
                    selected_steps = [per_target_steps[index] for index in target_group]
                    for step_combo in itertools.product(*selected_steps):
                        rows = deepcopy(original_rows)
                        touched_bands = {str(item["band_id"]) for item in step_combo}
                        for row in rows:
                            for step in step_combo:
                                if row["map_id"] == step["target_map"]:
                                    row["throughput_bias"] = f"{float(step['target_throughput']):.2f}".rstrip("0").rstrip(".")
                                    row["reward_bias"] = f"{float(step['target_reward']):.2f}".rstrip("0").rstrip(".")
                                elif row["map_id"] == step["alternative_map"]:
                                    row["throughput_bias"] = f"{float(step['alternative_throughput']):.2f}".rstrip("0").rstrip(".")
                                    row["reward_bias"] = f"{float(step['alternative_reward']):.2f}".rstrip("0").rstrip(".")
                        if any(
                            _spreads(rows, band_id)["throughput_spread"] < THROUGHPUT_SPREAD_FLOOR
                            or _spreads(rows, band_id)["reward_spread"] < REWARD_SPREAD_FLOOR
                            for band_id in touched_bands
                        ):
                            continue

                        _write_role_bands(fieldnames, rows)
                        last_written_rows = rows
                        player, economy, quality = _run_simulation()
                        candidate = {
                            "adjustments": [
                                {
                                    "band_id": str(step["band_id"]),
                                    "target_map": str(step["target_map"]),
                                    "target_throughput": float(step["target_throughput"]),
                                    "target_reward": float(step["target_reward"]),
                                    "alternative_map": str(step["alternative_map"]),
                                    "alternative_throughput": float(step["alternative_throughput"]),
                                    "alternative_reward": float(step["alternative_reward"]),
                                    "band_spreads": _spreads(rows, str(step["band_id"])),
                                }
                                for step in step_combo
                            ],
                            "economy_coherence": str(player["ranges"]["economy_coherence"]),
                            "economy_coherence_center": int(player["centers"]["economy_coherence"]),
                            "economy_pressure_balance": str(quality.get("economy_pressure_balance", "60~60")),
                            "economy_pressure_balance_center": _range_center(quality.get("economy_pressure_balance", "60~60")),
                            "drop_pressure": round(float(economy.get("drop_pressure", 0.0)), 4),
                            "top_pressure_gap": round(_top_pressure_gap(economy), 4),
                            "top_pressure_concentration": round(_top_pressure_concentration(economy), 4),
                            "top_pressure_nodes": list(economy.get("top_pressure_nodes", []))[:8],
                            "target_pressures": {
                                str(step["target_map"]): round(_pressure_for_node(economy, f"map:{step['target_map']}"), 4)
                                for step in step_combo
                            },
                            "distance_from_baseline": round(
                                sum(
                                    abs(float(step["target_throughput"]) - next(float(row["throughput_bias"]) for row in original_rows if row["map_id"] == step["target_map"]))
                                    + abs(float(step["target_reward"]) - next(float(row["reward_bias"]) for row in original_rows if row["map_id"] == step["target_map"]))
                                    + abs(float(step["alternative_throughput"]) - next(float(row["throughput_bias"]) for row in original_rows if row["map_id"] == step["alternative_map"]))
                                    + abs(float(step["alternative_reward"]) - next(float(row["reward_bias"]) for row in original_rows if row["map_id"] == step["alternative_map"]))
                                    for step in step_combo
                                ),
                                4,
                            ),
                        }
                        candidate["sort_key"] = (
                            -candidate["top_pressure_gap"],
                            -candidate["top_pressure_concentration"],
                            candidate["economy_pressure_balance_center"],
                            candidate["economy_coherence_center"],
                            -candidate["drop_pressure"],
                            -candidate["distance_from_baseline"],
                        )
                        candidates.append(candidate)
        finally:
            _, current_rows = _read_role_bands()
            if _rows_signature(current_rows) != _rows_signature(last_written_rows):
                raise RuntimeError("role_bands.csv changed during cross-band search; refusing to overwrite newer state")
            _write_role_bands(fieldnames, original_rows)
            _, restored_rows = _read_role_bands()
            if _rows_signature(restored_rows) != original_signature:
                raise RuntimeError("failed to restore role_bands.csv baseline after cross-band search")
            _run_simulation()

        candidates.sort(key=lambda item: item["sort_key"], reverse=True)
        for item in candidates:
            item.pop("sort_key", None)
        best = candidates[0] if candidates else None
        report["candidate_count"] = len(candidates)
        report["best_candidate"] = best
        report["candidates"] = candidates[:8]
        if best and (
            best["top_pressure_gap"] < report["baseline"]["top_pressure_gap"]
            or best["top_pressure_concentration"] < report["baseline"]["top_pressure_concentration"]
            or best["economy_coherence_center"] > report["baseline"]["economy_coherence_center"]
            or best["economy_pressure_balance_center"] > report["baseline"]["economy_pressure_balance_center"]
            or best["drop_pressure"] < report["baseline"]["drop_pressure"]
        ):
            report["recommendation"] = "use_best_candidate"

        REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
        REPORT_PATH.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        print(REPORT_PATH)
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
