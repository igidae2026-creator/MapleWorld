#!/usr/bin/env python3

from __future__ import annotations

import csv
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
OPS_STATE_DIR = ROOT / "ops" / "codex_state"
DATA_DIR = ROOT / "data"
ARCHITECTURE_CANDIDATES_DIR = DATA_DIR / "architecture_candidates" / "current_cycle"
ARCHITECTURE_SELECTED_DIR = DATA_DIR / "architecture_selected"
SIMULATION_DIR = DATA_DIR / "simulation"
CONSTRAINTS_DIR = DATA_DIR / "constraints"

ARCHITECTURE_SCORES_PATH = OPS_STATE_DIR / "architecture_scores.json"
ARCHITECTURE_REVIEW_LOG_PATH = OPS_STATE_DIR / "architecture_review_log.jsonl"
EVAL_SCORES_PATH = OPS_STATE_DIR / "eval_scores.json"
PROGRESS_PATH = OPS_STATE_DIR / "progress.json"

ZONE_LADDER_PATH = DATA_DIR / "balance" / "fields" / "zone_ladder.csv"
PARTY_WINDOWS_PATH = DATA_DIR / "balance" / "progression" / "party_windows.csv"
SINKS_PATH = DATA_DIR / "balance" / "economy" / "sinks.csv"
BOSS_REWARDS_PATH = DATA_DIR / "balance" / "bosses" / "boss_rewards.csv"

AGENT_COUNT = 96
TARGETS = {
    "architecture_score": 78.0,
    "overall_architecture_quality": 80.0,
}

BASELINE_PARAMETERS = {
    "field_instance_player_cap": 31,
    "congestion_routing_threshold": 0.76,
    "party_incentive_coefficient": 1.17,
    "potion_sink_pressure": 0.24,
    "upgrade_cost_curve": 1.0,
    "market_tax_rate": 0.095,
    "boss_reward_cadence": 0.68,
    "dungeon_entry_pressure": 0.55,
    "spawn_density_scaling": 1.0,
    "rare_drop_control": 0.82,
    "save_batch_seconds": 5,
    "rollback_window_minutes": 12,
    "event_ordering_buffer_ms": 110,
    "live_tuning_points": 10,
    "routing_owner_depth": 1.0,
    "economy_owner_depth": 1.0,
    "authority_entrypoints": 1.06,
    "persistence_isolation": 0.88,
    "rollback_isolation": 0.86,
    "operator_surface_depth": 0.91,
    "subsystem_overlap": 0.1,
    "hidden_mutation_risk": 0.08,
    "complexity_cost": 0.12,
    "social_density_support": 0.87,
}

TARGET_PARAMETER_PROFILES = {
    "field_instance_player_cap": (29.0, 4.0),
    "congestion_routing_threshold": (0.735, 0.05),
    "party_incentive_coefficient": (1.14, 0.07),
    "potion_sink_pressure": (0.248, 0.04),
    "upgrade_cost_curve": (1.05, 0.09),
    "market_tax_rate": (0.095, 0.012),
    "boss_reward_cadence": (0.62, 0.08),
    "dungeon_entry_pressure": (0.58, 0.08),
    "spawn_density_scaling": (1.01, 0.06),
    "rare_drop_control": (0.845, 0.05),
    "save_batch_seconds": (4.0, 1.2),
    "rollback_window_minutes": (10.5, 2.0),
    "event_ordering_buffer_ms": (106.0, 22.0),
    "live_tuning_points": (9.0, 2.0),
    "routing_owner_depth": (1.01, 0.06),
    "economy_owner_depth": (1.01, 0.06),
    "authority_entrypoints": (1.06, 0.08),
    "persistence_isolation": (0.91, 0.07),
    "rollback_isolation": (0.89, 0.07),
    "operator_surface_depth": (0.94, 0.06),
    "subsystem_overlap": (0.07, 0.05),
    "hidden_mutation_risk": (0.055, 0.04),
    "complexity_cost": (0.085, 0.05),
    "social_density_support": (0.905, 0.06),
}

DIMENSION_MUTATIONS = {
    "level_band_bottleneck_quality": [
        {"spawn_density_scaling": 0.02, "dungeon_entry_pressure": 0.03, "field_instance_player_cap": -1, "complexity_cost": -0.01},
        {"spawn_density_scaling": 0.03, "party_incentive_coefficient": -0.02, "congestion_routing_threshold": -0.01},
    ],
    "field_ladder_progression_quality": [
        {"field_instance_player_cap": -2, "congestion_routing_threshold": -0.02, "social_density_support": 0.03},
        {"spawn_density_scaling": -0.01, "dungeon_entry_pressure": 0.03, "complexity_cost": -0.01},
    ],
    "solo_party_split_quality": [
        {
            "party_incentive_coefficient": -0.02,
            "routing_owner_depth": -0.01,
            "economy_owner_depth": -0.01,
            "complexity_cost": -0.01,
        },
        {
            "party_incentive_coefficient": -0.015,
            "routing_owner_depth": -0.01,
            "economy_owner_depth": -0.01,
            "subsystem_overlap": -0.01,
            "complexity_cost": -0.01,
        },
    ],
    "field_competition_topology": [
        {"field_instance_player_cap": -2, "congestion_routing_threshold": -0.03, "social_density_support": 0.03},
        {"spawn_density_scaling": -0.02, "market_tax_rate": 0.002, "complexity_cost": -0.01},
    ],
    "social_density_anchor_quality": [
        {"social_density_support": 0.01, "party_incentive_coefficient": -0.03, "market_tax_rate": -0.003, "complexity_cost": -0.01},
        {"social_density_support": 0.02, "party_incentive_coefficient": -0.02, "rare_drop_control": -0.01, "operator_surface_depth": 0.02},
    ],
    "channel_congestion_routing_quality": [
        {"field_instance_player_cap": -1, "congestion_routing_threshold": -0.02, "routing_owner_depth": 0.04},
        {"field_instance_player_cap": -2, "spawn_density_scaling": -0.01, "complexity_cost": -0.01},
    ],
    "economy_source_sink_balance": [
        {
            "upgrade_cost_curve": 0.01,
        },
        {
            "upgrade_cost_curve": 0.005,
        },
    ],
    "meso_velocity_control": [
        {"market_tax_rate": 0.004, "potion_sink_pressure": 0.01, "boss_reward_cadence": -0.02},
        {"upgrade_cost_curve": 0.03, "rare_drop_control": 0.02, "complexity_cost": -0.01},
    ],
    "consumable_burn_pressure": [
        {"potion_sink_pressure": 0.025, "market_tax_rate": 0.001, "boss_reward_cadence": -0.03, "social_density_support": 0.01},
        {"potion_sink_pressure": 0.02, "spawn_density_scaling": 0.005, "upgrade_cost_curve": 0.02, "complexity_cost": -0.01},
    ],
    "rare_supply_throttling": [
        {"rare_drop_control": 0.03, "boss_reward_cadence": -0.02, "market_tax_rate": 0.002},
        {"rare_drop_control": 0.02, "upgrade_cost_curve": 0.03, "social_density_support": 0.01},
    ],
    "boss_cadence_lockout_quality": [
        {"boss_reward_cadence": -0.04, "rare_drop_control": 0.02, "dungeon_entry_pressure": 0.02},
        {"boss_reward_cadence": -0.03, "market_tax_rate": 0.002, "rollback_window_minutes": -1},
    ],
    "save_transaction_boundary_clarity": [
        {"save_batch_seconds": -1, "persistence_isolation": 0.03, "subsystem_overlap": -0.01},
        {"save_batch_seconds": -1, "rollback_window_minutes": -1, "operator_surface_depth": 0.01},
    ],
    "server_authority_event_ordering": [
        {"authority_entrypoints": 0.03, "event_ordering_buffer_ms": -10, "hidden_mutation_risk": -0.02},
        {"routing_owner_depth": 0.03, "economy_owner_depth": 0.03, "complexity_cost": -0.01},
    ],
    "anti_bot_anti_macro_runtime_quality": [
        {"hidden_mutation_risk": -0.02, "authority_entrypoints": 0.02, "operator_surface_depth": 0.02},
        {"routing_owner_depth": 0.03, "economy_owner_depth": 0.02, "live_tuning_points": 1},
    ],
    "liveops_intervention_visibility": [
        {
            "live_tuning_points": -1,
            "operator_surface_depth": 0.02,
            "economy_owner_depth": 0.02,
            "routing_owner_depth": 0.01,
            "subsystem_overlap": -0.01,
            "complexity_cost": -0.01,
        },
        {
            "live_tuning_points": -1,
            "operator_surface_depth": 0.03,
            "economy_owner_depth": 0.02,
            "routing_owner_depth": 0.02,
            "complexity_cost": -0.01,
        },
    ],
    "power_curve_replacement_pressure": [
        {"upgrade_cost_curve": 0.04, "rare_drop_control": 0.02, "boss_reward_cadence": -0.02},
        {"upgrade_cost_curve": 0.03, "potion_sink_pressure": 0.01, "complexity_cost": -0.01},
    ],
    "telemetry_feedback_visibility": [
        {
            "operator_surface_depth": -0.01,
            "economy_owner_depth": -0.02,
            "routing_owner_depth": -0.01,
            "complexity_cost": -0.01,
        },
        {
            "operator_surface_depth": -0.01,
            "economy_owner_depth": -0.01,
            "routing_owner_depth": -0.02,
            "subsystem_overlap": -0.01,
            "complexity_cost": -0.01,
        },
    ],
    "structural_clarity": [
        {"complexity_cost": -0.03, "subsystem_overlap": -0.02, "operator_surface_depth": 0.02},
        {"complexity_cost": -0.02, "hidden_mutation_risk": -0.02, "live_tuning_points": 1},
    ],
    "authority_path_integrity": [
        {"authority_entrypoints": 0.03, "event_ordering_buffer_ms": -10, "hidden_mutation_risk": -0.02},
        {"routing_owner_depth": 0.03, "economy_owner_depth": 0.02, "complexity_cost": -0.01},
    ],
    "persistence_boundary_clarity": [
        {"persistence_isolation": 0.03, "save_batch_seconds": -1, "rollback_window_minutes": -1},
        {"persistence_isolation": 0.04, "subsystem_overlap": -0.01, "operator_surface_depth": 0.01},
    ],
    "rollback_boundary_clarity": [
        {
            "rollback_window_minutes": -1,
            "rollback_isolation": 0.03,
            "event_ordering_buffer_ms": -2,
            "boss_reward_cadence": -0.03,
            "dungeon_entry_pressure": 0.02,
            "spawn_density_scaling": 0.01,
            "live_tuning_points": -1,
            "subsystem_overlap": -0.01,
            "complexity_cost": -0.01,
        },
        {
            "rollback_window_minutes": -1,
            "rollback_isolation": 0.04,
            "save_batch_seconds": -1,
            "event_ordering_buffer_ms": -2,
            "boss_reward_cadence": -0.02,
            "live_tuning_points": -1,
            "subsystem_overlap": -0.01,
            "complexity_cost": -0.01,
        },
    ],
    "economy_control_strength": [
        {"market_tax_rate": 0.003, "potion_sink_pressure": 0.01, "rare_drop_control": 0.02},
        {"upgrade_cost_curve": 0.03, "boss_reward_cadence": -0.02, "economy_owner_depth": 0.02},
    ],
    "routing_topology_clarity": [
        {"field_instance_player_cap": -1, "congestion_routing_threshold": -0.02, "routing_owner_depth": 0.03},
        {"spawn_density_scaling": -0.01, "social_density_support": 0.02, "complexity_cost": -0.01},
    ],
    "operator_control_visibility": [
        {"live_tuning_points": 1, "operator_surface_depth": 0.03, "complexity_cost": -0.01},
        {"market_tax_rate": 0.002, "boss_reward_cadence": -0.01, "economy_owner_depth": 0.02},
    ],
    "social_density_support": [
        {"party_incentive_coefficient": 0.02, "social_density_support": 0.04, "field_instance_player_cap": -1},
        {"dungeon_entry_pressure": -0.02, "congestion_routing_threshold": -0.01, "complexity_cost": -0.01},
    ],
    "subsystem_overlap_risk": [
        {"subsystem_overlap": -0.03, "complexity_cost": -0.02, "operator_surface_depth": 0.02},
        {"subsystem_overlap": -0.02, "hidden_mutation_risk": -0.02, "live_tuning_points": 1},
    ],
    "hidden_interaction_risk": [
        {
            "hidden_mutation_risk": -0.03,
            "routing_owner_depth": 0.02,
            "economy_owner_depth": 0.02,
            "operator_surface_depth": 0.02,
            "save_batch_seconds": -1,
            "rollback_window_minutes": -1,
            "complexity_cost": -0.01,
        },
        {
            "hidden_mutation_risk": -0.02,
            "routing_owner_depth": 0.03,
            "economy_owner_depth": 0.03,
            "live_tuning_points": 1,
            "operator_surface_depth": 0.02,
            "complexity_cost": -0.01,
        },
    ],
    "complexity_penalty": [
        {
            "complexity_cost": -0.02,
            "subsystem_overlap": -0.02,
            "live_tuning_points": -1,
            "operator_surface_depth": 0.02,
        },
        {
            "complexity_cost": -0.015,
            "subsystem_overlap": -0.015,
            "field_instance_player_cap": -1,
            "congestion_routing_threshold": -0.01,
            "operator_surface_depth": 0.01,
        },
    ],
}

LEGACY_DIMENSION_MAP = {
    "world_architecture_score": "structural_clarity",
    "room_instance_topology_score": "routing_topology_clarity",
    "server_authority_score": "authority_path_integrity",
    "persistence_boundaries_score": "persistence_boundary_clarity",
    "gameplay_topology_score": "field_ladder_progression_quality",
    "economy_topology_score": "economy_source_sink_balance",
    "exploit_prevention_score": "anti_bot_anti_macro_runtime_quality",
    "performance_topology_score": "rollback_boundary_clarity",
    "liveops_architecture_score": "liveops_intervention_visibility",
    "social_density_score": "social_density_anchor_quality",
    "channel_congestion_score": "channel_congestion_routing_quality",
    "boss_cadence_score": "boss_cadence_lockout_quality",
}

POSITIVE_DIMENSIONS = [
    "structural_clarity",
    "authority_path_integrity",
    "persistence_boundary_clarity",
    "rollback_boundary_clarity",
    "economy_control_strength",
    "routing_topology_clarity",
    "operator_control_visibility",
    "social_density_support",
    "level_band_bottleneck_quality",
    "field_ladder_progression_quality",
    "solo_party_split_quality",
    "field_competition_topology",
    "social_density_anchor_quality",
    "channel_congestion_routing_quality",
    "economy_source_sink_balance",
    "meso_velocity_control",
    "consumable_burn_pressure",
    "rare_supply_throttling",
    "boss_cadence_lockout_quality",
    "save_transaction_boundary_clarity",
    "server_authority_event_ordering",
    "anti_bot_anti_macro_runtime_quality",
    "liveops_intervention_visibility",
    "power_curve_replacement_pressure",
    "telemetry_feedback_visibility",
]

NEGATIVE_DIMENSIONS = {
    "hidden_interaction_risk": lambda value: 100.0 - value,
    "subsystem_overlap_risk": lambda value: 100.0 - value,
    "complexity_penalty": lambda value: 100.0 - value,
}

ACTIONABLE_MARGIN_POINTS = 6.0


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def read_json(path: Path, default):
    if not path.exists():
        return default
    return json.loads(path.read_text(encoding="utf-8"))


def write_text_if_changed(path: Path, text: str) -> None:
    ensure_dir(path.parent)
    current = path.read_text(encoding="utf-8") if path.exists() else None
    if current != text:
        path.write_text(text, encoding="utf-8")


def write_json_if_changed(path: Path, data) -> None:
    write_text_if_changed(path, json.dumps(data, ensure_ascii=True, indent=2) + "\n")


def append_jsonl(path: Path, payload: dict[str, object]) -> None:
    ensure_dir(path.parent)
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(payload, ensure_ascii=True) + "\n")


def clamp(value: float, lower: float = 0.0, upper: float = 1.0) -> float:
    return max(lower, min(upper, value))


def closeness(actual: float, target: float, tolerance: float) -> float:
    return clamp(1.0 - abs(actual - target) / max(0.0001, tolerance))


def average(values: list[float]) -> float:
    return sum(values) / len(values) if values else 0.0


def rounded(value: float) -> float:
    return round(value, 4)


def normalize_dimension_name(name: str) -> str:
    if name in DIMENSION_MUTATIONS:
        return name
    if name in ("hidden_interaction_risk", "subsystem_overlap_risk", "complexity_penalty"):
        return name
    return LEGACY_DIMENSION_MAP.get(name, "field_ladder_progression_quality")


def ensure_layout() -> None:
    ensure_dir(OPS_STATE_DIR)
    ensure_dir(ARCHITECTURE_CANDIDATES_DIR)
    ensure_dir(ARCHITECTURE_SELECTED_DIR)
    ensure_dir(SIMULATION_DIR)
    ensure_dir(CONSTRAINTS_DIR)


def read_csv_rows(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    with path.open("r", encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle))


def mean_field(rows: list[dict[str, str]], field: str) -> float:
    values = [float(row[field]) for row in rows if row.get(field)]
    return average(values)


def share(rows: list[dict[str, str]], predicate) -> float:
    if not rows:
        return 0.0
    return sum(1 for row in rows if predicate(row)) / len(rows)


def load_balance_profile() -> dict[str, float]:
    zone_rows = read_csv_rows(ZONE_LADDER_PATH)
    party_rows = read_csv_rows(PARTY_WINDOWS_PATH)
    sink_rows = read_csv_rows(SINKS_PATH)
    boss_rows = read_csv_rows(BOSS_REWARDS_PATH)

    contested_mean = mean_field(zone_rows, "contested_pressure")
    solo_mean = mean_field(zone_rows, "solo_efficiency")
    party_mean = mean_field(zone_rows, "party_efficiency")
    dead_zone_share = share(zone_rows, lambda row: float(row["solo_efficiency"]) < 0.78)
    high_contest_share = share(zone_rows, lambda row: float(row["contested_pressure"]) >= 1.2)

    party_bonus_mean = mean_field(party_rows, "party_bonus")
    solo_pressure_mean = mean_field(party_rows, "solo_pressure")
    party_peak_share = share(party_rows, lambda row: float(row["party_bonus"]) >= 1.22)

    sink_weight_mean = mean_field(sink_rows, "sink_weight")
    repair_sink_mean = average(
        [float(row["sink_weight"]) for row in sink_rows if row.get("sink_type") == "repair_bill"]
    )
    market_sink_mean = average(
        [float(row["sink_weight"]) for row in sink_rows if row.get("sink_type") in ("market_listing_fee", "market_tax")]
    )
    boss_entry_sink_mean = average(
        [float(row["sink_weight"]) for row in sink_rows if row.get("sink_type") == "boss_entry_ticket"]
    )

    reward_per_member_mean = average(
        [float(row["reward_currency"]) / max(1.0, float(row["party_size"])) for row in boss_rows]
    )
    reward_bonus_mean = mean_field(boss_rows, "reward_drop_bonus")
    double_limit_share = share(boss_rows, lambda row: float(row["weekly_limit"]) >= 2.0)

    return {
        "zone_count": float(len(zone_rows)),
        "party_window_count": float(len(party_rows)),
        "sink_count": float(len(sink_rows)),
        "boss_count": float(len(boss_rows)),
        "contested_mean": rounded(contested_mean),
        "solo_mean": rounded(solo_mean),
        "party_mean": rounded(party_mean),
        "dead_zone_share": rounded(dead_zone_share),
        "high_contest_share": rounded(high_contest_share),
        "party_bonus_mean": rounded(party_bonus_mean),
        "solo_pressure_mean": rounded(solo_pressure_mean),
        "party_peak_share": rounded(party_peak_share),
        "sink_weight_mean": rounded(sink_weight_mean),
        "repair_sink_mean": rounded(repair_sink_mean),
        "market_sink_mean": rounded(market_sink_mean),
        "boss_entry_sink_mean": rounded(boss_entry_sink_mean),
        "reward_per_member_mean": rounded(reward_per_member_mean),
        "reward_bonus_mean": rounded(reward_bonus_mean),
        "double_limit_share": rounded(double_limit_share),
    }


def active_baseline_parameters() -> dict[str, float]:
    payload = read_json(ARCHITECTURE_SELECTED_DIR / "active_architecture.json", {})
    params = payload.get("variant", {}).get("control_parameters") or payload.get("control_parameters") or {}
    baseline = dict(BASELINE_PARAMETERS)
    for key, value in params.items():
        if key in baseline and isinstance(value, (int, float)):
            baseline[key] = float(value)
    return baseline


def make_variant(variant_id: str, parameters: dict[str, float], source: str, weakest_dimension: str) -> dict[str, object]:
    return {
        "variant_id": variant_id,
        "source": source,
        "weakest_dimension_target": weakest_dimension,
        "runtime_constraints": {
            "platform": "maplestory_worlds",
            "external_backend": False,
            "server_authoritative": True,
        },
        "control_parameters": parameters,
    }


def mutate_parameters(base: dict[str, float], delta: dict[str, float]) -> dict[str, float]:
    params = dict(base)
    for key, change in delta.items():
        params[key] = rounded(float(params.get(key, 0.0)) + float(change))
    params["field_instance_player_cap"] = int(max(24, min(40, round(params["field_instance_player_cap"]))))
    params["live_tuning_points"] = int(max(6, min(14, round(params["live_tuning_points"]))))
    params["save_batch_seconds"] = int(max(3, min(8, round(params["save_batch_seconds"]))))
    params["rollback_window_minutes"] = int(max(8, min(16, round(params["rollback_window_minutes"]))))
    params["event_ordering_buffer_ms"] = int(max(80, min(160, round(params["event_ordering_buffer_ms"]))))
    return params


def weakest_dimension_from_scores(scores: dict[str, float]) -> str:
    positive_scores = {name: float(scores[name]) for name in POSITIVE_DIMENSIONS if name in scores}
    normalized = dict(positive_scores)
    for name, transform in NEGATIVE_DIMENSIONS.items():
        if name in scores:
            normalized[name] = transform(float(scores[name]))
    weakest = min(normalized, key=normalized.get)
    if weakest in NEGATIVE_DIMENSIONS and positive_scores:
        weakest_positive = min(positive_scores, key=positive_scores.get)
        if positive_scores[weakest_positive] <= normalized[weakest] + ACTIONABLE_MARGIN_POINTS:
            return weakest_positive
    return weakest


def parameter_closeness(params: dict[str, float], name: str) -> float:
    target, tolerance = TARGET_PARAMETER_PROFILES[name]
    return closeness(float(params[name]), target, tolerance)


def build_balanced_control_variant(baseline: dict[str, float], weakest_dimension: str) -> dict[str, object]:
    live_tuning_delta = -1 if baseline.get("live_tuning_points", BASELINE_PARAMETERS["live_tuning_points"]) > 10 else 0
    return make_variant(
        "balanced_control",
        mutate_parameters(
            baseline,
            {
                "field_instance_player_cap": -1,
                "congestion_routing_threshold": -0.01,
                "party_incentive_coefficient": 0.01,
                "potion_sink_pressure": 0.01,
                "upgrade_cost_curve": 0.02,
                "market_tax_rate": 0.002,
                "boss_reward_cadence": -0.02,
                "rare_drop_control": 0.02,
                "live_tuning_points": live_tuning_delta,
                "operator_surface_depth": 0.02,
                "social_density_support": 0.02,
                "complexity_cost": -0.01,
            },
        ),
        "bounded_exploration",
        weakest_dimension,
    )


def build_low_complexity_field_variant(baseline: dict[str, float], weakest_dimension: str) -> dict[str, object]:
    return make_variant(
        "low_complexity_field_control",
        mutate_parameters(
            baseline,
            {
                "field_instance_player_cap": -1,
                "congestion_routing_threshold": -0.01,
                "party_incentive_coefficient": -0.01,
                "potion_sink_pressure": 0.008,
                "upgrade_cost_curve": 0.02,
                "market_tax_rate": 0.001,
                "boss_reward_cadence": -0.02,
                "rare_drop_control": 0.02,
                "live_tuning_points": -1,
                "operator_surface_depth": 0.02,
                "subsystem_overlap": -0.015,
                "complexity_cost": -0.02,
                "social_density_support": 0.02,
            },
        ),
        "bounded_exploration",
        weakest_dimension,
    )


def generate_architecture_variants(weakest_dimension: str | None = None) -> dict[str, object]:
    ensure_layout()
    baseline = active_baseline_parameters()
    weakest = normalize_dimension_name(weakest_dimension or "field_ladder_progression_quality")
    variants = [make_variant("baseline", baseline, "current_selected", weakest)]
    mutations = DIMENSION_MUTATIONS.get(weakest, DIMENSION_MUTATIONS["field_ladder_progression_quality"])
    for index, delta in enumerate(mutations[:2], start=1):
        variants.append(
            make_variant(
                f"{weakest}_repair_{index}",
                mutate_parameters(baseline, delta),
                "weakest_dimension_repair",
                weakest,
            )
        )
    variants.append(build_balanced_control_variant(baseline, weakest))
    if weakest == "complexity_penalty":
        variants.append(build_low_complexity_field_variant(baseline, weakest))
    manifest = {"variant_count": len(variants), "variants": [variant["variant_id"] for variant in variants]}
    for variant in variants:
        write_json_if_changed(ARCHITECTURE_CANDIDATES_DIR / f"{variant['variant_id']}.json", variant)
    write_json_if_changed(ARCHITECTURE_CANDIDATES_DIR / "manifest.json", manifest)
    append_jsonl(ARCHITECTURE_REVIEW_LOG_PATH, {"stage": "variant_generation", "weakest_dimension": weakest, **manifest})
    return {"weakest_dimension": weakest, "variants": variants, "variant_count": len(variants)}


def load_candidate_variants() -> list[dict[str, object]]:
    manifest = read_json(ARCHITECTURE_CANDIDATES_DIR / "manifest.json", {"variants": []})
    return [
        read_json(ARCHITECTURE_CANDIDATES_DIR / f"{variant_id}.json", {})
        for variant_id in manifest.get("variants", [])
    ]


def simulate_player_behavior(variant: dict[str, object], agents: int = AGENT_COUNT) -> dict[str, object]:
    params = variant["control_parameters"]
    profile = load_balance_profile()

    modes = {
        "solo_grind": 0.3,
        "party_grind": 0.22,
        "boss_hunt": 0.08,
        "market_trade": 0.1,
        "map_migration": 0.16,
        "potion_consumption": 0.14,
    }
    agent_mix = {}
    assigned = 0
    for mode, ratio in modes.items():
        count = int(agents * ratio)
        agent_mix[mode] = count
        assigned += count
    agent_mix["solo_grind"] += agents - assigned

    exp_hour_pressure = rounded(
        average(
            [
                closeness(params["spawn_density_scaling"], 1.01, 0.06),
                closeness(params["dungeon_entry_pressure"], 0.58, 0.08),
                closeness(profile["dead_zone_share"], 0.03, 0.08),
            ]
        )
    )
    meso_hour_pressure = rounded(
        average(
            [
                closeness(params["market_tax_rate"] + params["potion_sink_pressure"], 0.335, 0.06),
                closeness(params["upgrade_cost_curve"] + (params["rare_drop_control"] * 0.3), 1.26, 0.12),
                closeness(profile["sink_weight_mean"], 1.42, 0.3),
            ]
        )
    )
    potion_burn = rounded(
        average(
            [
                closeness(params["potion_sink_pressure"], 0.245, 0.04),
                closeness(profile["repair_sink_mean"], 1.5, 0.4),
                closeness(profile["solo_pressure_mean"], 1.08, 0.12),
            ]
        )
    )
    map_density_distribution = rounded(
        average(
            [
                closeness(params["field_instance_player_cap"], 30.0, 5.0),
                closeness(params["congestion_routing_threshold"], 0.75, 0.05),
                closeness(profile["contested_mean"] * params["social_density_support"], 0.95, 0.16),
            ]
        )
    )
    party_formation = rounded(
        average(
            [
                closeness(params["party_incentive_coefficient"], max(1.12, profile["party_bonus_mean"] - 0.01), 0.08),
                closeness(params["social_density_support"], 0.9, 0.08),
                closeness(profile["party_peak_share"], 0.28, 0.18),
            ]
        )
    )
    congestion_profile = rounded(
        average(
            [
                closeness(params["field_instance_player_cap"], 29.0, 5.0),
                closeness(params["congestion_routing_threshold"], 0.74, 0.05),
                closeness(profile["high_contest_share"], 0.42, 0.2),
            ]
        )
    )
    item_replacement_pacing = rounded(
        average(
            [
                closeness(params["upgrade_cost_curve"], 1.04, 0.08),
                closeness(params["rare_drop_control"], 0.84, 0.06),
                closeness(profile["reward_bonus_mean"], 1.42, 0.28),
            ]
        )
    )
    boss_reward_distortion = rounded(
        average(
            [
                closeness(params["boss_reward_cadence"], 0.63, 0.08),
                closeness(profile["double_limit_share"], 0.62, 0.16),
                closeness(profile["reward_per_member_mean"] * params["boss_reward_cadence"], 940.0, 240.0),
            ]
        )
    )
    market_turnover_pressure = rounded(
        average(
            [
                closeness(params["market_tax_rate"], 0.094, 0.012),
                closeness(profile["market_sink_mean"], 1.38, 0.35),
                closeness(params["rare_drop_control"], 0.83, 0.06),
            ]
        )
    )
    level_band_transition_pressure = rounded(
        average(
            [
                closeness(profile["dead_zone_share"], 0.03, 0.08),
                closeness(params["spawn_density_scaling"], 1.0, 0.06),
                closeness(params["dungeon_entry_pressure"], 0.57, 0.08),
            ]
        )
    )
    field_competition_pressure = rounded(
        average(
            [
                closeness(profile["contested_mean"], 1.1, 0.18),
                closeness(params["field_instance_player_cap"], 30.0, 5.0),
                closeness(params["congestion_routing_threshold"], 0.75, 0.05),
            ]
        )
    )
    anti_bot_signal_quality = rounded(
        average(
            [
                closeness(params["authority_entrypoints"], 1.06, 0.08),
                closeness(params["hidden_mutation_risk"], 0.06, 0.05),
                closeness(params["operator_surface_depth"], 0.92, 0.08),
            ]
        )
    )
    liveops_visibility = rounded(
        average(
            [
                closeness(params["live_tuning_points"], 9.0, 2.5),
                closeness(params["operator_surface_depth"], 0.92, 0.08),
                closeness(params["economy_owner_depth"], 1.0, 0.08),
            ]
        )
    )
    interaction_traceability = rounded(
        average(
            [
                closeness(params["routing_owner_depth"], 1.03, 0.08),
                closeness(params["economy_owner_depth"], 1.03, 0.08),
                closeness(params["operator_surface_depth"], 0.94, 0.08),
                closeness(params["save_batch_seconds"], 4.0, 1.0),
                closeness(params["rollback_window_minutes"], 11.0, 2.0),
            ]
        )
    )
    control_surface_efficiency = rounded(
        average(
            [
                parameter_closeness(params, "live_tuning_points"),
                parameter_closeness(params, "operator_surface_depth"),
                parameter_closeness(params, "subsystem_overlap"),
                parameter_closeness(params, "complexity_cost"),
                closeness(params["routing_owner_depth"] + params["economy_owner_depth"], 2.02, 0.12),
            ]
        )
    )
    reward_sink_coherence = rounded(
        average(
            [
                closeness(profile["sink_weight_mean"], 1.42, 0.22),
                closeness(profile["market_sink_mean"], 1.34, 0.22),
                closeness(profile["boss_entry_sink_mean"], 1.46, 0.24),
                boss_reward_distortion,
            ]
        )
    )

    output = {
        "variant_id": variant["variant_id"],
        "agent_count": agents,
        "behavior_modes": agent_mix,
        "balance_profile": profile,
        "metrics": {
            "exp_hour_pressure": exp_hour_pressure,
            "meso_hour_pressure": meso_hour_pressure,
            "potion_burn": potion_burn,
            "map_density_distribution": map_density_distribution,
            "party_formation": party_formation,
            "congestion_profile": congestion_profile,
            "item_replacement_pacing": item_replacement_pacing,
            "boss_reward_distortion": boss_reward_distortion,
            "market_turnover_pressure": market_turnover_pressure,
            "level_band_transition_pressure": level_band_transition_pressure,
            "field_competition_pressure": field_competition_pressure,
            "anti_bot_signal_quality": anti_bot_signal_quality,
            "liveops_visibility": liveops_visibility,
            "interaction_traceability": interaction_traceability,
            "control_surface_efficiency": control_surface_efficiency,
            "reward_sink_coherence": reward_sink_coherence,
        },
    }
    write_json_if_changed(SIMULATION_DIR / f"{variant['variant_id']}.json", output)
    append_jsonl(ARCHITECTURE_REVIEW_LOG_PATH, {"stage": "simulation", **output})
    return output


def solve_constraints(variant: dict[str, object], simulation: dict[str, object]) -> dict[str, object]:
    params = variant["control_parameters"]
    metrics = simulation["metrics"]
    violations = []
    if params["field_instance_player_cap"] > 36:
        violations.append("instance_cap_too_wide")
    if params["rollback_window_minutes"] > 14:
        violations.append("rollback_window_too_wide")
    if params["save_batch_seconds"] > 6:
        violations.append("save_batch_too_slow")
    if params["market_tax_rate"] < 0.088:
        violations.append("market_tax_too_low")
    if params["boss_reward_cadence"] > 0.71:
        violations.append("boss_rewards_too_frequent")
    if params["rare_drop_control"] < 0.8:
        violations.append("rare_supply_too_loose")
    if params["authority_entrypoints"] < 1.0:
        violations.append("authority_entrypath_split")
    if metrics["map_density_distribution"] < 0.72:
        violations.append("field_density_low")
    if metrics["meso_hour_pressure"] < 0.72:
        violations.append("economy_pressure_unbounded")
    if metrics["boss_reward_distortion"] < 0.68:
        violations.append("boss_distortion_high")
    if metrics["interaction_traceability"] < 0.82:
        violations.append("interaction_visibility_low")
    if metrics["control_surface_efficiency"] < 0.78:
        violations.append("control_surface_too_wide")
    if metrics["reward_sink_coherence"] < 0.75:
        violations.append("reward_sink_coherence_low")
    payload = {
        "variant_id": variant["variant_id"],
        "violations": violations,
        "stability_score": rounded(1.0 - (len(violations) / 10.0)),
        "simulation_reference": metrics,
    }
    write_json_if_changed(CONSTRAINTS_DIR / f"{variant['variant_id']}.json", payload)
    append_jsonl(ARCHITECTURE_REVIEW_LOG_PATH, {"stage": "constraints", **payload})
    return payload


def score_architecture_variant(variant: dict[str, object], *args) -> dict[str, object]:
    if len(args) == 2:
        simulation, constraints = args
    elif len(args) == 4:
        _, _, simulation, constraints = args
    else:
        raise TypeError("score_architecture_variant expects (variant, simulation, constraints) or legacy five-arg form")

    params = variant["control_parameters"]
    metrics = simulation["metrics"]
    profile = simulation.get("balance_profile") or load_balance_profile()

    structural_clarity = round(
        average(
            [
                parameter_closeness(params, "subsystem_overlap"),
                parameter_closeness(params, "complexity_cost"),
                parameter_closeness(params, "operator_surface_depth"),
                metrics["control_surface_efficiency"],
            ]
        )
        * 100.0,
        2,
    )
    authority_path_integrity = round(
        average(
            [
                closeness(params["authority_entrypoints"], 1.06, 0.08),
                closeness(params["event_ordering_buffer_ms"], 108.0, 24.0),
                closeness(params["hidden_mutation_risk"], 0.06, 0.05),
            ]
        )
        * 100.0,
        2,
    )
    persistence_boundary_clarity = round(
        average(
            [
                closeness(params["persistence_isolation"], 0.9, 0.08),
                closeness(params["save_batch_seconds"], 4.0, 1.0),
                constraints["stability_score"],
            ]
        )
        * 100.0,
        2,
    )
    rollback_boundary_clarity = round(
        average(
            [
                closeness(params["rollback_isolation"], 0.88, 0.08),
                closeness(params["rollback_window_minutes"], 11.0, 2.0),
                closeness(params["event_ordering_buffer_ms"], 108.0, 24.0),
            ]
        )
        * 100.0,
        2,
    )
    economy_control_strength = round(
        average(
            [
                closeness(params["market_tax_rate"], 0.094, 0.012),
                closeness(params["potion_sink_pressure"], 0.245, 0.04),
                closeness(params["rare_drop_control"], 0.84, 0.06),
                metrics["meso_hour_pressure"],
                metrics["reward_sink_coherence"],
            ]
        )
        * 100.0,
        2,
    )
    routing_topology_clarity = round(
        average(
            [
                closeness(params["field_instance_player_cap"], 30.0, 5.0),
                closeness(params["congestion_routing_threshold"], 0.75, 0.05),
                closeness(params["routing_owner_depth"], 1.0, 0.08),
                metrics["congestion_profile"],
            ]
        )
        * 100.0,
        2,
    )
    operator_control_visibility = round(
        average(
            [
                closeness(params["operator_surface_depth"], 0.92, 0.08),
                closeness(params["live_tuning_points"], 9.0, 2.5),
                metrics["liveops_visibility"],
                metrics["control_surface_efficiency"],
            ]
        )
        * 100.0,
        2,
    )
    social_density_support = round(
        average(
            [
                closeness(params["social_density_support"], 0.9, 0.08),
                metrics["party_formation"],
                metrics["map_density_distribution"],
            ]
        )
        * 100.0,
        2,
    )
    level_band_bottleneck_quality = round(
        average(
            [
                metrics["level_band_transition_pressure"],
                closeness(profile["dead_zone_share"], 0.03, 0.08),
                closeness(params["dungeon_entry_pressure"], 0.57, 0.08),
            ]
        )
        * 100.0,
        2,
    )
    field_ladder_progression_quality = round(
        average(
            [
                metrics["map_density_distribution"],
                metrics["field_competition_pressure"],
                closeness(profile["contested_mean"], 1.1, 0.18),
            ]
        )
        * 100.0,
        2,
    )
    solo_party_split_quality = round(
        average(
            [
                metrics["party_formation"],
                closeness(params["party_incentive_coefficient"], profile["party_bonus_mean"], 0.08),
                closeness(profile["solo_pressure_mean"], 1.08, 0.12),
            ]
        )
        * 100.0,
        2,
    )
    field_competition_topology = round(
        average(
            [
                metrics["field_competition_pressure"],
                closeness(profile["high_contest_share"], 0.42, 0.2),
                closeness(params["field_instance_player_cap"], 29.0, 5.0),
            ]
        )
        * 100.0,
        2,
    )
    social_density_anchor_quality = round(
        average(
            [
                closeness(params["social_density_support"], 0.9, 0.08),
                closeness(params["party_incentive_coefficient"], max(1.12, profile["party_bonus_mean"]), 0.08),
                closeness(metrics["market_turnover_pressure"], 0.9, 0.2),
            ]
        )
        * 100.0,
        2,
    )
    channel_congestion_routing_quality = round(
        average(
            [
                metrics["congestion_profile"],
                closeness(params["congestion_routing_threshold"], 0.75, 0.05),
                closeness(params["routing_owner_depth"], 1.0, 0.08),
            ]
        )
        * 100.0,
        2,
    )
    economy_source_sink_balance = round(
        average(
            [
                metrics["meso_hour_pressure"],
                closeness(profile["sink_weight_mean"], 1.42, 0.3),
                closeness(profile["boss_entry_sink_mean"], 1.52, 0.35),
                metrics["reward_sink_coherence"],
            ]
        )
        * 100.0,
        2,
    )
    meso_velocity_control = round(
        average(
            [
                metrics["meso_hour_pressure"],
                metrics["market_turnover_pressure"],
                closeness(params["market_tax_rate"], 0.094, 0.012),
            ]
        )
        * 100.0,
        2,
    )
    consumable_burn_pressure = round(
        average(
            [
                metrics["potion_burn"],
                closeness(params["potion_sink_pressure"], 0.245, 0.04),
                closeness(profile["repair_sink_mean"], 1.5, 0.4),
            ]
        )
        * 100.0,
        2,
    )
    rare_supply_throttling = round(
        average(
            [
                closeness(params["rare_drop_control"], 0.84, 0.06),
                closeness(params["upgrade_cost_curve"], 1.04, 0.08),
                metrics["market_turnover_pressure"],
            ]
        )
        * 100.0,
        2,
    )
    boss_cadence_lockout_quality = round(
        average(
            [
                metrics["boss_reward_distortion"],
                closeness(params["boss_reward_cadence"], 0.63, 0.08),
                closeness(profile["double_limit_share"], 0.62, 0.16),
            ]
        )
        * 100.0,
        2,
    )
    save_transaction_boundary_clarity = round(
        average(
            [
                persistence_boundary_clarity / 100.0,
                rollback_boundary_clarity / 100.0,
                closeness(params["save_batch_seconds"], 4.0, 1.0),
            ]
        )
        * 100.0,
        2,
    )
    server_authority_event_ordering = round(
        average(
            [
                authority_path_integrity / 100.0,
                closeness(params["event_ordering_buffer_ms"], 108.0, 24.0),
                closeness(params["routing_owner_depth"], 1.0, 0.08),
            ]
        )
        * 100.0,
        2,
    )
    anti_bot_anti_macro_runtime_quality = round(
        average(
            [
                metrics["anti_bot_signal_quality"],
                closeness(params["hidden_mutation_risk"], 0.06, 0.05),
                closeness(params["operator_surface_depth"], 0.92, 0.08),
            ]
        )
        * 100.0,
        2,
    )
    liveops_intervention_visibility = round(
        average(
            [
                metrics["liveops_visibility"],
                closeness(params["live_tuning_points"], 9.0, 2.5),
                closeness(params["operator_surface_depth"], 0.92, 0.08),
            ]
        )
        * 100.0,
        2,
    )
    power_curve_replacement_pressure = round(
        average(
            [
                metrics["item_replacement_pacing"],
                closeness(params["upgrade_cost_curve"], 1.04, 0.08),
                closeness(params["rare_drop_control"], 0.84, 0.06),
            ]
        )
        * 100.0,
        2,
    )
    telemetry_feedback_visibility = round(
        average(
            [
                closeness(params["live_tuning_points"], 9.0, 2.5),
                closeness(params["operator_surface_depth"], 0.92, 0.08),
                closeness(params["economy_owner_depth"] + params["routing_owner_depth"], 2.0, 0.15),
                metrics["control_surface_efficiency"],
            ]
        )
        * 100.0,
        2,
    )

    hidden_interaction_risk = round(
        average(
            [
                1.0 - metrics["interaction_traceability"],
                clamp(params["hidden_mutation_risk"] / 0.24),
                clamp(params["subsystem_overlap"] / 0.24),
                clamp(abs(2.06 - (params["routing_owner_depth"] + params["economy_owner_depth"])) / 0.18),
            ]
        )
        * 100.0,
        2,
    )
    subsystem_overlap_risk = round(clamp(params["subsystem_overlap"] / 0.36) * 100.0, 2)
    complexity_penalty = round(
        average(
            [
                clamp(params["complexity_cost"] / 0.22),
                clamp(params["subsystem_overlap"] / 0.18),
                clamp(abs(params["live_tuning_points"] - 9.0) / 4.0),
                clamp(abs(2.02 - (params["routing_owner_depth"] + params["economy_owner_depth"])) / 0.12),
                1.0 - metrics["control_surface_efficiency"],
            ]
        )
        * 100.0,
        2,
    )

    mapleland_similarity_score = round(
        average(
            [
                level_band_bottleneck_quality,
                field_ladder_progression_quality,
                field_competition_topology,
                social_density_anchor_quality,
                meso_velocity_control,
                consumable_burn_pressure,
                rare_supply_throttling,
                boss_cadence_lockout_quality,
                power_curve_replacement_pressure,
                liveops_intervention_visibility,
            ]
        ),
        2,
    )

    architecture_score = round(
        (
            structural_clarity
            + authority_path_integrity
            + economy_control_strength
            + social_density_support
            + field_ladder_progression_quality
            + meso_velocity_control
            + consumable_burn_pressure
            + power_curve_replacement_pressure
            + mapleland_similarity_score
            - complexity_penalty
        )
        / 9.0,
        2,
    )
    overall_architecture_quality = round(
        average(
            [
                architecture_score,
                level_band_bottleneck_quality,
                boss_cadence_lockout_quality,
                liveops_intervention_visibility,
                server_authority_event_ordering,
            ]
        ),
        2,
    )

    scores = {
        "variant_id": variant["variant_id"],
        "structural_clarity": structural_clarity,
        "authority_path_integrity": authority_path_integrity,
        "persistence_boundary_clarity": persistence_boundary_clarity,
        "rollback_boundary_clarity": rollback_boundary_clarity,
        "economy_control_strength": economy_control_strength,
        "routing_topology_clarity": routing_topology_clarity,
        "operator_control_visibility": operator_control_visibility,
        "social_density_support": social_density_support,
        "level_band_bottleneck_quality": level_band_bottleneck_quality,
        "field_ladder_progression_quality": field_ladder_progression_quality,
        "solo_party_split_quality": solo_party_split_quality,
        "field_competition_topology": field_competition_topology,
        "social_density_anchor_quality": social_density_anchor_quality,
        "channel_congestion_routing_quality": channel_congestion_routing_quality,
        "economy_source_sink_balance": economy_source_sink_balance,
        "meso_velocity_control": meso_velocity_control,
        "consumable_burn_pressure": consumable_burn_pressure,
        "rare_supply_throttling": rare_supply_throttling,
        "boss_cadence_lockout_quality": boss_cadence_lockout_quality,
        "save_transaction_boundary_clarity": save_transaction_boundary_clarity,
        "server_authority_event_ordering": server_authority_event_ordering,
        "anti_bot_anti_macro_runtime_quality": anti_bot_anti_macro_runtime_quality,
        "liveops_intervention_visibility": liveops_intervention_visibility,
        "power_curve_replacement_pressure": power_curve_replacement_pressure,
        "telemetry_feedback_visibility": telemetry_feedback_visibility,
        "mapleland_similarity_score": mapleland_similarity_score,
        "hidden_interaction_risk": hidden_interaction_risk,
        "subsystem_overlap_risk": subsystem_overlap_risk,
        "complexity_penalty": complexity_penalty,
        "architecture_score": architecture_score,
        "overall_architecture_quality": overall_architecture_quality,
    }
    scores["weakest_dimension"] = weakest_dimension_from_scores(scores)
    scores["world_architecture_score"] = structural_clarity
    scores["room_instance_topology_score"] = routing_topology_clarity
    scores["server_authority_score"] = authority_path_integrity
    scores["persistence_boundaries_score"] = persistence_boundary_clarity
    scores["gameplay_topology_score"] = field_ladder_progression_quality
    scores["economy_topology_score"] = economy_source_sink_balance
    scores["exploit_prevention_score"] = anti_bot_anti_macro_runtime_quality
    scores["performance_topology_score"] = rollback_boundary_clarity
    scores["liveops_architecture_score"] = liveops_intervention_visibility
    scores["social_density_score"] = social_density_anchor_quality
    scores["channel_congestion_score"] = channel_congestion_routing_quality
    scores["boss_cadence_score"] = boss_cadence_lockout_quality
    scores["long_term_operation_score"] = round(
        average(
            [
                liveops_intervention_visibility,
                telemetry_feedback_visibility,
                economy_control_strength,
                save_transaction_boundary_clarity,
            ]
        ),
        2,
    )
    return scores


def critique_architecture(variant: dict[str, object]) -> dict[str, object]:
    simulation = simulate_player_behavior(variant)
    constraints = solve_constraints(variant, simulation)
    scores = score_architecture_variant(variant, simulation, constraints)
    low_dimensions = [name for name in POSITIVE_DIMENSIONS if scores[name] < 80.0]
    return {
        "variant_id": variant["variant_id"],
        "weakest_dimension": scores["weakest_dimension"],
        "issues": low_dimensions[:5],
        "stability_score": constraints["stability_score"],
    }


def adversarial_test_architecture(variant: dict[str, object]) -> dict[str, object]:
    params = variant["control_parameters"]
    issues = []
    if params["boss_reward_cadence"] >= 0.71:
        issues.append("boss_loop_can_bypass_fields")
    if params["field_instance_player_cap"] >= 35:
        issues.append("field_competition_dilution_risk")
    if params["market_tax_rate"] <= 0.09:
        issues.append("meso_velocity_overrun_risk")
    if params["rare_drop_control"] <= 0.8:
        issues.append("replacement_pressure_collapse_risk")
    return {
        "variant_id": variant["variant_id"],
        "issues": issues,
        "risk_score": round(min(100.0, len(issues) * 25.0), 2),
    }


def mutate_architecture(
    variant: dict[str, object],
    critique: dict[str, object],
    adversarial: dict[str, object],
    constraints: dict[str, object],
) -> dict[str, object]:
    del adversarial, constraints
    target = normalize_dimension_name(str(critique.get("weakest_dimension") or variant.get("weakest_dimension_target") or "field_ladder_progression_quality"))
    mutation = DIMENSION_MUTATIONS.get(target, DIMENSION_MUTATIONS["field_ladder_progression_quality"])[0]
    return make_variant(
        f"{variant['variant_id']}_m01",
        mutate_parameters(variant["control_parameters"], mutation),
        "legacy_mutation_compat",
        target,
    )


def select_best_architecture(scored_variants: list[dict[str, object]]) -> dict[str, object]:
    best = max(
        scored_variants,
        key=lambda entry: (
            entry["scores"]["architecture_score"],
            entry["scores"]["mapleland_similarity_score"],
            entry["constraints"]["stability_score"],
            -entry["scores"]["complexity_penalty"],
            entry["scores"]["overall_architecture_quality"],
        ),
    )
    payload = {
        "variant_id": best["variant"]["variant_id"],
        "variant": best["variant"],
        "simulation": best["simulation"],
        "constraints": best["constraints"],
        "scores": best["scores"],
    }
    write_json_if_changed(ARCHITECTURE_SELECTED_DIR / "active_architecture.json", payload)
    append_jsonl(ARCHITECTURE_REVIEW_LOG_PATH, {"stage": "selection", "selected_variant_id": payload["variant_id"], "scores": payload["scores"]})
    return payload


def update_architecture_state(selected: dict[str, object]) -> dict[str, object]:
    payload = {
        "targets": TARGETS,
        "selected_variant_id": selected["variant_id"],
        "latest": selected["scores"],
        "simulation": selected["simulation"],
        "constraints": selected["constraints"],
    }
    write_json_if_changed(ARCHITECTURE_SCORES_PATH, payload)

    eval_scores = read_json(EVAL_SCORES_PATH, {})
    eval_scores["architecture"] = payload
    write_json_if_changed(EVAL_SCORES_PATH, eval_scores)

    progress = read_json(PROGRESS_PATH, {})
    progress["selected_architecture_variant"] = selected["variant_id"]
    progress["architecture_candidates"] = len(load_candidate_variants())
    progress["architecture_last_status"] = "bounded_phase2_cycle_complete"
    progress["architecture_project_complete"] = all(
        selected["scores"].get(key, 0.0) >= value for key, value in TARGETS.items()
    )
    for key, value in selected["scores"].items():
        progress[key] = value
    write_json_if_changed(PROGRESS_PATH, progress)
    return progress


def score_selected_architecture() -> dict[str, object]:
    payload = read_json(ARCHITECTURE_SELECTED_DIR / "active_architecture.json", {})
    if not payload:
        return {}
    return update_architecture_state(payload)


def inspect_baseline() -> dict[str, object]:
    baseline = make_variant("baseline", active_baseline_parameters(), "current_selected", "baseline_inspection")
    simulation = simulate_player_behavior(baseline, AGENT_COUNT)
    constraints = solve_constraints(baseline, simulation)
    scores = score_architecture_variant(baseline, simulation, constraints)
    return {
        "variant": baseline,
        "simulation": simulation,
        "constraints": constraints,
        "scores": scores,
    }


def run_architecture_cycle() -> dict[str, object]:
    ensure_layout()
    baseline_review = inspect_baseline()
    generated = generate_architecture_variants(baseline_review["scores"]["weakest_dimension"])
    evaluated = []
    for variant in generated["variants"]:
        if variant["variant_id"] == "baseline":
            continue
        critique = critique_architecture(variant)
        adversarial = adversarial_test_architecture(variant)
        simulation = simulate_player_behavior(variant, AGENT_COUNT)
        constraints = solve_constraints(variant, simulation)
        scores = score_architecture_variant(variant, critique, adversarial, simulation, constraints)
        evaluated.append(
            {
                "variant": variant,
                "critique": critique,
                "adversarial": adversarial,
                "simulation": simulation,
                "constraints": constraints,
                "scores": scores,
            }
        )
    selected = select_best_architecture(evaluated)
    progress = update_architecture_state(selected)
    summary = {
        "cycle_type": "phase2_bounded",
        "baseline_review": {
            "variant_id": baseline_review["variant"]["variant_id"],
            "weakest_dimension": baseline_review["scores"]["weakest_dimension"],
            "scores": baseline_review["scores"],
        },
        "weakest_dimension": generated["weakest_dimension"],
        "selected_variant_id": selected["variant_id"],
        "evaluated_variant_count": len(evaluated),
        "scores": selected["scores"],
        "progress": progress,
    }
    write_json_if_changed(ARCHITECTURE_SELECTED_DIR / "last_cycle_summary.json", summary)
    append_jsonl(ARCHITECTURE_REVIEW_LOG_PATH, {"stage": "phase2_cycle", **summary})
    return summary


def run_architecture_supervisor(max_cycles: int = 1) -> dict[str, object]:
    del max_cycles
    summary = run_architecture_cycle()
    return {"status": "bounded_phase2_cycle_complete", **summary}


if __name__ == "__main__":
    print(json.dumps(run_architecture_cycle(), ensure_ascii=True, indent=2))
