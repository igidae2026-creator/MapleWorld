from __future__ import annotations

import csv
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
ROLE_BANDS_PATH = ROOT_DIR / "data" / "balance" / "maps" / "role_bands.csv"
SIM_OUTPUT_DIR = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs"
PLAYER_METRICS_PATH = SIM_OUTPUT_DIR / "player_experience_metrics_latest.json"
ECONOMY_PRESSURE_PATH = SIM_OUTPUT_DIR / "economy_pressure_metrics_latest.json"
FUN_GUARD_PATH = SIM_OUTPUT_DIR / "fun_guard_metrics_latest.json"
REPORT_PATH = SIM_OUTPUT_DIR / "early02_shadow_relief_candidates.json"


def _read_rows(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        return list(reader.fieldnames or []), list(reader)


def _write_rows(path: Path, fieldnames: list[str], rows: list[dict[str, str]]) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def _run_metrics() -> tuple[dict[str, object], dict[str, object], dict[str, object]]:
    subprocess.run([sys.executable, "simulation_py/run_all.py"], cwd=ROOT_DIR, check=True, stdout=subprocess.DEVNULL)
    subprocess.run([sys.executable, "metrics_engine/run_quality_eval.py"], cwd=ROOT_DIR, check=True, stdout=subprocess.DEVNULL)
    player = json.loads(PLAYER_METRICS_PATH.read_text(encoding="utf-8"))
    economy = json.loads(ECONOMY_PRESSURE_PATH.read_text(encoding="utf-8"))
    fun = json.loads(FUN_GUARD_PATH.read_text(encoding="utf-8"))
    return player, economy, fun


def _pressure_for(economy: dict[str, object], node: str) -> float:
    for item in economy.get("top_pressure_nodes", []):
        if item.get("node") == node:
            return float(item.get("pressure", 0.0))
    return 0.0


def _set_early02(rows: list[dict[str, str]], lith_t: float, lith_r: float, ell_t: float, ell_r: float) -> list[dict[str, str]]:
    out = [dict(row) for row in rows]
    for row in out:
        if row["map_id"] == "lith_harbor_coast_road":
            row["throughput_bias"] = f"{lith_t:.2f}".rstrip("0").rstrip(".")
            row["reward_bias"] = f"{lith_r:.2f}".rstrip("0").rstrip(".")
        elif row["map_id"] == "ellinia_lower_canopy":
            row["throughput_bias"] = f"{ell_t:.2f}".rstrip("0").rstrip(".")
            row["reward_bias"] = f"{ell_r:.2f}".rstrip("0").rstrip(".")
    return out


def main() -> int:
    fieldnames, rows = _read_rows(ROLE_BANDS_PATH)
    original = ROLE_BANDS_PATH.read_text(encoding="utf-8")
    baseline_player, baseline_economy, baseline_fun = _run_metrics()
    baseline = {
        "economy_coherence_center": baseline_player["centers"]["economy_coherence"],
        "top_pressure_gap": baseline_economy.get("top_pressure_gap"),
        "top_pressure_concentration": baseline_economy.get("top_pressure_concentration"),
        "patch_veto": baseline_fun.get("patch_veto"),
    }

    candidates: list[dict[str, object]] = []
    try:
        for lith_t in (0.95, 0.96, 0.97):
            for lith_r in (0.98, 0.99):
                for ell_t in (1.06, 1.07, 1.08):
                    for ell_r in (1.07, 1.08, 1.09):
                        test_rows = _set_early02(rows, lith_t, lith_r, ell_t, ell_r)
                        _write_rows(ROLE_BANDS_PATH, fieldnames, test_rows)
                        player, economy, fun = _run_metrics()
                        if fun.get("patch_veto") != "allow":
                            continue
                        candidate = {
                            "lith_throughput": lith_t,
                            "lith_reward": lith_r,
                            "ellinia_throughput": ell_t,
                            "ellinia_reward": ell_r,
                            "economy_coherence_center": player["centers"]["economy_coherence"],
                            "top_pressure_gap": economy.get("top_pressure_gap"),
                            "top_pressure_concentration": economy.get("top_pressure_concentration"),
                            "perion_pressure": _pressure_for(economy, "map:perion_rockfall_edge"),
                            "ellinia_pressure": _pressure_for(economy, "map:ellinia_lower_canopy"),
                            "lith_pressure": _pressure_for(economy, "map:lith_harbor_coast_road"),
                        }
                        candidate["sort_key"] = (
                            -float(candidate["top_pressure_gap"]),
                            -float(candidate["top_pressure_concentration"]),
                            int(candidate["economy_coherence_center"]),
                        )
                        candidates.append(candidate)
    finally:
        ROLE_BANDS_PATH.write_text(original, encoding="utf-8")
        _run_metrics()

    candidates.sort(key=lambda item: item["sort_key"], reverse=True)
    for item in candidates:
        item.pop("sort_key", None)

    payload = {
        "baseline": baseline,
        "candidate_count": len(candidates),
        "best_candidate": candidates[0] if candidates else None,
        "candidates": candidates[:20],
        "recommendation": (
            "same-band early_02 shadow relief exhausted"
            if not candidates
            or (
                float(candidates[0]["top_pressure_gap"]) >= float(baseline["top_pressure_gap"]) - 0.01
                and float(candidates[0]["top_pressure_concentration"]) >= float(baseline["top_pressure_concentration"]) - 0.003
            )
            else "use_best_candidate"
        ),
    }
    REPORT_PATH.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(REPORT_PATH)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
