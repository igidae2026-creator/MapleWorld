from __future__ import annotations

import csv
import fcntl
import json
import subprocess
import sys
import time
from copy import deepcopy
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
ROLE_BANDS_PATH = ROOT_DIR / "data" / "balance" / "maps" / "role_bands.csv"
ECONOMY_PRESSURE_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs" / "economy_pressure_metrics_latest.json"
PLAYER_METRICS_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs" / "player_experience_metrics_latest.json"
QUALITY_EVAL_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs" / "quality_metrics_latest.json"
REPORT_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs" / "next_map_rebalance_candidates.json"
LOCK_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs" / ".next_map_rebalance.lock"
BLOCKED_MAPS = {"perion_rockfall_edge", "ellinia_lower_canopy", "lith_harbor_coast_road"}
WAIT_FOR_FRESH_REPORT_SECONDS = 15.0
WAIT_FOR_FRESH_REPORT_POLL_SECONDS = 0.25
TARGET_THROUGHPUT_DELTAS = (0.01, 0.02, 0.03)
TARGET_REWARD_DELTAS = (0.00, 0.01, 0.02, 0.03, 0.04, 0.05)
ALTERNATIVE_THROUGHPUT_DELTAS = (0.00, 0.01, 0.02)
ALTERNATIVE_REWARD_DELTAS = (0.00, 0.01, 0.02)


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


def _report_is_fresh() -> bool:
    if not REPORT_PATH.exists():
        return False
    return REPORT_PATH.stat().st_mtime >= ROLE_BANDS_PATH.stat().st_mtime


def _rows_signature(rows: list[dict[str, str]]) -> list[tuple[tuple[str, str], ...]]:
    return [tuple(sorted(row.items())) for row in rows]


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


def _run_simulation() -> tuple[dict[str, object], dict[str, object], dict[str, object]]:
    subprocess.run([sys.executable, "simulation_py/run_all.py"], cwd=ROOT_DIR, check=True, stdout=subprocess.DEVNULL)
    subprocess.run([sys.executable, "metrics_engine/run_quality_eval.py"], cwd=ROOT_DIR, check=True, stdout=subprocess.DEVNULL)
    return _load_json(PLAYER_METRICS_PATH), _load_json(ECONOMY_PRESSURE_PATH), _load_json(QUALITY_EVAL_PATH)


def _pressure_for_node(economy: dict[str, object], node: str) -> float:
    for item in list(economy.get("top_pressure_nodes", [])):
        if str(item.get("node", "")) == node:
            return float(item.get("pressure", 0.0))
    propagation = dict(economy.get("reward_pressure_propagation", {}))
    for item in list(propagation.get("top_pressure_nodes", [])):
        if str(item.get("node", "")) == node:
            return float(item.get("pressure", 0.0))
    return 0.0


def _top_pressure_gap(economy: dict[str, object]) -> float:
    return float(economy.get("top_pressure_gap", 0.0))


def _top_pressure_concentration(economy: dict[str, object]) -> float:
    return float(economy.get("top_pressure_concentration", 0.0))


def _candidate_target_maps(economy: dict[str, object], rows: list[dict[str, str]], limit: int = 4) -> list[str]:
    available = {str(row.get("map_id", "")) for row in rows}
    targets: list[str] = []
    for item in list(economy.get("top_pressure_nodes", [])):
        node = str(item.get("node", "")).strip()
        if not node.startswith("map:"):
            continue
        map_id = node.split(":", 1)[1]
        if map_id in BLOCKED_MAPS or map_id not in available or map_id in targets:
            continue
        targets.append(map_id)
        if len(targets) >= limit:
            break
    return targets


def _band_rows(rows: list[dict[str, str]], band_id: str) -> list[dict[str, str]]:
    return [row for row in rows if row["band_id"] == band_id]


def _spreads(rows: list[dict[str, str]], band_id: str) -> dict[str, float]:
    band_rows = _band_rows(rows, band_id)
    throughput = [float(row["throughput_bias"]) for row in band_rows]
    reward = [float(row["reward_bias"]) for row in band_rows]
    return {
        "throughput_spread": round(max(throughput) - min(throughput), 4),
        "reward_spread": round(max(reward) - min(reward), 4),
    }


def _distance(candidate: dict[str, float], current: dict[str, float]) -> float:
    return round(
        abs(candidate["throughput_bias"] - current["throughput_bias"])
        + abs(candidate["reward_bias"] - current["reward_bias"]),
        4,
    )


def _candidate_sort_key(candidate: dict[str, object]) -> tuple[float, ...]:
    return (
        -round(float(candidate["top_pressure_gap"]), 4),
        -round(float(candidate["top_pressure_concentration"]), 4),
        int(candidate["economy_pressure_balance_center"]),
        int(candidate["economy_coherence_center"]),
        -float(candidate["drop_pressure"]),
        -round(float(candidate["target_pressure"]), 4),
        float(candidate["alternative_throughput_bias"]),
        float(candidate["alternative_reward_bias"]),
        -float(candidate["distance_from_baseline"]),
    )


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
            raise RuntimeError("next-map rebalance report is stale while another search holds the lock")
        fieldnames, original_rows = _read_role_bands()
        original_signature = _rows_signature(original_rows)
        baseline_player, baseline_economy, baseline_quality = _run_simulation()
        target_maps = _candidate_target_maps(baseline_economy, original_rows)
        target_map = target_maps[0] if target_maps else ""

        report: dict[str, object] = {
            "target_map": target_map,
            "evaluated_targets": target_maps,
            "recommendation": "no_next_map_candidate",
            "candidate_count": 0,
            "best_candidate": None,
            "candidates": [],
        }
        if not target_map:
            REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
            REPORT_PATH.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
            print(REPORT_PATH)
            return 0

        report["baseline"] = {
            "primary_target_map": target_map,
            "economy_coherence": str(baseline_player["ranges"]["economy_coherence"]),
            "economy_coherence_center": int(baseline_player["centers"]["economy_coherence"]),
            "economy_pressure_balance": str(baseline_quality.get("economy_pressure_balance", "60~60")),
            "economy_pressure_balance_center": _range_center(baseline_quality.get("economy_pressure_balance", "60~60")),
            "drop_pressure": round(float(baseline_economy.get("drop_pressure", 0.0)), 4),
            "top_pressure_gap": round(_top_pressure_gap(baseline_economy), 4),
            "top_pressure_concentration": round(_top_pressure_concentration(baseline_economy), 4),
        }

        candidates: list[dict[str, object]] = []
        last_written_rows = original_rows
        try:
            for target_map in target_maps:
                target_row = next(row for row in original_rows if row["map_id"] == target_map)
                band_id = str(target_row["band_id"])
                band_rows = _band_rows(original_rows, band_id)
                alternative_row = next((row for row in band_rows if row.get("role") == "alternative"), None)
                if not alternative_row:
                    continue
                current = {
                    "throughput_bias": float(target_row["throughput_bias"]),
                    "reward_bias": float(target_row["reward_bias"]),
                }
                alternative_current = {
                    "map_id": str(alternative_row["map_id"]),
                    "throughput_bias": float(alternative_row["throughput_bias"]),
                    "reward_bias": float(alternative_row["reward_bias"]),
                }
                if alternative_current["map_id"] == target_map:
                    continue
                throughput_steps = sorted({round(current["throughput_bias"] - delta, 2) for delta in TARGET_THROUGHPUT_DELTAS})
                reward_steps = sorted({round(current["reward_bias"] - delta, 2) for delta in TARGET_REWARD_DELTAS})
                alt_throughput_steps = sorted(
                    {round(alternative_current["throughput_bias"] + delta, 2) for delta in ALTERNATIVE_THROUGHPUT_DELTAS}
                )
                alt_reward_steps = sorted(
                    {round(alternative_current["reward_bias"] + delta, 2) for delta in ALTERNATIVE_REWARD_DELTAS}
                )
                baseline_pressure = _pressure_for_node(baseline_economy, f"map:{target_map}")
                for throughput_bias in throughput_steps:
                    if throughput_bias <= 1.0:
                        continue
                    for reward_bias in reward_steps:
                        if reward_bias <= 1.0 or reward_bias < throughput_bias:
                            continue
                        for alt_throughput_bias in alt_throughput_steps:
                            if throughput_bias <= alt_throughput_bias:
                                continue
                            for alt_reward_bias in alt_reward_steps:
                                if alt_throughput_bias <= 1.0 or alt_reward_bias <= 1.0:
                                    continue
                                if reward_bias <= alt_reward_bias:
                                    continue
                                if (current["reward_bias"] - reward_bias) < 0.02 and (alt_reward_bias - alternative_current["reward_bias"]) > 0.01:
                                    continue
                                rows = deepcopy(original_rows)
                                for row in rows:
                                    if row["map_id"] == target_map:
                                        row["throughput_bias"] = f"{throughput_bias:.2f}".rstrip("0").rstrip(".")
                                        row["reward_bias"] = f"{reward_bias:.2f}".rstrip("0").rstrip(".")
                                    elif row["map_id"] == alternative_current["map_id"]:
                                        row["throughput_bias"] = f"{alt_throughput_bias:.2f}".rstrip("0").rstrip(".")
                                        row["reward_bias"] = f"{alt_reward_bias:.2f}".rstrip("0").rstrip(".")
                                spreads = _spreads(rows, band_id)
                                if spreads["throughput_spread"] < 0.12 or spreads["reward_spread"] < 0.14:
                                    continue
                                _write_role_bands(fieldnames, rows)
                                last_written_rows = rows
                                player, economy, quality = _run_simulation()
                                target_pressure = _pressure_for_node(economy, f"map:{target_map}")
                                drop_pressure = round(float(economy.get("drop_pressure", 0.0)), 4)
                                pressure_balance_center = _range_center(quality.get("economy_pressure_balance", "60~60"))
                                top_gap = _top_pressure_gap(economy)
                                top_concentration = _top_pressure_concentration(economy)
                                candidate = {
                                    "band_id": band_id,
                                    "baseline_target_pressure": round(baseline_pressure, 4),
                                    "target_map": target_map,
                                    "throughput_bias": throughput_bias,
                                    "reward_bias": reward_bias,
                                    "alternative_map": alternative_current["map_id"],
                                    "alternative_throughput_bias": round(alt_throughput_bias, 2),
                                    "alternative_reward_bias": round(alt_reward_bias, 2),
                                    "economy_coherence": str(player["ranges"]["economy_coherence"]),
                                    "economy_coherence_center": int(player["centers"]["economy_coherence"]),
                                    "economy_pressure_balance": str(quality.get("economy_pressure_balance", "60~60")),
                                    "economy_pressure_balance_center": pressure_balance_center,
                                    "drop_pressure": drop_pressure,
                                    "target_pressure": round(target_pressure, 4),
                                    "top_pressure_gap": round(top_gap, 4),
                                    "top_pressure_concentration": round(top_concentration, 4),
                                    "distance_from_baseline": round(
                                        _distance({"throughput_bias": throughput_bias, "reward_bias": reward_bias}, current)
                                        + _distance(
                                            {"throughput_bias": alt_throughput_bias, "reward_bias": alt_reward_bias},
                                            {
                                                "throughput_bias": alternative_current["throughput_bias"],
                                                "reward_bias": alternative_current["reward_bias"],
                                            },
                                        ),
                                        4,
                                    ),
                                    "band_spreads": spreads,
                                }
                                candidate["sort_key"] = _candidate_sort_key(candidate)
                                candidates.append(candidate)
        finally:
            _, current_rows = _read_role_bands()
            if _rows_signature(current_rows) != _rows_signature(last_written_rows):
                raise RuntimeError("role_bands.csv changed during next-map search; refusing to overwrite newer state")
            _write_role_bands(fieldnames, original_rows)
            _, restored_rows = _read_role_bands()
            if _rows_signature(restored_rows) != original_signature:
                raise RuntimeError("failed to restore role_bands.csv baseline after next-map search")
            _run_simulation()

        candidates.sort(key=lambda item: item["sort_key"], reverse=True)
        for item in candidates:
            item.pop("sort_key", None)

        best = candidates[0] if candidates else None
        report["candidate_count"] = len(candidates)
        report["best_candidate"] = best
        report["candidates"] = candidates[:12]
        if best:
            report["target_map"] = best["target_map"]
            report["baseline"].update(
                {
                    "band_id": best["band_id"],
                    "current_biases": {
                        "throughput_bias": next(
                            float(row["throughput_bias"]) for row in original_rows if row["map_id"] == best["target_map"]
                        ),
                        "reward_bias": next(
                            float(row["reward_bias"]) for row in original_rows if row["map_id"] == best["target_map"]
                        ),
                    },
                    "alternative_biases": {
                        "map_id": best["alternative_map"],
                        "throughput_bias": next(
                            float(row["throughput_bias"]) for row in original_rows if row["map_id"] == best["alternative_map"]
                        ),
                        "reward_bias": next(
                            float(row["reward_bias"]) for row in original_rows if row["map_id"] == best["alternative_map"]
                        ),
                    },
                    "band_spreads": _spreads(original_rows, best["band_id"]),
                    "target_pressure": round(_pressure_for_node(baseline_economy, f"map:{best['target_map']}"), 4),
                }
            )
        if best and (
            best["top_pressure_gap"] < report["baseline"]["top_pressure_gap"]
            or best["top_pressure_concentration"] < report["baseline"]["top_pressure_concentration"]
            or
            best["economy_pressure_balance_center"] > report["baseline"]["economy_pressure_balance_center"]
            or best["economy_coherence_center"] > report["baseline"]["economy_coherence_center"]
            or best["drop_pressure"] < report["baseline"]["drop_pressure"]
            or best["target_pressure"] < report["baseline"]["target_pressure"]
        ):
            report["recommendation"] = "use_best_candidate"
        else:
            report["recommendation"] = "next-map rebalance exhausted"

        REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
        REPORT_PATH.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        print(REPORT_PATH)
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
