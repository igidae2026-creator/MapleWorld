from __future__ import annotations

import csv
import json
import re
from dataclasses import dataclass
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
RUNS_DIR = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs"
OUTPUT_PATH = RUNS_DIR / "fun_guard_metrics_latest.json"


def _clamp(value: int, floor: int = 60, ceiling: int = 95) -> int:
    return max(floor, min(ceiling, int(value)))


def _range_string(center: int) -> str:
    center = _clamp(center)
    low = _clamp(center - 1)
    high = _clamp(center + 2)
    return f"{low}~{high}"


def _average(values: list[float]) -> float:
    return sum(values) / len(values) if values else 0.0


def _unique_count(values: list[float]) -> int:
    return len({round(value, 6) for value in values})


def _missing_reason(kind: str, values: list[str]) -> str | None:
    if not values:
        return None
    joined = ", ".join(values)
    return f"locked {kind} missing or normalized away: {joined}"


@dataclass(frozen=True)
class FunGuardSources:
    drop_table_path: Path
    level_curve_path: Path
    regional_progression_path: Path
    runtime_tables_path: Path
    canon_lock_path: Path
    python_simulation_path: Path

    @classmethod
    def default(cls) -> "FunGuardSources":
        return cls(
            drop_table_path=ROOT_DIR / "data" / "balance" / "drops" / "drop_table.csv",
            level_curve_path=ROOT_DIR / "data" / "balance" / "progression" / "level_curve.csv",
            regional_progression_path=ROOT_DIR / "data" / "regional_progression_tables.lua",
            runtime_tables_path=ROOT_DIR / "runtime_tables.lua",
            canon_lock_path=ROOT_DIR / "data" / "canon" / "locked_assets.json",
            python_simulation_path=RUNS_DIR / "python_simulation_latest.json",
        )


def _read_csv_rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def _load_locked_assets(path: Path) -> dict[str, list[str]]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    return {
        "regions": [str(value) for value in payload.get("regions", [])],
        "bosses": [str(value) for value in payload.get("bosses", [])],
        "rewards": [str(value) for value in payload.get("rewards", [])],
        "early_loop_segments": [str(value) for value in payload.get("early_loop_segments", [])],
    }


def _parse_regional_progression(text: str) -> list[dict[str, object]]:
    pattern = re.compile(
        r"\{\s*id = '([^']+)', range = \{\s*(\d+),\s*(\d+)\s*\}, loop = '([^']+)'\s*\}",
        re.MULTILINE,
    )
    rows = []
    for match in pattern.finditer(text):
        rows.append(
            {
                "id": match.group(1),
                "min_level": int(match.group(2)),
                "max_level": int(match.group(3)),
                "loop": match.group(4),
            }
        )
    return rows


def _parse_reward_suffixes(text: str) -> set[str]:
    return set(re.findall(r"reward = region\.id \.\. '_([^']+)'", text))


def _parse_region_level_ranges(text: str) -> dict[str, dict[str, object]]:
    block_match = re.search(r"runtime\.region_level_ranges = \{(.*?)\n\}", text, re.DOTALL)
    if not block_match:
        return {}
    block = block_match.group(1)
    pattern = re.compile(
        r"(\w+)\s*=\s*\{\s*min = (\d+), max = (\d+), hub = '([^']+)', entry = '([^']+)'\s*\}",
        re.MULTILINE,
    )
    out: dict[str, dict[str, object]] = {}
    for match in pattern.finditer(block):
        out[match.group(1)] = {
            "min": int(match.group(2)),
            "max": int(match.group(3)),
            "hub": match.group(4),
            "entry": match.group(5),
        }
    return out


def _parse_region_equipment_weights(text: str) -> dict[str, dict[str, float]]:
    block_match = re.search(r"runtime\.region_equipment_weights = \{(.*?)\n\}", text, re.DOTALL)
    if not block_match:
        return {}
    block = block_match.group(1)
    pattern = re.compile(
        r"(\w+)\s*=\s*\{\s*weapon = ([0-9.]+), armor = ([0-9.]+), accessory = ([0-9.]+), consumable = ([0-9.]+)\s*\}",
        re.MULTILINE,
    )
    out: dict[str, dict[str, float]] = {}
    for match in pattern.finditer(block):
        out[match.group(1)] = {
            "weapon": float(match.group(2)),
            "armor": float(match.group(3)),
            "accessory": float(match.group(4)),
            "consumable": float(match.group(5)),
        }
    return out


def _parse_boss_groups(text: str) -> set[str]:
    block_match = re.search(r"runtime\.boss_respawn_groups = \{(.*?)\n\}", text, re.DOTALL)
    if not block_match:
        return set()
    return set(re.findall(r"'([^']+)'", block_match.group(1)))


def _load_map_role_distribution(path: Path) -> dict[str, dict[str, object]]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    return dict(payload.get("world", {}).get("map_role_distribution", {}))


def _score_distinctiveness(regions: list[dict[str, object]], equipment_weights: dict[str, dict[str, float]]) -> int:
    unique_loops = len({str(region["loop"]).lower() for region in regions})
    dominant_roles = {
        max(weights, key=weights.get)
        for weights in equipment_weights.values()
        if weights
    }
    early_mid_late = len(
        {
            "early" if int(region["min_level"]) <= 30 else "mid" if int(region["min_level"]) <= 70 else "late"
            for region in regions
        }
    )
    score = 70 + min(10, unique_loops) + min(8, len(dominant_roles) * 2) + min(7, early_mid_late * 2)
    return _clamp(score)


def _score_variance_health(drop_rows: list[dict[str, str]], level_rows: list[dict[str, str]]) -> int:
    rates = [float(row["drop_rate"]) for row in drop_rows if row.get("drop_rate")]
    rarity_count = len({row.get("rarity_band", "") for row in drop_rows if row.get("rarity_band")})
    rate_span = (max(rates) - min(rates)) if rates else 0.0
    unique_rates = _unique_count(rates)
    early_exp = [int(row["exp_required"]) for row in level_rows if row.get("level") and int(row["level"]) <= 30]
    deltas = [max(0, right - left) for left, right in zip(early_exp, early_exp[1:])]
    delta_span = (max(deltas) - min(deltas)) if deltas else 0
    score = 66 + min(10, rarity_count * 2) + min(8, int(rate_span * 100)) + min(8, unique_rates // 6) + min(5, delta_span // 300)
    return _clamp(score)


def _score_memorable_rewards(
    drop_rows: list[dict[str, str]],
    reward_suffixes: set[str],
    boss_ids: set[str],
) -> int:
    rare_like_count = sum(1 for row in drop_rows if row.get("rarity_band") in {"rare", "elite", "boss"})
    boss_count = sum(1 for row in drop_rows if row.get("rarity_band") == "boss")
    score = 68 + min(8, len(reward_suffixes) * 2) + min(8, len(boss_ids) // 2) + min(9, rare_like_count // 20) + min(5, boss_count)
    return _clamp(score)


def _score_early_loop_texture(
    regions: list[dict[str, object]],
    runtime_ranges: dict[str, dict[str, object]],
    early_loop_segments: list[str],
) -> int:
    early_regions = [region for region in regions if int(region["min_level"]) <= 30]
    runtime_early_ranges = [
        row for row in runtime_ranges.values() if int(row["min"]) <= 30 and int(row["max"]) >= 15
    ]
    combined_loops = " ".join(str(region["loop"]).lower() for region in early_regions)
    segment_hits = sum(1 for segment in early_loop_segments if segment.lower() in combined_loops)
    overlap_count = sum(
        1
        for left, right in zip(early_regions, early_regions[1:])
        if int(left["max_level"]) >= int(right["min_level"]) - 4
    )
    score = 70 + min(8, len(early_regions) * 2) + min(8, len(runtime_early_ranges) * 2) + min(8, segment_hits * 2) + min(4, overlap_count)
    return _clamp(score)


def _score_map_role_separation(map_role_distribution: dict[str, dict[str, object]]) -> int:
    required_roles = {"safe", "alternative", "high_risk_high_reward"}
    intact_bands = 0
    unique_patterns: set[tuple[str, str, str]] = set()
    populated_bands = 0
    for band in map_role_distribution.values():
        roles = band.get("roles", {})
        role_keys = set(roles.keys())
        if band.get("population", 0) > 0:
            populated_bands += 1
        if required_roles.issubset(role_keys):
            intact_bands += 1
        pattern = tuple(str(roles.get(role, {}).get("map_id", "")) for role in sorted(required_roles))
        if any(pattern):
            unique_patterns.add(pattern)
    score = 68 + min(12, intact_bands * 2) + min(8, len(unique_patterns) * 2) + min(7, populated_bands)
    return _clamp(score)


def _map_role_risk_reasons(map_role_distribution: dict[str, dict[str, object]]) -> list[str]:
    required_roles = {"safe", "alternative", "high_risk_high_reward"}
    reasons: list[str] = []
    patterns: dict[tuple[str, str, str], list[str]] = {}
    spread_floor = 0.12
    for band_id, band in sorted(map_role_distribution.items()):
        if int(band.get("population", 0)) <= 0:
            continue
        roles = band.get("roles", {})
        missing_roles = sorted(required_roles - set(roles.keys()))
        if missing_roles:
            reasons.append(f"map role band {band_id} missing required roles: {', '.join(missing_roles)}")
            continue
        pattern = tuple(str(roles[role].get("map_id", "")) for role in sorted(required_roles))
        patterns.setdefault(pattern, []).append(str(band_id))
        throughputs = [
            float(roles[role].get("throughput_proxy", 0.0))
            for role in ("safe", "alternative", "high_risk_high_reward")
        ]
        if (max(throughputs) - min(throughputs)) < spread_floor:
            reasons.append(
                f"map role band {band_id} throughput spread below floor: "
                f"{max(throughputs) - min(throughputs):.2f} < {spread_floor:.2f}"
            )
    repeated = [bands for bands in patterns.values() if len(bands) >= 2]
    if repeated:
        joined = "; ".join(", ".join(bands) for bands in repeated)
        reasons.append(f"map role pattern elevated risk: repeated band layouts across {joined}")
    return reasons


def validate_canon_locks(sources: FunGuardSources | None = None) -> dict[str, object]:
    active_sources = sources or FunGuardSources.default()
    locked_assets = _load_locked_assets(active_sources.canon_lock_path)
    regional_text = active_sources.regional_progression_path.read_text(encoding="utf-8")
    runtime_text = active_sources.runtime_tables_path.read_text(encoding="utf-8")

    regions = _parse_regional_progression(regional_text)
    region_ids = {str(region["id"]) for region in regions}
    region_ids.update(_parse_region_level_ranges(runtime_text).keys())
    boss_ids = _parse_boss_groups(runtime_text)
    reward_suffixes = _parse_reward_suffixes(regional_text)
    loop_text = " ".join(str(region["loop"]).lower() for region in regions)

    missing_regions = [region for region in locked_assets["regions"] if region not in region_ids]
    missing_bosses = [boss for boss in locked_assets["bosses"] if boss not in boss_ids]
    missing_rewards = [reward for reward in locked_assets["rewards"] if reward not in reward_suffixes]
    missing_segments = [segment for segment in locked_assets["early_loop_segments"] if segment.lower() not in loop_text]

    reasons = [
        reason
        for reason in (
            _missing_reason("regions", missing_regions),
            _missing_reason("bosses", missing_bosses),
            _missing_reason("rewards", missing_rewards),
            _missing_reason("early loop segments", missing_segments),
        )
        if reason is not None
    ]
    return {
        "locked_assets": locked_assets,
        "missing": {
            "regions": missing_regions,
            "bosses": missing_bosses,
            "rewards": missing_rewards,
            "early_loop_segments": missing_segments,
        },
        "status": "ok" if not reasons else "reject",
        "reasons": reasons,
    }


def build_fun_guard_metrics(sources: FunGuardSources | None = None) -> dict[str, object]:
    active_sources = sources or FunGuardSources.default()
    drop_rows = _read_csv_rows(active_sources.drop_table_path)
    level_rows = _read_csv_rows(active_sources.level_curve_path)
    regional_text = active_sources.regional_progression_path.read_text(encoding="utf-8")
    runtime_text = active_sources.runtime_tables_path.read_text(encoding="utf-8")

    regions = _parse_regional_progression(regional_text)
    runtime_ranges = _parse_region_level_ranges(runtime_text)
    equipment_weights = _parse_region_equipment_weights(runtime_text)
    reward_suffixes = _parse_reward_suffixes(regional_text)
    boss_ids = _parse_boss_groups(runtime_text)
    map_role_distribution = _load_map_role_distribution(active_sources.python_simulation_path)
    canon_status = validate_canon_locks(active_sources)

    centers = {
        "distinctiveness": _score_distinctiveness(regions, equipment_weights),
        "variance_health": _score_variance_health(drop_rows, level_rows),
        "memorable_rewards": _score_memorable_rewards(drop_rows, reward_suffixes, boss_ids),
        "early_loop_texture": _score_early_loop_texture(
            regions,
            runtime_ranges,
            canon_status["locked_assets"]["early_loop_segments"],
        ),
        "map_role_separation": _score_map_role_separation(map_role_distribution),
    }
    floors = {
        "distinctiveness": 82,
        "variance_health": 80,
        "memorable_rewards": 82,
        "early_loop_texture": 80,
        "map_role_separation": 82,
    }
    reasons = list(canon_status["reasons"])
    for key, floor in floors.items():
        if centers[key] < floor:
            reasons.append(f"{key} below floor: {centers[key]} < {floor}")
    reasons.extend(_map_role_risk_reasons(map_role_distribution))

    payload: dict[str, object] = {key: _range_string(value) for key, value in centers.items()}
    payload["floor_centers"] = floors
    payload["centers"] = centers
    payload["canon_lock_status"] = canon_status["status"]
    payload["canon_lock_reasons"] = canon_status["reasons"]
    payload["canon_lock_missing"] = canon_status["missing"]
    payload["map_role_distribution"] = map_role_distribution
    payload["veto_rules"] = [
        "reject if variance_health center falls below 80",
        "reject if map_role_separation center falls below 82",
        "reject if memorable_rewards center falls below 82",
        "reject if early_loop_texture center falls below 80",
        "reject if distinctiveness center falls below 82",
        "reject if any populated level band loses safe, alternative, or high_risk_high_reward map roles",
        "reject if multiple bands collapse into the same safe/alternative/high_risk_high_reward map pattern",
        "reject if any populated level band has throughput spread below 0.12 across safe, alternative, and high_risk_high_reward routes",
        "reject if any locked region, boss, reward, or early loop segment disappears or is normalized away",
    ]
    payload["patch_veto"] = "reject" if reasons else "allow"
    payload["reasons"] = reasons
    return payload


def write_fun_guard_metrics(
    sources: FunGuardSources | None = None,
    output_path: Path = OUTPUT_PATH,
) -> dict[str, object]:
    payload = build_fun_guard_metrics(sources)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return payload
