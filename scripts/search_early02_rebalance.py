from __future__ import annotations

import csv
import json
import subprocess
import sys
from copy import deepcopy
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
ROLE_BANDS_PATH = ROOT_DIR / "data" / "balance" / "maps" / "role_bands.csv"
REPORT_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs" / "early02_rebalance_candidates.json"
PLAYER_METRICS_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs" / "player_experience_metrics_latest.json"
ECONOMY_PRESSURE_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs" / "economy_pressure_metrics_latest.json"
TARGET_MAPS = {"lith_harbor_coast_road", "ellinia_lower_canopy", "perion_rockfall_edge"}
PERION_REWARD_FLOOR = 1.12
THROUGHPUT_SPREAD_FLOOR = 0.12
REWARD_SPREAD_FLOOR = 0.14


def _read_role_bands() -> tuple[list[str], list[dict[str, str]]]:
    with ROLE_BANDS_PATH.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        return list(reader.fieldnames or []), list(reader)


def _write_role_bands(fieldnames: list[str], rows: list[dict[str, str]]) -> None:
    with ROLE_BANDS_PATH.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def _run_simulation() -> tuple[dict[str, object], dict[str, object]]:
    subprocess.run([sys.executable, "simulation_py/run_all.py"], cwd=ROOT_DIR, check=True, stdout=subprocess.DEVNULL)
    subprocess.run([sys.executable, "metrics_engine/run_quality_eval.py"], cwd=ROOT_DIR, check=True, stdout=subprocess.DEVNULL)
    player = json.loads(PLAYER_METRICS_PATH.read_text(encoding="utf-8"))
    economy = json.loads(ECONOMY_PRESSURE_PATH.read_text(encoding="utf-8"))
    return player, economy


def _pressure_for_node(economy: dict[str, object], node: str) -> float:
    for item in list(economy.get("top_pressure_nodes", [])):
        if str(item.get("node", "")) == node:
            return float(item.get("pressure", 0.0))
    propagation = dict(economy.get("reward_pressure_propagation", {}))
    for item in list(propagation.get("top_pressure_nodes", [])):
        if str(item.get("node", "")) == node:
            return float(item.get("pressure", 0.0))
    return 0.0


def _ranges(rows: list[dict[str, str]]) -> dict[str, float]:
    early_rows = [row for row in rows if row["band_id"] == "early_02" and row["map_id"] in TARGET_MAPS]
    throughput = [float(row["throughput_bias"]) for row in early_rows]
    reward = [float(row["reward_bias"]) for row in early_rows]
    return {
        "throughput_spread": round(max(throughput) - min(throughput), 4),
        "reward_spread": round(max(reward) - min(reward), 4),
    }


def _candidate_rows(
    original_rows: list[dict[str, str]],
    lith_throughput: float,
    lith_reward: float,
    ellinia_throughput: float,
    ellinia_reward: float,
) -> list[dict[str, str]]:
    rows = deepcopy(original_rows)
    for row in rows:
        if row["band_id"] != "early_02":
            continue
        if row["map_id"] == "lith_harbor_coast_road":
            row["throughput_bias"] = f"{lith_throughput:.2f}".rstrip("0").rstrip(".")
            row["reward_bias"] = f"{lith_reward:.2f}".rstrip("0").rstrip(".")
        elif row["map_id"] == "ellinia_lower_canopy":
            row["throughput_bias"] = f"{ellinia_throughput:.2f}".rstrip("0").rstrip(".")
            row["reward_bias"] = f"{ellinia_reward:.2f}".rstrip("0").rstrip(".")
        elif row["map_id"] == "perion_rockfall_edge":
            row["reward_bias"] = f"{max(float(row['reward_bias']), PERION_REWARD_FLOOR):.2f}".rstrip("0").rstrip(".")
    return rows


def _extract_current(rows: list[dict[str, str]]) -> dict[str, tuple[float, float]]:
    current: dict[str, tuple[float, float]] = {}
    for row in rows:
        if row["band_id"] == "early_02" and row["map_id"] in TARGET_MAPS:
            current[row["map_id"]] = (float(row["throughput_bias"]), float(row["reward_bias"]))
    return current


def _distance_from_baseline(candidate: dict[str, object], current: dict[str, tuple[float, float]]) -> float:
    lith = candidate["lith_harbor_coast_road"]
    ellinia = candidate["ellinia_lower_canopy"]
    total = 0.0
    total += abs(float(lith["throughput_bias"]) - current["lith_harbor_coast_road"][0])
    total += abs(float(lith["reward_bias"]) - current["lith_harbor_coast_road"][1])
    total += abs(float(ellinia["throughput_bias"]) - current["ellinia_lower_canopy"][0])
    total += abs(float(ellinia["reward_bias"]) - current["ellinia_lower_canopy"][1])
    return round(total, 4)


def main() -> int:
    fieldnames, original_rows = _read_role_bands()
    original_text = ROLE_BANDS_PATH.read_text(encoding="utf-8")
    original_path_snapshot = ROLE_BANDS_PATH.read_text(encoding="utf-8")
    current = _extract_current(original_rows)

    current_player, current_economy = _run_simulation()
    baseline_gap = _pressure_for_node(current_economy, "map:perion_rockfall_edge") - _pressure_for_node(
        current_economy, "map:ellinia_lower_canopy"
    )
    baseline = {
        "economy_coherence": str(current_player["ranges"]["economy_coherence"]),
        "economy_coherence_center": int(current_player["centers"]["economy_coherence"]),
        "perion_pressure": _pressure_for_node(current_economy, "map:perion_rockfall_edge"),
        "ellinia_pressure": _pressure_for_node(current_economy, "map:ellinia_lower_canopy"),
        "lith_pressure": _pressure_for_node(current_economy, "map:lith_harbor_coast_road"),
        "top_pressure_nodes": list(current_economy.get("top_pressure_nodes", []))[:3],
        "early_02_spreads": _ranges(original_rows),
        "current_role_biases": {
            "lith_harbor_coast_road": {
                "throughput_bias": current["lith_harbor_coast_road"][0],
                "reward_bias": current["lith_harbor_coast_road"][1],
            },
            "ellinia_lower_canopy": {
                "throughput_bias": current["ellinia_lower_canopy"][0],
                "reward_bias": current["ellinia_lower_canopy"][1],
            },
            "perion_rockfall_edge": {
                "throughput_bias": current["perion_rockfall_edge"][0],
                "reward_bias": current["perion_rockfall_edge"][1],
            },
        },
    }

    candidates: list[dict[str, object]] = []
    try:
        for lith_throughput in (0.95, 0.96, 0.97):
            for lith_reward in (0.98, 0.99, 1.00):
                for ellinia_throughput in (1.03, 1.04, 1.05, 1.06):
                    for ellinia_reward in (1.04, 1.05, 1.06, 1.07, 1.08):
                        rows = _candidate_rows(
                            original_rows,
                            lith_throughput=lith_throughput,
                            lith_reward=lith_reward,
                            ellinia_throughput=ellinia_throughput,
                            ellinia_reward=ellinia_reward,
                        )
                        spreads = _ranges(rows)
                        if spreads["throughput_spread"] < THROUGHPUT_SPREAD_FLOOR:
                            continue
                        if spreads["reward_spread"] < REWARD_SPREAD_FLOOR:
                            continue

                        _write_role_bands(fieldnames, rows)
                        player, economy = _run_simulation()
                        perion = _pressure_for_node(economy, "map:perion_rockfall_edge")
                        ellinia = _pressure_for_node(economy, "map:ellinia_lower_canopy")
                        lith = _pressure_for_node(economy, "map:lith_harbor_coast_road")
                        if not (perion > ellinia > lith):
                            continue

                        gap = round(perion - ellinia, 4)
                        candidate = {
                            "lith_harbor_coast_road": {
                                "throughput_bias": round(lith_throughput, 4),
                                "reward_bias": round(lith_reward, 4),
                            },
                            "ellinia_lower_canopy": {
                                "throughput_bias": round(ellinia_throughput, 4),
                                "reward_bias": round(ellinia_reward, 4),
                            },
                            "economy_coherence": str(player["ranges"]["economy_coherence"]),
                            "economy_coherence_center": int(player["centers"]["economy_coherence"]),
                            "perion_pressure": round(perion, 4),
                            "ellinia_pressure": round(ellinia, 4),
                            "lith_pressure": round(lith, 4),
                            "perion_to_ellinia_gap": gap,
                            "ellinia_to_lith_gap": round(ellinia - lith, 4),
                            "perion_to_lith_gap": round(perion - lith, 4),
                            "top_pressure_nodes": list(economy.get("top_pressure_nodes", []))[:3],
                            "early_02_spreads": spreads,
                        }
                        candidate["distance_from_baseline"] = _distance_from_baseline(candidate, current)
                        candidate["sort_score"] = (
                            int(player["centers"]["economy_coherence"]),
                            -gap,
                            -candidate["distance_from_baseline"],
                        )
                        candidates.append(candidate)
    finally:
        if ROLE_BANDS_PATH.read_text(encoding="utf-8") != original_path_snapshot:
            raise RuntimeError("role_bands.csv changed during early_02 search; refusing to overwrite newer state")
        ROLE_BANDS_PATH.write_text(original_text, encoding="utf-8")
        _run_simulation()

    candidates.sort(key=lambda item: item["sort_score"], reverse=True)
    for item in candidates:
        item.pop("sort_score", None)

    best = candidates[0] if candidates else None
    report = {
        "baseline": baseline,
        "candidate_count": len(candidates),
        "best_candidate": best,
        "candidates": candidates[:12],
        "recommendation": (
            "use_best_candidate"
            if best
            and (
                best["economy_coherence_center"] > baseline["economy_coherence_center"]
                or best["perion_to_ellinia_gap"] < baseline_gap
            )
            else "same-band early_02 rebalance exhausted"
        ),
    }
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(REPORT_PATH)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
