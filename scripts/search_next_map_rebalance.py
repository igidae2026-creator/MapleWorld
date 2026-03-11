from __future__ import annotations

import csv
import json
import subprocess
import sys
from copy import deepcopy
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
ROLE_BANDS_PATH = ROOT_DIR / "data" / "balance" / "maps" / "role_bands.csv"
ECONOMY_PRESSURE_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs" / "economy_pressure_metrics_latest.json"
PLAYER_METRICS_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs" / "player_experience_metrics_latest.json"
REPORT_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs" / "next_map_rebalance_candidates.json"
BLOCKED_MAPS = {"perion_rockfall_edge", "ellinia_lower_canopy", "lith_harbor_coast_road"}


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


def _run_simulation() -> tuple[dict[str, object], dict[str, object]]:
    subprocess.run([sys.executable, "simulation_py/run_all.py"], cwd=ROOT_DIR, check=True, stdout=subprocess.DEVNULL)
    subprocess.run([sys.executable, "metrics_engine/run_quality_eval.py"], cwd=ROOT_DIR, check=True, stdout=subprocess.DEVNULL)
    return _load_json(PLAYER_METRICS_PATH), _load_json(ECONOMY_PRESSURE_PATH)


def _pressure_for_node(economy: dict[str, object], node: str) -> float:
    for item in list(economy.get("top_pressure_nodes", [])):
        if str(item.get("node", "")) == node:
            return float(item.get("pressure", 0.0))
    propagation = dict(economy.get("reward_pressure_propagation", {}))
    for item in list(propagation.get("top_pressure_nodes", [])):
        if str(item.get("node", "")) == node:
            return float(item.get("pressure", 0.0))
    return 0.0


def _next_target_map(economy: dict[str, object], rows: list[dict[str, str]]) -> str:
    available = {str(row.get("map_id", "")) for row in rows}
    for item in list(economy.get("top_pressure_nodes", [])):
        node = str(item.get("node", "")).strip()
        if not node.startswith("map:"):
            continue
        map_id = node.split(":", 1)[1]
        if map_id not in BLOCKED_MAPS and map_id in available:
            return map_id
    return ""


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


def main() -> int:
    fieldnames, original_rows = _read_role_bands()
    original_text = ROLE_BANDS_PATH.read_text(encoding="utf-8")
    baseline_player, baseline_economy = _run_simulation()
    target_map = _next_target_map(baseline_economy, original_rows)

    report: dict[str, object] = {
        "target_map": target_map,
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

    target_row = next(row for row in original_rows if row["map_id"] == target_map)
    band_id = str(target_row["band_id"])
    band_rows = _band_rows(original_rows, band_id)
    alternative_row = next((row for row in band_rows if row.get("role") == "alternative"), None)
    safe_reward = max(float(row["reward_bias"]) for row in band_rows if row["map_id"] != target_map)
    safe_throughput = max(float(row["throughput_bias"]) for row in band_rows if row["map_id"] != target_map)
    current = {
        "throughput_bias": float(target_row["throughput_bias"]),
        "reward_bias": float(target_row["reward_bias"]),
    }
    alternative_current = {
        "map_id": str(alternative_row["map_id"]) if alternative_row else "",
        "throughput_bias": float(alternative_row["throughput_bias"]) if alternative_row else 0.0,
        "reward_bias": float(alternative_row["reward_bias"]) if alternative_row else 0.0,
    }
    baseline_pressure = _pressure_for_node(baseline_economy, f"map:{target_map}")
    report["baseline"] = {
        "band_id": band_id,
        "economy_coherence": str(baseline_player["ranges"]["economy_coherence"]),
        "economy_coherence_center": int(baseline_player["centers"]["economy_coherence"]),
        "target_pressure": round(baseline_pressure, 4),
        "current_biases": current,
        "alternative_biases": alternative_current,
        "band_spreads": _spreads(original_rows, band_id),
    }

    candidates: list[dict[str, object]] = []
    try:
        throughput_steps = [round(current["throughput_bias"] - delta, 2) for delta in (0.01, 0.02, 0.03)]
        reward_steps = [round(current["reward_bias"] - delta, 2) for delta in (0.00, 0.01, 0.02, 0.03, 0.04, 0.05, 0.06)]
        alt_throughput_steps = [alternative_current["throughput_bias"]]
        alt_reward_steps = [alternative_current["reward_bias"]]
        if alternative_row:
            alt_throughput_steps.extend(round(alternative_current["throughput_bias"] + delta, 2) for delta in (0.01, 0.02))
            alt_reward_steps.extend(round(alternative_current["reward_bias"] + delta, 2) for delta in (0.01, 0.02))
        for throughput_bias in throughput_steps:
            for reward_bias in reward_steps:
                for alt_throughput_bias in alt_throughput_steps:
                    for alt_reward_bias in alt_reward_steps:
                        if throughput_bias <= alt_throughput_bias or reward_bias <= alt_reward_bias:
                            continue
                        if alt_throughput_bias <= 1.0 or alt_reward_bias <= 1.0:
                            continue
                        rows = deepcopy(original_rows)
                        for row in rows:
                            if row["map_id"] == target_map:
                                row["throughput_bias"] = f"{throughput_bias:.2f}".rstrip("0").rstrip(".")
                                row["reward_bias"] = f"{reward_bias:.2f}".rstrip("0").rstrip(".")
                            elif alternative_row and row["map_id"] == alternative_current["map_id"]:
                                row["throughput_bias"] = f"{alt_throughput_bias:.2f}".rstrip("0").rstrip(".")
                                row["reward_bias"] = f"{alt_reward_bias:.2f}".rstrip("0").rstrip(".")
                        spreads = _spreads(rows, band_id)
                        if spreads["throughput_spread"] < 0.12 or spreads["reward_spread"] < 0.14:
                            continue
                        _write_role_bands(fieldnames, rows)
                        player, economy = _run_simulation()
                        target_pressure = _pressure_for_node(economy, f"map:{target_map}")
                        candidate = {
                            "band_id": band_id,
                            "target_map": target_map,
                            "throughput_bias": throughput_bias,
                            "reward_bias": reward_bias,
                            "alternative_map": alternative_current["map_id"],
                            "alternative_throughput_bias": round(alt_throughput_bias, 2),
                            "alternative_reward_bias": round(alt_reward_bias, 2),
                            "economy_coherence": str(player["ranges"]["economy_coherence"]),
                            "economy_coherence_center": int(player["centers"]["economy_coherence"]),
                            "target_pressure": round(target_pressure, 4),
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
                        candidate["sort_key"] = (
                            int(player["centers"]["economy_coherence"]),
                            -round(target_pressure, 4),
                            alt_reward_bias,
                            reward_bias,
                            -candidate["distance_from_baseline"],
                        )
                        candidates.append(candidate)
    finally:
        ROLE_BANDS_PATH.write_text(original_text, encoding="utf-8")
        _run_simulation()

    candidates.sort(key=lambda item: item["sort_key"], reverse=True)
    for item in candidates:
        item.pop("sort_key", None)

    best = candidates[0] if candidates else None
    report["candidate_count"] = len(candidates)
    report["best_candidate"] = best
    report["candidates"] = candidates[:12]
    if best and (
        best["economy_coherence_center"] > report["baseline"]["economy_coherence_center"]
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
