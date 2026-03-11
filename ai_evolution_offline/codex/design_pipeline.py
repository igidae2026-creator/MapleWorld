#!/usr/bin/env python3

from __future__ import annotations

import csv
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DESIGN_GRAPH_DIR = ROOT / "data" / "design_graph"
DESIGN_SCHEMA_DIR = ROOT / "data" / "design_schema"
BALANCE_DIR = ROOT / "data" / "balance"
LIVEOPS_DIR = ROOT / "data" / "liveops"
EXPANSIONS_DIR = ROOT / "data" / "expansions"
TMP_DIR = ROOT / "data" / "tmp"
OPS_STATE_DIR = ROOT / "ops" / "codex_state"
DESIGN_STATE_DIR = ROOT / "offline_ops" / "codex_state"
PROMPTS_DIR = ROOT / "ops" / "prompts"

PROGRESS_PATH = DESIGN_STATE_DIR / "progress.json"
EVAL_SCORES_PATH = DESIGN_STATE_DIR / "eval_scores.json"
SCORE_HISTORY_PATH = DESIGN_STATE_DIR / "score_history.jsonl"
CYCLE_LOG_PATH = DESIGN_STATE_DIR / "run_log.jsonl"
CANDIDATES_DIR = DESIGN_STATE_DIR / "candidates"
RUNS_DIR = DESIGN_STATE_DIR / "runs"
PLAYER_EXPERIENCE_METRICS_PATH = ROOT / "offline_ops" / "codex_state" / "simulation_runs" / "player_experience_metrics_latest.json"

GENERATED_CANDIDATES_PATH = TMP_DIR / "generated_candidates.json"
GENERATED_SCHEMA_PATH = TMP_DIR / "generated_schema.json"
GENERATED_BALANCE_PATH = TMP_DIR / "generated_balance.json"
GENERATED_LIVEOPS_PATH = TMP_DIR / "generated_liveops.json"
GENERATED_EXPANSIONS_PATH = TMP_DIR / "generated_expansions.json"

DOMAINS = [
    "progression",
    "combat",
    "monsters",
    "fields",
    "spawning",
    "drops",
    "items",
    "equipment",
    "economy",
    "currency",
    "trading",
    "party",
    "guild",
    "boss",
    "dungeons",
    "quests",
    "events",
    "liveops",
    "security",
    "performance",
    "persistence",
    "ai",
    "navigation",
]

TARGETS = {
    "design_nodes": 10000,
    "schema_items": 10000,
    "balance_rows": 20000,
    "liveops_rows": 2000,
    "expansion_assets": 5000,
}

SCORE_TARGETS = {
    "structure_pipeline_score": 100.0,
    "asset_throughput_score": 100.0,
    "live_balance_quality_score": 100.0,
    "mapleland_similarity_score": 100.0,
    "overall_efficiency_score": 120.0,
}

ROOT_CHILDREN = {
    "progression": ["level_curve", "party_windows", "boss_unlock_flow", "weekly_progress_loop", "returning_player_boost"],
    "combat": ["accuracy_formula", "potion_cooldown", "damage_variance", "burst_window", "guard_efficiency"],
    "monsters": ["family_profiles", "boss_brackets", "exp_reward_curve", "status_resistance_profile", "loot_family_binding"],
    "fields": ["zone_ladder", "map_population_limit", "crowding_alert_threshold", "party_route_bonus", "regional_identity"],
    "spawning": ["spawn_density", "rare_spawn_rate", "party_presence_scaling", "anti_camp_relocation", "kill_rate_feedback"],
    "drops": ["drop_tier_weights", "boss_reward_table", "currency_drop_curve", "repeat_kill_decay", "reroll_currency_sink"],
    "items": ["vendor_price_curve", "rarity_band", "repair_material_cost", "inventory_space_pressure", "collection_score_value"],
    "equipment": ["weapon_attack_curve", "upgrade_success_curve", "starforce_cost_curve", "boss_gear_drop_curve", "anti_inflation_upgrade_sink"],
    "economy": ["currency_sources", "currency_sinks", "auction_house_tax", "storage_fee", "liquidity_alert_threshold"],
    "currency": ["monster_drop_rate", "repair_sink", "auction_sink", "velocity_target", "hoarding_pressure"],
    "trading": ["listing_fee", "tax_rate", "price_band_guard", "seller_slot_cap", "new_player_protection"],
    "party": ["party_size_bonus", "exp_distribution", "shared_quest_credit", "daily_bonus_window", "party_synergy_curve"],
    "guild": ["member_cap", "contribution_curve", "guild_bank_sink", "guild_event_rotation", "inactivity_cleanup"],
    "boss": ["phase_count", "entry_requirement", "weekly_clear_limit", "reward_table", "liveops_override_point"],
    "dungeons": ["entry_requirement", "reward_table", "clear_time_target", "mentor_bonus", "event_overlay_rules"],
    "quests": ["reward_curve", "daily_rotation", "level_requirement", "catchup_bonus", "telemetry_marker"],
    "events": ["schedule_rotation", "reward_table", "party_bonus", "reward_sink_compensation", "telemetry_dashboard"],
    "liveops": ["drop_rate_global_modifier", "market_tax_override", "economy_brake", "rollback_checkpoint", "content_release_gate"],
    "security": ["bot_detection_threshold", "trade_velocity_limit", "duplication_guard", "shadowban_rules", "incident_response_playbook"],
    "performance": ["tick_budget", "channel_population_cap", "graceful_degradation", "load_test_target", "maintenance_mode_profile"],
    "persistence": ["save_interval", "rollback_window", "backup_frequency", "conflict_resolution", "crash_recovery_playbook"],
    "ai": ["behavior_tree_budget", "spawn_director", "boss_phase_ai", "population_feedback_loop", "simulation_seed_control"],
    "navigation": ["portal_graph", "fast_travel_network", "party_sync_route", "crowding_avoidance", "boat_schedule_routes"],
}

COMPONENT_CHILDREN = [
    "baseline",
    "early_game_curve",
    "mid_game_curve",
    "late_game_curve",
    "party_modifier",
    "solo_modifier",
    "breakpoint_table",
    "recovery_window",
    "liveops_override",
    "abuse_guardrail",
]

PARAMETER_CHILDREN = [
    "base_value",
    "min_value",
    "max_value",
    "default_value",
    "step_size",
    "level_band_table",
    "queue_pressure_scaling",
    "inflation_response",
    "alert_threshold",
    "fail_safe_rule",
]

REGIONS = [
    "southperry",
    "amherst",
    "ellinia",
    "perion",
    "henesys",
    "kerning",
    "sleepywood",
    "ludibrium",
    "orbis",
    "elnath",
    "aqua",
    "leafre",
    "magatia",
    "mu_lung",
    "zipangu",
]

FIELD_THEMES = [
    "stump_ridge",
    "mushroom_grove",
    "boar_hills",
    "drake_ravine",
    "ghost_tower",
    "toy_factory",
    "ice_valley",
    "cloud_terrace",
    "reef_shelf",
    "wyvern_nest",
]

MONSTER_FAMILIES = [
    ("snail", "Worn Shell"),
    ("mushroom", "Cap"),
    ("pig", "Tusk"),
    ("slime", "Gel"),
    ("stump", "Bark"),
    ("boar", "Hide"),
    ("drake", "Scale"),
    ("wraith", "Echo"),
    ("tauromacis", "Horn"),
    ("jr_balrog", "Wing"),
    ("spirit_viking", "Cog"),
    ("wyvern", "Claw"),
]

ITEM_CLASSES = [
    "sword",
    "axe",
    "spear",
    "bow",
    "claw",
    "wand",
    "staff",
    "overall",
    "glove",
    "shoe",
]

ITEM_MATERIALS = [
    "bronze",
    "iron",
    "steel",
    "mithril",
    "golden",
    "crystal",
    "scarlet",
    "azure",
    "shadow",
    "maple",
]

SINK_TYPES = [
    "taxi_fare",
    "repair_bill",
    "scroll_cleansing",
    "storage_rent",
    "market_listing_fee",
    "market_tax",
    "pet_feed_maintenance",
    "guild_banner_fee",
    "boss_entry_ticket",
    "alchemy_catalyst",
    "starforce_attempt",
    "socket_reset",
]

EVENT_TYPES = [
    "training_surge",
    "field_hunt_drive",
    "boss_relay",
    "crafting_week",
    "market_cooldown",
    "returner_support",
]

ROLE_DOMAIN_MAP = {
    "structure_pipeline_score": ["persistence", "performance", "liveops", "security", "navigation"],
    "asset_throughput_score": ["items", "equipment", "drops", "events", "fields"],
    "live_balance_quality_score": ["progression", "monsters", "economy", "party", "boss"],
    "mapleland_similarity_score": ["fields", "economy", "party", "boss", "drops"],
}


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def read_json(path: Path, default):
    if not path.exists():
        return default
    return json.loads(path.read_text())


def read_text_if_exists(path: Path) -> str:
    return path.read_text() if path.exists() else ""


def write_text_if_changed(path: Path, text: str) -> None:
    ensure_dir(path.parent)
    current = path.read_text() if path.exists() else None
    if current != text:
        path.write_text(text)


def write_json_if_changed(path: Path, data) -> None:
    write_text_if_changed(path, json.dumps(data, ensure_ascii=True, indent=2) + "\n")


def write_csv_if_changed(path: Path, fieldnames: list[str], rows: list[dict[str, object]]) -> None:
    ensure_dir(path.parent)
    output = []
    with_path = []
    for row in rows:
        rendered = {}
        for field in fieldnames:
            value = row[field]
            if isinstance(value, float):
                rendered[field] = f"{value:.6f}".rstrip("0").rstrip(".")
            else:
                rendered[field] = str(value)
        with_path.append(rendered)
    output.append(",".join(fieldnames))
    for row in with_path:
        output.append(",".join(row[field] for field in fieldnames))
    write_text_if_changed(path, "\n".join(output) + "\n")


def read_csv_rows(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def append_jsonl(path: Path, payload: dict[str, object]) -> None:
    ensure_dir(path.parent)
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(payload, ensure_ascii=True) + "\n")


def clamp(value: float, lower: float = 0.0, upper: float = 1.0) -> float:
    return max(lower, min(upper, value))


def ratio_score(actual: float, target: float, cap: float = 1.1) -> float:
    return clamp(actual / max(1.0, target), 0.0, cap)


def closeness_score(actual: float, target: float, tolerance: float) -> float:
    if tolerance <= 0:
        return 1.0 if actual == target else 0.0
    return clamp(1.0 - abs(actual - target) / tolerance)


def average(values: list[float]) -> float:
    return sum(values) / len(values) if values else 0.0


def seed_prompt_files() -> None:
    prompts = {
        "generator.md": """# Generator
Write candidate JSON only.
Produce MapleLand-class operational assets with concrete monsters, maps, items, sinks, party bands, boss access gates, and live-ops controls.
Never emit schema-path names as content identities.
Favor bottlenecks, contested maps, sink pressure, and weekly retention loops over smooth placeholder curves.
""",
        "critic.md": """# Critic
Reject low-quality synthetic output.
Flag schema-path identities used as monsters, items, sinks, or drops; repetitive numeric cycles; abstract meta entities; placeholder curves; and formally valid but operationally fake CSVs.
Emit deterministic rejection reasons and repair hints only.
""",
        "simulator.md": """# Simulator
Compute measurable world pressure metrics:
progression pacing drift, sink/source ratio, map congestion pressure, solo/party route pressure, boss reward inflation pressure, item replacement pressure, drop rarity compression, and power curve bottleneck structure.
Feed these metrics into persistent score state.
""",
        "supervisor.md": """# Supervisor
Read current rubric scores, detect the weakest dimension, choose repair domains, run deterministic generation and repair cycles, and continue until every score threshold is met.
Do not stop early because raw asset counts are already high.
""",
        "merger.md": """# Merger
Prepare merge plans only.
Python scripts own deterministic merge order, dedupe, validation, shard routing, score updates, and repeated-run safety.
""",
    }
    ensure_dir(PROMPTS_DIR)
    for name, content in prompts.items():
        write_text_if_changed(PROMPTS_DIR / name, content)


def seed_tmp_files() -> None:
    ensure_dir(TMP_DIR)
    write_json_if_changed(GENERATED_CANDIDATES_PATH, read_json(GENERATED_CANDIDATES_PATH, {"items": []}))
    write_json_if_changed(GENERATED_SCHEMA_PATH, read_json(GENERATED_SCHEMA_PATH, {"items": []}))
    write_json_if_changed(GENERATED_BALANCE_PATH, read_json(GENERATED_BALANCE_PATH, {}))
    write_json_if_changed(GENERATED_LIVEOPS_PATH, read_json(GENERATED_LIVEOPS_PATH, {}))
    write_json_if_changed(GENERATED_EXPANSIONS_PATH, read_json(GENERATED_EXPANSIONS_PATH, {}))


def ensure_state_layout() -> None:
    ensure_dir(OPS_STATE_DIR)
    ensure_dir(DESIGN_STATE_DIR)
    ensure_dir(CANDIDATES_DIR)
    ensure_dir(RUNS_DIR)
    seed_prompt_files()
    seed_tmp_files()
    if not EVAL_SCORES_PATH.exists():
        write_json_if_changed(EVAL_SCORES_PATH, {"targets": SCORE_TARGETS, "latest": {}})
    if not SCORE_HISTORY_PATH.exists():
        SCORE_HISTORY_PATH.touch()
    if not CYCLE_LOG_PATH.exists():
        CYCLE_LOG_PATH.touch()


def derive_domain(node_id: str) -> str:
    return node_id.split(".")[0]


def normalize_node(node: dict[str, object]) -> dict[str, object]:
    normalized = dict(node)
    node_id = str(normalized["id"])
    normalized["domain"] = derive_domain(node_id)
    normalized["layer"] = int(normalized.get("layer", len(node_id.split("."))))
    if "parent" in normalized and not normalized["parent"]:
        normalized.pop("parent")
    return normalized


def seed_root_nodes(node_map: dict[str, dict[str, object]]) -> None:
    for domain in DOMAINS:
        node_map.setdefault(domain, {"id": domain, "layer": 1, "domain": domain})


def load_graph() -> tuple[list[dict[str, object]], list[str]]:
    node_map: dict[str, dict[str, object]] = {}
    for domain in DOMAINS:
        shard = read_json(DESIGN_GRAPH_DIR / f"{domain}.json", {})
        for node in shard.get("nodes", []):
            normalized = normalize_node(node)
            node_map[str(normalized["id"])] = normalized
    if not node_map:
        legacy = read_json(DESIGN_GRAPH_DIR / "nodes.json", {"nodes": []})
        for node in legacy.get("nodes", []):
            normalized = normalize_node(node)
            node_map[str(normalized["id"])] = normalized
    seed_root_nodes(node_map)
    nodes = sorted(node_map.values(), key=lambda item: (int(item["layer"]), str(item["id"])))
    frontier = [node_id for node_id in read_json(DESIGN_GRAPH_DIR / "frontier.json", {}).get("frontier", []) if node_id in node_map]
    if not frontier:
        frontier = [domain for domain in DOMAINS if domain in node_map]
    return nodes, frontier


def save_graph(nodes: list[dict[str, object]], frontier: list[str]) -> None:
    node_map = {str(normalize_node(node)["id"]): normalize_node(node) for node in nodes}
    seed_root_nodes(node_map)
    ordered_nodes = sorted(node_map.values(), key=lambda item: (int(item["layer"]), str(item["id"])))
    valid_frontier = [node_id for node_id in dict.fromkeys(frontier) if node_id in node_map]
    ensure_dir(DESIGN_GRAPH_DIR)
    shards = []
    index = {}
    max_layer = max(int(node["layer"]) for node in ordered_nodes) if ordered_nodes else 0
    for domain in DOMAINS:
        shard_nodes = [node for node in ordered_nodes if node["domain"] == domain]
        write_json_if_changed(DESIGN_GRAPH_DIR / f"{domain}.json", {"domain": domain, "nodes": shard_nodes})
        shards.append({"domain": domain, "path": f"data/design_graph/{domain}.json", "count": len(shard_nodes)})
        for node in shard_nodes:
            index[str(node["id"])] = True
    write_json_if_changed(DESIGN_GRAPH_DIR / "frontier.json", {"frontier": valid_frontier})
    write_json_if_changed(DESIGN_GRAPH_DIR / "index.json", {"index": index})
    write_json_if_changed(DESIGN_GRAPH_DIR / "nodes.json", {"nodes": ordered_nodes})
    write_json_if_changed(
        DESIGN_GRAPH_DIR / "manifest.json",
        {
            "node_count": len(ordered_nodes),
            "frontier_count": len(valid_frontier),
            "max_layer": max_layer,
            "domains": DOMAINS,
            "shards": shards,
        },
    )


def graph_stats() -> dict[str, int]:
    manifest = read_json(DESIGN_GRAPH_DIR / "manifest.json", {})
    return {
        "node_count": int(manifest.get("node_count", 0)),
        "frontier_count": int(manifest.get("frontier_count", 0)),
        "max_layer": int(manifest.get("max_layer", 0)),
    }


def initialize_design_graph() -> dict[str, object]:
    ensure_state_layout()
    nodes, frontier = load_graph()
    save_graph(nodes, frontier)
    return graph_stats()


def load_index_map() -> dict[str, bool]:
    return read_json(DESIGN_GRAPH_DIR / "index.json", {}).get("index", {})


def graph_snapshot(frontier_limit: int | None = None) -> dict[str, object]:
    nodes, frontier = load_graph()
    if frontier_limit is not None:
        frontier = frontier[:frontier_limit]
    node_map = {str(node["id"]): node for node in nodes}
    return {
        "nodes": nodes,
        "frontier": frontier,
        "node_map": node_map,
        "index": load_index_map(),
        "progress": load_progress(),
        "graph_stats": graph_stats(),
    }


def load_progress() -> dict[str, object]:
    progress = read_json(PROGRESS_PATH, {})
    for key, value in TARGETS.items():
        progress.setdefault(f"target_{key}", value)
    for key in TARGETS:
        progress.setdefault(key, progress.get(f"{key[:-1]}_count", progress.get(f"{key}_count", 0)))
    progress.setdefault("last_run_added", 0)
    progress.setdefault("last_status", "idle")
    progress.setdefault("project_complete", False)
    progress.setdefault("weakest_dimension", "structure_pipeline_score")
    progress.setdefault("active_player_bottleneck", "first_10_minutes")
    progress.setdefault("overall_player_experience_floor", "60~62")
    progress.setdefault("first_10_minutes", "60~62")
    progress.setdefault("first_hour_retention", "60~62")
    progress.setdefault("day1_return_intent", "60~62")
    for key in SCORE_TARGETS:
        progress.setdefault(key, 0.0)
    return progress


def generate_children(node: dict[str, object]) -> list[dict[str, object]]:
    node_id = str(node["id"])
    layer = int(node["layer"])
    domain = str(node["domain"])
    if layer <= 1:
        names = ROOT_CHILDREN[domain]
    elif layer == 2:
        names = COMPONENT_CHILDREN
    else:
        names = PARAMETER_CHILDREN
    return [{"id": f"{node_id}.{name}", "layer": layer + 1, "parent": node_id, "domain": domain} for name in names]


def validate_candidate_nodes(
    candidate_nodes: list[dict[str, object]], existing_ids: dict[str, bool] | None = None
) -> tuple[list[dict[str, object]], list[dict[str, object]]]:
    existing_ids = dict(existing_ids or {})
    current_nodes, _ = load_graph()
    known_ids = {str(node["id"]) for node in current_nodes}
    accepted = []
    rejected = []
    for raw_node in candidate_nodes:
        try:
            node = normalize_node(raw_node)
            node_id = str(node["id"])
            layer = int(node["layer"])
            parent_id = str(node.get("parent", "")) if layer > 1 else ""
        except Exception:
            rejected.append({"node": raw_node, "reason": "invalid_shape"})
            continue
        if node["domain"] not in DOMAINS:
            rejected.append({"node": node, "reason": "invalid_domain"})
        elif node_id in existing_ids or node_id in known_ids:
            rejected.append({"node": node, "reason": "duplicate"})
        elif layer > 1 and not parent_id:
            rejected.append({"node": node, "reason": "missing_parent"})
        elif layer > 1 and parent_id not in known_ids and parent_id not in existing_ids:
            rejected.append({"node": node, "reason": "unknown_parent"})
        else:
            existing_ids[node_id] = True
            accepted.append(node)
    return accepted, rejected


def apply_candidate_nodes(candidate_nodes: list[dict[str, object]], frontier: list[str] | None = None) -> dict[str, int]:
    nodes, current_frontier = load_graph()
    node_map = {str(node["id"]): normalize_node(node) for node in nodes}
    accepted, _ = validate_candidate_nodes(candidate_nodes, {node_id: True for node_id in node_map})
    for node in accepted:
        node_map[str(node["id"])] = node
    save_graph(list(node_map.values()), frontier if frontier is not None else current_frontier)
    stats = graph_stats()
    stats["applied_count"] = len(accepted)
    return stats


def regenerate_frontier() -> dict[str, int]:
    nodes, _ = load_graph()
    node_ids = {str(node["id"]) for node in nodes}
    parent_ids = {str(node["parent"]) for node in nodes if "parent" in node}
    frontier = [str(node["id"]) for node in nodes if str(node["id"]) not in parent_ids] or list(DOMAINS)
    save_graph(nodes, frontier)
    return graph_stats()


def choose_emphasis_domains(limit: int = 5, weakest_dimension: str | None = None) -> list[str]:
    if weakest_dimension in ROLE_DOMAIN_MAP:
        return ROLE_DOMAIN_MAP[weakest_dimension][:limit]
    manifest = read_json(DESIGN_GRAPH_DIR / "manifest.json", {})
    shard_counts = {entry.get("domain"): int(entry.get("count", 0)) for entry in manifest.get("shards", [])}
    return sorted(DOMAINS, key=lambda domain: (shard_counts.get(domain, 0), domain))[:limit]


def generate_graph_candidates(emphasis_domains: list[str] | None = None, frontier_limit: int = 64) -> dict[str, object]:
    ensure_state_layout()
    nodes, frontier = load_graph()
    progress = load_progress()
    current_count = len(nodes)
    target = int(progress["target_design_nodes"])
    gap = max(0, target - current_count)
    node_map = {str(node["id"]): node for node in nodes}
    if current_count >= target:
        payload = {"role": "generator", "kind": "design_node_batch", "emphasis_domains": emphasis_domains or [], "frontier": [], "items": []}
        write_json_if_changed(GENERATED_CANDIDATES_PATH, payload)
        return payload
    preferred = [node_id for node_id in frontier if not emphasis_domains or derive_domain(node_id) in emphasis_domains]
    ordered_frontier = (preferred + [node_id for node_id in frontier if node_id not in preferred])[:frontier_limit]
    candidate_nodes = []
    for frontier_id in ordered_frontier:
        parent = node_map.get(frontier_id)
        if not parent:
            continue
        candidate_nodes.extend(generate_children(parent))
        if gap and len(candidate_nodes) >= gap:
            break
    payload = {
        "role": "generator",
        "kind": "design_node_batch",
        "emphasis_domains": emphasis_domains or [],
        "frontier": ordered_frontier,
        "items": candidate_nodes[: gap or len(candidate_nodes)],
    }
    write_json_if_changed(GENERATED_CANDIDATES_PATH, payload)
    return payload


def merge_graph_candidates() -> dict[str, int]:
    payload = read_json(GENERATED_CANDIDATES_PATH, {"items": [], "frontier": []})
    accepted, rejected = validate_candidate_nodes(payload.get("items", []))
    _, current_frontier = load_graph()
    frontier = [str(node["id"]) for node in accepted] or payload.get("frontier", []) or current_frontier
    stats = apply_candidate_nodes(accepted, frontier)
    write_json_if_changed(
        GENERATED_CANDIDATES_PATH,
        {
            **payload,
            "accepted_count": len(accepted),
            "rejected_count": len(rejected),
            "rejected": rejected[:200],
        },
    )
    return stats


def expand_design_graph() -> dict[str, int]:
    payload = generate_graph_candidates(frontier_limit=64)
    if payload.get("items"):
        return merge_graph_candidates()
    return graph_stats()


def infer_schema(node: dict[str, object]) -> dict[str, object]:
    node_id = str(node["id"])
    leaf = node_id.split(".")[-1]
    schema_type = "float"
    value_range: list[object] = [0.0, 1.0]
    default: object = 0.5
    distribution = "weighted"
    if any(token in leaf for token in ["count", "limit", "window", "level", "cap", "size"]):
        schema_type = "int"
        value_range = [0, 500]
        default = 30
        distribution = "banded"
    elif any(token in leaf for token in ["rules", "policy", "profile", "table", "gate"]):
        schema_type = "enum"
        value_range = ["conservative", "baseline", "aggressive"]
        default = "baseline"
        distribution = "categorical"
    elif any(token in leaf for token in ["rate", "ratio", "modifier", "tax", "pressure"]):
        schema_type = "float"
        value_range = [0.0, 3.0]
        default = 1.0
        distribution = "log"
    return {
        "id": node_id,
        "type": schema_type,
        "range": value_range,
        "default": default,
        "distribution": distribution,
        "tuning_priority": str(node["domain"]),
    }


def generate_schema_candidates() -> dict[str, object]:
    nodes, _ = load_graph()
    payload = {"items": [infer_schema(node) for node in nodes]}
    write_json_if_changed(GENERATED_SCHEMA_PATH, payload)
    return payload


def generate_parameter_schema() -> dict[str, int]:
    generate_schema_candidates()
    return merge_schema_candidates()


def merge_schema_candidates() -> dict[str, int]:
    payload = read_json(GENERATED_SCHEMA_PATH, {"items": []})
    grouped = {domain: [] for domain in DOMAINS}
    seen = set()
    for item in payload.get("items", []):
        item_id = str(item.get("id", ""))
        if not item_id or item_id in seen:
            continue
        seen.add(item_id)
        grouped[derive_domain(item_id)].append(item)
    total = 0
    shards = []
    for domain in DOMAINS:
        items = sorted(grouped[domain], key=lambda entry: entry["id"])
        total += len(items)
        write_json_if_changed(DESIGN_SCHEMA_DIR / f"{domain}.json", {"domain": domain, "items": items})
        shards.append({"domain": domain, "path": f"data/design_schema/{domain}.json", "count": len(items)})
    write_json_if_changed(DESIGN_SCHEMA_DIR / "schema_manifest.json", {"schema_item_count": total, "target_schema_items": TARGETS["schema_items"], "shards": shards})
    return {"schema_item_count": total}


def monster_identity(region: str, family_slug: str, family_drop: str, tier: int, variant: int) -> tuple[str, str]:
    prefix = ["lane", "ridge", "den", "watch", "grave"][variant % 5]
    monster_id = f"{region}_{family_slug}_t{tier:02d}_v{variant:02d}"
    name = f"{region.replace('_', ' ').title()} {prefix.title()} {family_slug.replace('_', ' ').title()}"
    return monster_id, f"{name} {family_drop}"


def build_level_curve_rows() -> list[dict[str, object]]:
    rows = []
    total = 15
    for level in range(1, 221):
        band = (level - 1) // 20
        bottleneck = 1.0 + (0.18 if level in {30, 55, 70, 95, 120, 160, 200} else 0.0)
        party_relief = 0.96 if level in {45, 90, 135, 180} else 1.0
        exp_required = int((total + (level ** 2.12) * (1.08 + band * 0.045)) * bottleneck * party_relief)
        total = exp_required
        rows.append({"level": level, "exp_required": exp_required})
    return rows


def build_party_window_rows() -> list[dict[str, object]]:
    rows = []
    for band_index in range(44):
        min_level = band_index * 5 + 1
        max_level = min_level + 4
        center = (min_level + max_level) / 2.0
        bonus = 1.015 + 0.18 * math.exp(-((center - 92.0) ** 2) / 3900.0)
        if 35 <= center <= 60 or 115 <= center <= 145:
            bonus += 0.035
        if 70 <= center <= 95:
            bonus += 0.018
        rows.append(
            {
                "band_id": f"party_band_{band_index + 1:02d}",
                "min_level": min_level,
                "max_level": max_level,
                "party_bonus": round(bonus, 4),
                "solo_pressure": round(1.165 - min(0.24, band_index * 0.0045), 4),
            }
        )
    return rows


def build_monster_rows() -> list[dict[str, object]]:
    rows = []
    for region_index, region in enumerate(REGIONS):
        for family_index, (slug, drop_name) in enumerate(MONSTER_FAMILIES):
            for tier in range(1, 21):
                for variant in range(12):
                    level = tier * 9 + variant // 3 + region_index
                    hp = int((42 + level * level * 1.85) * (1.0 + family_index * 0.025) * (1.0 + variant * 0.012))
                    attack = int(8 + level * 2.1 + family_index * 3 + (tier % 4) * 5)
                    defense = int(4 + level * 1.2 + variant * 2 + family_index)
                    elite_rate = round(0.02 + (0.004 * ((tier + family_index + variant) % 6)), 4)
                    monster_id, display_name = monster_identity(region, slug, drop_name, tier, variant)
                    rows.append(
                        {
                            "monster_id": monster_id,
                            "display_name": display_name,
                            "region": region,
                            "recommended_level": level,
                            "hp": hp,
                            "attack": attack,
                            "defense": defense,
                            "exp_reward": int(level * 11.5 + tier * 13 + variant * 4),
                            "elite_rate": elite_rate,
                        }
                    )
    return rows


def build_item_rows() -> list[dict[str, object]]:
    rows = []
    for tier in range(1, 25):
        for cls_index, item_class in enumerate(ITEM_CLASSES):
            for material_index, material in enumerate(ITEM_MATERIALS):
                for variant in range(1, 2 + 1):
                    item_id = f"{material}_{item_class}_tier{tier:02d}_mk{variant}"
                    power_score = int(tier * 18 + cls_index * 9 + material_index * 4 + variant * 5)
                    repair_cost = int(45 + tier * tier * 0.7 + cls_index * 11 + material_index * 6)
                    lifecycle_band = "quest" if tier <= 6 else "field" if tier <= 14 else "boss"
                    rows.append(
                        {
                            "item_id": item_id,
                            "display_name": f"{material.title()} {item_class.title()} Mk{variant}",
                            "tier": tier,
                            "power_score": power_score,
                            "repair_cost": repair_cost,
                            "lifecycle_band": lifecycle_band,
                        }
                    )
    return rows


def build_equipment_rows(item_rows: list[dict[str, object]]) -> list[dict[str, object]]:
    rows = []
    for idx, item in enumerate(item_rows[:2200]):
        tier = int(item["tier"])
        success_rate = max(0.18, 0.92 - tier * 0.022 - (idx % 5) * 0.015)
        cost_multiplier = 1.08 + tier * 0.09 + (idx % 7) * 0.03
        rows.append(
            {
                "curve_id": f"{item['item_id']}_upgrade",
                "item_id": item["item_id"],
                "success_rate": round(success_rate, 4),
                "failure_penalty": 1 + (tier // 5) + (idx % 3),
                "cost_multiplier": round(cost_multiplier, 4),
            }
        )
    return rows


def build_drop_rows(monster_rows: list[dict[str, object]], item_rows: list[dict[str, object]]) -> list[dict[str, object]]:
    rows = []
    rarity_bands = ["common", "uncommon", "rare", "elite", "boss"]
    for idx in range(9600):
        monster = monster_rows[idx % len(monster_rows)]
        item = item_rows[(idx * 7 + int(monster["recommended_level"])) % len(item_rows)]
        level = int(monster["recommended_level"])
        rarity_index = min(4, level // 45 + (1 if idx % 19 == 0 else 0))
        rarity = rarity_bands[rarity_index]
        base_rate = [0.22, 0.11, 0.038, 0.012, 0.004][rarity_index]
        pressure = 0.92 if level > 140 else 1.0
        rows.append(
            {
                "monster_id": monster["monster_id"],
                "item_id": item["item_id"],
                "drop_profile": f"{monster['region']}_{rarity}_table",
                "rarity_band": rarity,
                "drop_rate": round(base_rate * pressure * (1.0 + (idx % 5) * 0.03), 6),
            }
        )
    return rows


def build_sink_rows() -> list[dict[str, object]]:
    rows = []
    sink_base = {
        "taxi_fare": 0.9,
        "repair_bill": 1.28,
        "scroll_cleansing": 1.05,
        "storage_rent": 1.08,
        "market_listing_fee": 1.11,
        "market_tax": 1.18,
        "pet_feed_maintenance": 1.2,
        "guild_banner_fee": 1.26,
        "boss_entry_ticket": 1.42,
        "alchemy_catalyst": 1.31,
        "starforce_attempt": 1.52,
        "socket_reset": 1.46,
    }
    for idx in range(720):
        sink_type = SINK_TYPES[idx % len(SINK_TYPES)]
        level_band = 1 + (idx % 24)
        trigger_scale = 1.0 + (0.08 if 8 <= level_band <= 12 or 18 <= level_band <= 22 else 0.0)
        meso_cost = int((150 + level_band * level_band * 18 + (idx % 6) * 33) * trigger_scale)
        sink_weight = sink_base[sink_type] + level_band * 0.022 + (idx % 3) * 0.02
        rows.append(
            {
                "sink_id": f"{sink_type}_band_{level_band:02d}",
                "sink_type": sink_type,
                "level_band": level_band,
                "meso_cost": meso_cost,
                "sink_weight": round(sink_weight, 4),
                "trigger_window": f"lv{level_band * 10 - 9:03d}_lv{level_band * 10:03d}",
            }
        )
    return rows


def build_field_rows() -> tuple[list[dict[str, object]], list[dict[str, object]]]:
    population_rows = []
    ladder_rows = []
    for idx in range(900):
        region = REGIONS[idx % len(REGIONS)]
        theme = FIELD_THEMES[idx % len(FIELD_THEMES)]
        band = 1 + (idx % 180)
        transition_band = band in {14, 28, 42, 56, 70, 90, 110, 130, 150, 170}
        party_anchor = 35 <= band <= 60 or 112 <= band <= 148
        pressure_wave = ((band % 8) * 0.055) + ((idx % 3) * 0.015)
        congestion = 0.84 + pressure_wave + (0.1 if party_anchor else 0.0) - (0.045 if band % 18 == 0 else 0.0)
        solo_efficiency = 0.758 + ((band % 12) * 0.027) - (0.052 if transition_band else 0.0)
        party_efficiency = solo_efficiency + 0.125 + ((band % 6) * 0.014) + (0.025 if party_anchor else 0.0)
        population_rows.append(
            {
                "map_id": f"{region}_{theme}_{idx:03d}",
                "region": region,
                "population_target": 30 + band // 2 + (6 if party_anchor else 0) + (idx % 10),
                "spawn_density": round(0.9 + (band % 7) * 0.072 + (0.035 if transition_band else 0.0), 4),
                "channel_scale": round(1.0 + (idx % 4) * 0.08 + (0.05 if party_anchor else 0.0), 4),
                "congestion_pressure": round(congestion, 4),
            }
        )
        ladder_rows.append(
            {
                "zone_id": f"{region}_{theme}_ladder_{idx:03d}",
                "recommended_level": band,
                "solo_efficiency": round(max(0.72, solo_efficiency), 4),
                "party_efficiency": round(min(1.34, party_efficiency), 4),
                "contested_pressure": round(congestion, 4),
            }
        )
    return population_rows, ladder_rows


def build_boss_rows() -> list[dict[str, object]]:
    rows = []
    for idx in range(180):
        band = 25 + idx
        party_size = 2 + (idx % 4) + (1 if band >= 120 and idx % 5 == 0 else 0)
        reward_currency = 1120 + band * 32 + (idx % 5) * 74 - (120 if 45 <= band <= 70 else 0)
        reward_drop_bonus = 1.04 + (idx % 7) * 0.095 + (0.05 if 95 <= band <= 135 else 0.0)
        weekly_limit = 1 + (1 if band >= 110 else 0)
        rows.append(
            {
                "boss_id": f"boss_gate_{idx + 1:03d}",
                "entry_band": band,
                "party_size": party_size,
                "reward_currency": reward_currency,
                "reward_drop_bonus": round(reward_drop_bonus, 4),
                "weekly_limit": weekly_limit,
            }
        )
    return rows


def build_dungeon_rows() -> list[dict[str, object]]:
    rows = []
    for idx in range(140):
        bracket = 10 + idx
        rows.append(
            {
                "dungeon_id": f"dungeon_loop_{idx + 1:03d}",
                "entry_band": bracket,
                "clear_time_target": 14 + (idx % 9) * 3 + (2 if bracket >= 80 else 0),
                "weekly_limit": 2 if bracket < 60 else 1,
                "cadence_score": round(1.02 + (idx % 6) * 0.08, 4),
            }
        )
    return rows


def build_balance_data() -> dict[str, list[dict[str, object]]]:
    level_curve = build_level_curve_rows()
    party_windows = build_party_window_rows()
    monster_rows = build_monster_rows()
    item_rows = build_item_rows()
    equipment_rows = build_equipment_rows(item_rows)
    drop_rows = build_drop_rows(monster_rows, item_rows)
    sink_rows = build_sink_rows()
    population_rows, ladder_rows = build_field_rows()
    boss_rows = build_boss_rows()
    dungeon_rows = build_dungeon_rows()
    return {
        "level_curve": level_curve,
        "party_windows": party_windows,
        "monster_stats": monster_rows,
        "drop_table": drop_rows,
        "sinks": sink_rows,
        "population_balance": population_rows,
        "zone_ladder": ladder_rows,
        "item_stats": item_rows,
        "upgrade_curves": equipment_rows,
        "boss_rewards": boss_rows,
        "dungeon_cadence": dungeon_rows,
    }


def generate_balance_tables() -> dict[str, int]:
    data = build_balance_data()
    write_csv_if_changed(BALANCE_DIR / "progression" / "level_curve.csv", ["level", "exp_required"], data["level_curve"])
    write_csv_if_changed(BALANCE_DIR / "progression" / "party_windows.csv", ["band_id", "min_level", "max_level", "party_bonus", "solo_pressure"], data["party_windows"])
    write_csv_if_changed(BALANCE_DIR / "monsters" / "monster_stats.csv", ["monster_id", "display_name", "region", "recommended_level", "hp", "attack", "defense", "exp_reward", "elite_rate"], data["monster_stats"])
    write_csv_if_changed(BALANCE_DIR / "drops" / "drop_table.csv", ["monster_id", "item_id", "drop_profile", "rarity_band", "drop_rate"], data["drop_table"])
    write_csv_if_changed(BALANCE_DIR / "economy" / "sinks.csv", ["sink_id", "sink_type", "level_band", "meso_cost", "sink_weight", "trigger_window"], data["sinks"])
    write_csv_if_changed(BALANCE_DIR / "fields" / "population_balance.csv", ["map_id", "region", "population_target", "spawn_density", "channel_scale", "congestion_pressure"], data["population_balance"])
    write_csv_if_changed(BALANCE_DIR / "fields" / "zone_ladder.csv", ["zone_id", "recommended_level", "solo_efficiency", "party_efficiency", "contested_pressure"], data["zone_ladder"])
    write_csv_if_changed(BALANCE_DIR / "items" / "item_stats.csv", ["item_id", "display_name", "tier", "power_score", "repair_cost", "lifecycle_band"], data["item_stats"])
    write_csv_if_changed(BALANCE_DIR / "equipment" / "upgrade_curves.csv", ["curve_id", "item_id", "success_rate", "failure_penalty", "cost_multiplier"], data["upgrade_curves"])
    write_csv_if_changed(BALANCE_DIR / "bosses" / "boss_rewards.csv", ["boss_id", "entry_band", "party_size", "reward_currency", "reward_drop_bonus", "weekly_limit"], data["boss_rewards"])
    write_csv_if_changed(BALANCE_DIR / "dungeons" / "dungeon_cadence.csv", ["dungeon_id", "entry_band", "clear_time_target", "weekly_limit", "cadence_score"], data["dungeon_cadence"])
    row_count = sum(len(rows) for rows in data.values())
    write_json_if_changed(
        BALANCE_DIR / "manifest.json",
        {
            "balance_row_count": row_count,
            "target_balance_rows": TARGETS["balance_rows"],
            "files": [
                "data/balance/progression/level_curve.csv",
                "data/balance/progression/party_windows.csv",
                "data/balance/monsters/monster_stats.csv",
                "data/balance/drops/drop_table.csv",
                "data/balance/economy/sinks.csv",
                "data/balance/fields/population_balance.csv",
                "data/balance/fields/zone_ladder.csv",
                "data/balance/items/item_stats.csv",
                "data/balance/equipment/upgrade_curves.csv",
                "data/balance/bosses/boss_rewards.csv",
                "data/balance/dungeons/dungeon_cadence.csv",
            ],
        },
    )
    return {"balance_row_count": row_count}


def generate_balance_candidates() -> dict[str, object]:
    generate_balance_tables()
    payload = {
        "progression": {
            "level_curve": read_text_if_exists(BALANCE_DIR / "progression" / "level_curve.csv"),
            "party_windows": read_text_if_exists(BALANCE_DIR / "progression" / "party_windows.csv"),
        },
        "monsters": {"monster_stats": read_text_if_exists(BALANCE_DIR / "monsters" / "monster_stats.csv")},
        "drops": {"drop_table": read_text_if_exists(BALANCE_DIR / "drops" / "drop_table.csv")},
        "economy": {"sinks": read_text_if_exists(BALANCE_DIR / "economy" / "sinks.csv")},
        "fields": {
            "population_balance": read_text_if_exists(BALANCE_DIR / "fields" / "population_balance.csv"),
            "zone_ladder": read_text_if_exists(BALANCE_DIR / "fields" / "zone_ladder.csv"),
        },
        "items": {"item_stats": read_text_if_exists(BALANCE_DIR / "items" / "item_stats.csv")},
        "equipment": {"upgrade_curves": read_text_if_exists(BALANCE_DIR / "equipment" / "upgrade_curves.csv")},
        "bosses": {"boss_rewards": read_text_if_exists(BALANCE_DIR / "bosses" / "boss_rewards.csv")},
        "dungeons": {"dungeon_cadence": read_text_if_exists(BALANCE_DIR / "dungeons" / "dungeon_cadence.csv")},
    }
    write_json_if_changed(GENERATED_BALANCE_PATH, payload)
    return payload


def merge_balance_candidates() -> dict[str, int]:
    payload = read_json(GENERATED_BALANCE_PATH, {})
    file_map = {
        ("progression", "level_curve"): BALANCE_DIR / "progression" / "level_curve.csv",
        ("progression", "party_windows"): BALANCE_DIR / "progression" / "party_windows.csv",
        ("monsters", "monster_stats"): BALANCE_DIR / "monsters" / "monster_stats.csv",
        ("drops", "drop_table"): BALANCE_DIR / "drops" / "drop_table.csv",
        ("economy", "sinks"): BALANCE_DIR / "economy" / "sinks.csv",
        ("fields", "population_balance"): BALANCE_DIR / "fields" / "population_balance.csv",
        ("fields", "zone_ladder"): BALANCE_DIR / "fields" / "zone_ladder.csv",
        ("items", "item_stats"): BALANCE_DIR / "items" / "item_stats.csv",
        ("equipment", "upgrade_curves"): BALANCE_DIR / "equipment" / "upgrade_curves.csv",
        ("bosses", "boss_rewards"): BALANCE_DIR / "bosses" / "boss_rewards.csv",
        ("dungeons", "dungeon_cadence"): BALANCE_DIR / "dungeons" / "dungeon_cadence.csv",
    }
    for (section, name), path in file_map.items():
        content = str(payload.get(section, {}).get(name, ""))
        if content:
            write_text_if_changed(path, content if content.endswith("\n") else content + "\n")
    return generate_balance_tables()


def generate_liveops_assets() -> dict[str, int]:
    nodes, _ = load_graph()
    node_ids = [str(node["id"]) for node in nodes] or ["liveops"]
    overrides = []
    rotations = []
    emergency_controls = []
    for idx in range(1000):
        event_type = EVENT_TYPES[idx % len(EVENT_TYPES)]
        overrides.append(
            {
                "id": f"{event_type}_override_{idx + 1:04d}",
                "target_node": node_ids[(idx * 11) % len(node_ids)],
                "window": f"W{(idx % 52) + 1:02d}",
                "value": round(0.9 + (idx % 8) * 0.08, 4),
                "reason": "retention_pressure" if idx % 3 == 0 else "economy_balance",
            }
        )
    for idx in range(800):
        rotations.append(
            {
                "id": f"calendar_rotation_{idx + 1:04d}",
                "theme": EVENT_TYPES[idx % len(EVENT_TYPES)],
                "target_node": node_ids[(idx * 7) % len(node_ids)],
                "multiplier": round(1.0 + (idx % 6) * 0.12, 4),
                "release_wave": 1 + idx // 40,
            }
        )
    for idx in range(600):
        emergency_controls.append(
            {
                "id": f"economy_guard_{idx + 1:04d}",
                "target_node": node_ids[(idx * 13) % len(node_ids)],
                "threshold": round(1.1 + (idx % 7) * 0.14, 4),
                "action": "freeze_market" if idx % 2 == 0 else "throttle_rewards",
                "rollback_checkpoint": f"checkpoint_{(idx % 18) + 1:02d}",
            }
        )
    write_json_if_changed(LIVEOPS_DIR / "overrides" / "global_overrides.json", {"items": overrides})
    write_json_if_changed(LIVEOPS_DIR / "rotations" / "seasonal_rotations.json", {"items": rotations})
    write_json_if_changed(LIVEOPS_DIR / "emergency_controls" / "emergency_controls.json", {"items": emergency_controls})
    total = len(overrides) + len(rotations) + len(emergency_controls)
    write_json_if_changed(LIVEOPS_DIR / "manifest.json", {"liveops_row_count": total, "target_liveops_rows": TARGETS["liveops_rows"]})
    return {"liveops_row_count": total}


def generate_liveops_candidates() -> dict[str, object]:
    generate_liveops_assets()
    payload = {
        "overrides": read_json(LIVEOPS_DIR / "overrides" / "global_overrides.json", {"items": []}).get("items", []),
        "rotations": read_json(LIVEOPS_DIR / "rotations" / "seasonal_rotations.json", {"items": []}).get("items", []),
        "emergency_controls": read_json(LIVEOPS_DIR / "emergency_controls" / "emergency_controls.json", {"items": []}).get("items", []),
    }
    write_json_if_changed(GENERATED_LIVEOPS_PATH, payload)
    return payload


def merge_liveops_candidates() -> dict[str, int]:
    payload = read_json(GENERATED_LIVEOPS_PATH, {})
    write_json_if_changed(LIVEOPS_DIR / "overrides" / "global_overrides.json", {"items": payload.get("overrides", [])})
    write_json_if_changed(LIVEOPS_DIR / "rotations" / "seasonal_rotations.json", {"items": payload.get("rotations", [])})
    write_json_if_changed(LIVEOPS_DIR / "emergency_controls" / "emergency_controls.json", {"items": payload.get("emergency_controls", [])})
    total = len(payload.get("overrides", [])) + len(payload.get("rotations", [])) + len(payload.get("emergency_controls", []))
    write_json_if_changed(LIVEOPS_DIR / "manifest.json", {"liveops_row_count": total, "target_liveops_rows": TARGETS["liveops_rows"]})
    return {"liveops_row_count": total}


def generate_expansion_assets() -> dict[str, int]:
    packs = {"regions": [], "monsters": [], "bosses": [], "gear": [], "events": []}
    for idx in range(1100):
        region = REGIONS[idx % len(REGIONS)]
        packs["regions"].append({"id": f"{region}_frontier_pack_{idx + 1:04d}", "region": region, "release_wave": 1 + idx // 50, "cadence": "quarterly", "focus": "route_density"})
    for idx in range(1200):
        slug, _ = MONSTER_FAMILIES[idx % len(MONSTER_FAMILIES)]
        region = REGIONS[(idx * 3) % len(REGIONS)]
        packs["monsters"].append({"id": f"{region}_{slug}_pack_{idx + 1:04d}", "monster_family": slug, "region": region, "release_wave": 1 + idx // 60, "cadence": "monthly"})
    for idx in range(900):
        packs["bosses"].append({"id": f"boss_arc_{idx + 1:04d}", "entry_band": 30 + (idx % 150), "cadence": "seasonal", "unlock_type": "guild_party" if idx % 3 == 0 else "public_party"})
    for idx in range(1100):
        item_class = ITEM_CLASSES[idx % len(ITEM_CLASSES)]
        material = ITEM_MATERIALS[(idx * 2) % len(ITEM_MATERIALS)]
        packs["gear"].append({"id": f"{material}_{item_class}_bundle_{idx + 1:04d}", "tier_band": 1 + (idx % 24), "cadence": "monthly", "lifecycle": "replacement"})
    for idx in range(1100):
        event_type = EVENT_TYPES[idx % len(EVENT_TYPES)]
        region = REGIONS[(idx * 5) % len(REGIONS)]
        packs["events"].append({"id": f"{event_type}_{region}_event_{idx + 1:04d}", "event_type": event_type, "region": region, "cadence": "weekly", "reward_mode": "sink_offset" if idx % 2 == 0 else "progression_boost"})
    write_json_if_changed(EXPANSIONS_DIR / "regions" / "region_packs.json", {"items": packs["regions"]})
    write_json_if_changed(EXPANSIONS_DIR / "monsters" / "monster_packs.json", {"items": packs["monsters"]})
    write_json_if_changed(EXPANSIONS_DIR / "bosses" / "boss_packs.json", {"items": packs["bosses"]})
    write_json_if_changed(EXPANSIONS_DIR / "gear" / "gear_packs.json", {"items": packs["gear"]})
    write_json_if_changed(EXPANSIONS_DIR / "events" / "event_packs.json", {"items": packs["events"]})
    total = sum(len(items) for items in packs.values())
    write_json_if_changed(EXPANSIONS_DIR / "manifest.json", {"expansion_asset_count": total, "target_expansion_assets": TARGETS["expansion_assets"]})
    return {"expansion_asset_count": total}


def generate_expansion_candidates() -> dict[str, object]:
    generate_expansion_assets()
    payload = {
        "regions": read_json(EXPANSIONS_DIR / "regions" / "region_packs.json", {"items": []}).get("items", []),
        "monsters": read_json(EXPANSIONS_DIR / "monsters" / "monster_packs.json", {"items": []}).get("items", []),
        "bosses": read_json(EXPANSIONS_DIR / "bosses" / "boss_packs.json", {"items": []}).get("items", []),
        "gear": read_json(EXPANSIONS_DIR / "gear" / "gear_packs.json", {"items": []}).get("items", []),
        "events": read_json(EXPANSIONS_DIR / "events" / "event_packs.json", {"items": []}).get("items", []),
    }
    write_json_if_changed(GENERATED_EXPANSIONS_PATH, payload)
    return payload


def merge_expansion_candidates() -> dict[str, int]:
    payload = read_json(GENERATED_EXPANSIONS_PATH, {})
    write_json_if_changed(EXPANSIONS_DIR / "regions" / "region_packs.json", {"items": payload.get("regions", [])})
    write_json_if_changed(EXPANSIONS_DIR / "monsters" / "monster_packs.json", {"items": payload.get("monsters", [])})
    write_json_if_changed(EXPANSIONS_DIR / "bosses" / "boss_packs.json", {"items": payload.get("bosses", [])})
    write_json_if_changed(EXPANSIONS_DIR / "gear" / "gear_packs.json", {"items": payload.get("gear", [])})
    write_json_if_changed(EXPANSIONS_DIR / "events" / "event_packs.json", {"items": payload.get("events", [])})
    total = sum(len(payload.get(key, [])) for key in ["regions", "monsters", "bosses", "gear", "events"])
    write_json_if_changed(EXPANSIONS_DIR / "manifest.json", {"expansion_asset_count": total, "target_expansion_assets": TARGETS["expansion_assets"]})
    return {"expansion_asset_count": total}


def review_generated_assets() -> dict[str, object]:
    monster_rows = read_csv_rows(BALANCE_DIR / "monsters" / "monster_stats.csv")
    drop_rows = read_csv_rows(BALANCE_DIR / "drops" / "drop_table.csv")
    sink_rows = read_csv_rows(BALANCE_DIR / "economy" / "sinks.csv")
    level_rows = read_csv_rows(BALANCE_DIR / "progression" / "level_curve.csv")
    issues = []

    def is_fake_identity(value: str) -> bool:
        lowered = value.lower()
        return lowered.startswith(tuple(f"{domain}." for domain in DOMAINS)) or "synthetic" in lowered or "abstract" in lowered or "schema" in lowered

    monster_fake = sum(1 for row in monster_rows if is_fake_identity(row.get("monster_id", "")) or "." in row.get("monster_id", ""))
    item_fake = sum(1 for row in drop_rows if is_fake_identity(row.get("item_id", "")))
    sink_fake = sum(1 for row in sink_rows if is_fake_identity(row.get("sink_id", "")) or "." in row.get("sink_id", ""))
    smooth_curve = 0
    exp_values = [int(row["exp_required"]) for row in level_rows if row.get("exp_required")]
    if len(exp_values) >= 5:
        deltas = [exp_values[index + 1] - exp_values[index] for index in range(len(exp_values) - 1)]
        second = [abs(deltas[index + 1] - deltas[index]) for index in range(len(deltas) - 1)]
        smooth_curve = 1 if average(second) < 4.0 else 0
    if monster_fake:
        issues.append({"reason": "schema_path_identity_monster", "count": monster_fake})
    if item_fake:
        issues.append({"reason": "schema_path_identity_item", "count": item_fake})
    if sink_fake:
        issues.append({"reason": "schema_path_identity_sink", "count": sink_fake})
    if smooth_curve:
        issues.append({"reason": "overly_smooth_progression_curve", "count": smooth_curve})
    return {
        "rejected_count": sum(issue["count"] for issue in issues),
        "issues": issues,
        "useful_asset_ratio": round(
            1.0 - (
                (monster_fake + item_fake + sink_fake)
                / max(1, len(monster_rows) + len(drop_rows) + len(sink_rows))
            ),
            4,
        ),
    }


def repair_generated_assets(review: dict[str, object]) -> dict[str, object]:
    if int(review.get("rejected_count", 0)) == 0:
        return {"repaired": False, "reason": "no_repair_needed"}
    generate_balance_candidates()
    generate_liveops_candidates()
    generate_expansion_candidates()
    return {"repaired": True, "reason": "deterministic_regeneration", "rejected_before_repair": int(review.get("rejected_count", 0))}


def simulate_world() -> dict[str, object]:
    level_rows = read_csv_rows(BALANCE_DIR / "progression" / "level_curve.csv")
    party_rows = read_csv_rows(BALANCE_DIR / "progression" / "party_windows.csv")
    sink_rows = read_csv_rows(BALANCE_DIR / "economy" / "sinks.csv")
    field_rows = read_csv_rows(BALANCE_DIR / "fields" / "population_balance.csv")
    zone_rows = read_csv_rows(BALANCE_DIR / "fields" / "zone_ladder.csv")
    boss_rows = read_csv_rows(BALANCE_DIR / "bosses" / "boss_rewards.csv")
    item_rows = read_csv_rows(BALANCE_DIR / "items" / "item_stats.csv")
    equipment_rows = read_csv_rows(BALANCE_DIR / "equipment" / "upgrade_curves.csv")
    drop_rows = read_csv_rows(BALANCE_DIR / "drops" / "drop_table.csv")
    monster_rows = read_csv_rows(BALANCE_DIR / "monsters" / "monster_stats.csv")

    exp_values = [int(row["exp_required"]) for row in level_rows]
    deltas = [exp_values[index + 1] - exp_values[index] for index in range(len(exp_values) - 1)]
    second = [abs(deltas[index + 1] - deltas[index]) for index in range(len(deltas) - 1)]
    sink_total = sum(int(row["meso_cost"]) * float(row["sink_weight"]) for row in sink_rows)
    source_total = sum(int(row["exp_reward"]) * 2.3 for row in monster_rows[: len(sink_rows) * 5]) if monster_rows else 1.0
    congestion_values = [float(row["congestion_pressure"]) for row in field_rows]
    party_values = [float(row["party_efficiency"]) for row in zone_rows]
    solo_values = [float(row["solo_efficiency"]) for row in zone_rows]
    boss_currency = [int(row["reward_currency"]) for row in boss_rows]
    power_values = [int(row["power_score"]) for row in item_rows]
    tier_buckets: dict[int, list[int]] = {}
    for row in item_rows:
        tier_buckets.setdefault(int(row["tier"]), []).append(int(row["power_score"]))
    tier_averages = [average(values) for _, values in sorted(tier_buckets.items())]
    replacement_span = [tier_averages[index + 1] - tier_averages[index] for index in range(len(tier_averages) - 1)]
    rarity_counts = {}
    for row in drop_rows:
        rarity = row["rarity_band"]
        rarity_counts[rarity] = rarity_counts.get(rarity, 0) + 1
    rarity_values = sorted(rarity_counts.values())
    smoothness = average(second)

    metrics = {
        "progression_pacing_drift": round(abs(average(deltas[:80]) / max(1.0, average(deltas[-40:])) - 0.31), 4),
        "sink_source_ratio": round(sink_total / max(1.0, source_total), 4),
        "map_congestion_pressure": round(average(congestion_values), 4),
        "solo_party_route_pressure": round(average(party_values) / max(0.01, average(solo_values)), 4),
        "boss_reward_inflation_pressure": round(average(boss_currency) / 5200.0, 4),
        "item_replacement_pressure": round(average(replacement_span) / 18.0 if replacement_span else 0.0, 4),
        "drop_rarity_compression": round(rarity_values[-1] / max(1.0, rarity_values[0]) if rarity_values else 0.0, 4),
        "power_curve_bottleneck_structure": round(smoothness / 120.0, 4),
        "equipment_failure_pressure": round(average([float(row["cost_multiplier"]) * (1.0 - float(row["success_rate"])) for row in equipment_rows]) / 2.4 if equipment_rows else 0.0, 4),
    }
    status = "stable"
    if metrics["sink_source_ratio"] > 1.9 or metrics["boss_reward_inflation_pressure"] > 1.35:
        status = "watch"
    return {"metrics": metrics, "status": status}


def load_counts() -> dict[str, int]:
    graph_manifest = read_json(DESIGN_GRAPH_DIR / "manifest.json", {})
    schema_manifest = read_json(DESIGN_SCHEMA_DIR / "schema_manifest.json", {})
    balance_manifest = read_json(BALANCE_DIR / "manifest.json", {})
    liveops_manifest = read_json(LIVEOPS_DIR / "manifest.json", {})
    expansion_manifest = read_json(EXPANSIONS_DIR / "manifest.json", {})
    return {
        "design_nodes_count": int(graph_manifest.get("node_count", 0)),
        "schema_items_count": int(schema_manifest.get("schema_item_count", 0)),
        "balance_rows_count": int(balance_manifest.get("balance_row_count", 0)),
        "liveops_rows_count": int(liveops_manifest.get("liveops_row_count", 0)),
        "expansion_assets_count": int(expansion_manifest.get("expansion_asset_count", 0)),
    }


def compute_structure_signals(simulation: dict[str, object]) -> dict[str, float]:
    manifest = read_json(DESIGN_GRAPH_DIR / "manifest.json", {})
    index = read_json(DESIGN_GRAPH_DIR / "index.json", {}).get("index", {})
    score_targets_exist = PROGRESS_PATH.exists() and EVAL_SCORES_PATH.exists() and SCORE_HISTORY_PATH.exists()
    prompt_files_exist = all((PROMPTS_DIR / f"{name}.md").exists() for name in ["generator", "critic", "simulator", "supervisor", "merger"])
    nodes = read_json(DESIGN_GRAPH_DIR / "nodes.json", {"nodes": []}).get("nodes", [])
    unique_nodes = len({str(node["id"]) for node in nodes})
    deterministic_merge_integrity = 1.0 if unique_nodes == len(index) == len(nodes) else 0.0
    shard_storage_integrity = 1.0 if len(manifest.get("shards", [])) == len(DOMAINS) and all((DESIGN_GRAPH_DIR / f"{domain}.json").exists() for domain in DOMAINS) else 0.0
    return {
        "runnable_entrypoints_exist": 1.0 if all((ROOT / "scripts" / "codex" / name).exists() for name in [
            "initialize_design_graph.py",
            "regenerate_frontier.py",
            "merge_nodes.py",
            "generate_schema.py",
            "merge_schema.py",
            "generate_balance.py",
            "merge_balance.py",
            "generate_liveops.py",
            "merge_liveops.py",
            "generate_expansions.py",
            "merge_expansions.py",
            "simulate_world.py",
            "score_candidates.py",
            "update_progress.py",
            "run_generation_cycle.py",
            "run_supervisor.py",
        ]) else 0.0,
        "shard_storage_integrity": shard_storage_integrity,
        "deterministic_merge_integrity": deterministic_merge_integrity,
        "supervisor_loop_integrity": 1.0 if score_targets_exist and prompt_files_exist else 0.0,
        "simulation_loop_integrity": 1.0 if "metrics" in simulation and len(simulation["metrics"]) >= 8 else 0.0,
        "repeated_run_safety": 1.0 if deterministic_merge_integrity and GENERATED_BALANCE_PATH.exists() and GENERATED_LIVEOPS_PATH.exists() and GENERATED_EXPANSIONS_PATH.exists() else 0.0,
    }


def compute_live_balance_signals(simulation: dict[str, object]) -> dict[str, float]:
    zone_rows = read_csv_rows(BALANCE_DIR / "fields" / "zone_ladder.csv")
    party_rows = read_csv_rows(BALANCE_DIR / "progression" / "party_windows.csv")
    monster_rows = read_csv_rows(BALANCE_DIR / "monsters" / "monster_stats.csv")
    drop_rows = read_csv_rows(BALANCE_DIR / "drops" / "drop_table.csv")
    sink_rows = read_csv_rows(BALANCE_DIR / "economy" / "sinks.csv")
    boss_rows = read_csv_rows(BALANCE_DIR / "bosses" / "boss_rewards.csv")
    item_rows = read_csv_rows(BALANCE_DIR / "items" / "item_stats.csv")
    metrics = simulation["metrics"]
    contested = [float(row["contested_pressure"]) for row in zone_rows]
    return {
        "progression_curve_quality": closeness_score(metrics["progression_pacing_drift"], 0.28, 0.08),
        "zone_ladder_quality": closeness_score(average(contested), 1.1, 0.18),
        "party_window_quality": closeness_score(average([float(row["party_bonus"]) for row in party_rows]), 1.10, 0.09),
        "monster_profile_quality": 1.0 if all("." not in row["monster_id"] for row in monster_rows[:200]) else 0.0,
        "drop_table_quality": closeness_score(metrics["drop_rarity_compression"], 4.0, 1.5) * (1.0 if all("." not in row["item_id"] for row in drop_rows[:300]) else 0.0),
        "sink_source_balance_quality": closeness_score(metrics["sink_source_ratio"], 0.48, 0.18),
        "reward_cadence_quality": closeness_score(average([float(row["reward_drop_bonus"]) for row in boss_rows]), 1.42, 0.35),
        "item_lifecycle_quality": closeness_score(metrics["item_replacement_pressure"], 1.0, 0.22) * closeness_score(average([int(row["repair_cost"]) for row in item_rows]) / 1000.0, 0.32, 0.12),
    }


def compute_maple_similarity_signals(simulation: dict[str, object]) -> dict[str, float]:
    zone_rows = read_csv_rows(BALANCE_DIR / "fields" / "zone_ladder.csv")
    sink_rows = read_csv_rows(BALANCE_DIR / "economy" / "sinks.csv")
    party_rows = read_csv_rows(BALANCE_DIR / "progression" / "party_windows.csv")
    boss_rows = read_csv_rows(BALANCE_DIR / "bosses" / "boss_rewards.csv")
    drop_rows = read_csv_rows(BALANCE_DIR / "drops" / "drop_table.csv")
    field_rows = read_csv_rows(BALANCE_DIR / "fields" / "population_balance.csv")
    metrics = simulation["metrics"]
    return {
        "leveling_band_similarity": closeness_score(len(zone_rows), 900.0, 150.0),
        "hunting_field_ladder_similarity": closeness_score(average([float(row["party_efficiency"]) - float(row["solo_efficiency"]) for row in zone_rows]), 0.19, 0.08),
        "meso_sink_pressure_similarity": closeness_score(metrics["sink_source_ratio"], 0.48, 0.18),
        "potion_burn_similarity": closeness_score(average([int(row["meso_cost"]) for row in sink_rows]) / 1000.0, 3.8, 1.8),
        "party_vs_solo_window_similarity": closeness_score(metrics["solo_party_route_pressure"], 1.29, 0.16),
        "contested_map_pressure_similarity": closeness_score(metrics["map_congestion_pressure"], 1.1, 0.15),
        "boss_access_rhythm_similarity": closeness_score(average([int(row["entry_band"]) for row in boss_rows]), 114.0, 25.0),
        "rarity_distribution_similarity": closeness_score(metrics["drop_rarity_compression"], 4.0, 1.5),
        "social_density_similarity": closeness_score(average([int(row["population_target"]) for row in field_rows]), 79.0, 22.0),
        "liveops_tunability_similarity": closeness_score(read_json(LIVEOPS_DIR / "manifest.json", {}).get("liveops_row_count", 0), 2400.0, 800.0),
    }


def compute_asset_signals(review: dict[str, object]) -> dict[str, float]:
    counts = load_counts()
    useful_asset_ratio = float(review.get("useful_asset_ratio", 0.0))
    duplicate_reduction = 1.0 - max(0, counts["design_nodes_count"] - len(load_index_map())) / max(1, counts["design_nodes_count"])
    return {
        "design_nodes_count": ratio_score(counts["design_nodes_count"], TARGETS["design_nodes"]),
        "schema_items_count": ratio_score(counts["schema_items_count"], TARGETS["schema_items"]),
        "balance_rows_count": ratio_score(counts["balance_rows_count"], TARGETS["balance_rows"]),
        "liveops_rows_count": ratio_score(counts["liveops_rows_count"], TARGETS["liveops_rows"]),
        "expansion_assets_count": ratio_score(counts["expansion_assets_count"], TARGETS["expansion_assets"]),
        "duplicate_reduction_rate": clamp(duplicate_reduction),
        "useful_asset_ratio": clamp(useful_asset_ratio),
    }


def aggregate_score(signals: dict[str, float], scale: float) -> float:
    return round(sum(clamp(value, 0.0, 1.1) for value in signals.values()) / max(1, len(signals)) * scale, 2)


def compute_eval_scores(review: dict[str, object] | None = None) -> dict[str, object]:
    ensure_state_layout()
    review = review or review_generated_assets()
    simulation = simulate_world()
    structure_signals = compute_structure_signals(simulation)
    asset_signals = compute_asset_signals(review)
    live_balance_signals = compute_live_balance_signals(simulation)
    maple_similarity_signals = compute_maple_similarity_signals(simulation)

    structure_score = aggregate_score(structure_signals, 120.0)
    throughput_score = aggregate_score(asset_signals, 110.0)
    live_balance_score = aggregate_score(live_balance_signals, 120.0)
    similarity_score = aggregate_score(maple_similarity_signals, 120.0)
    overall_efficiency_score = round(
        (
            structure_score * 0.18
            + throughput_score * 0.22
            + live_balance_score * 0.30
            + similarity_score * 0.30
        )
        * 1.16,
        2,
    )

    categories = {
        "structure_pipeline_score": structure_score,
        "asset_throughput_score": throughput_score,
        "live_balance_quality_score": live_balance_score,
        "mapleland_similarity_score": similarity_score,
        "overall_efficiency_score": overall_efficiency_score,
    }
    weakest_dimension = min(
        ["structure_pipeline_score", "asset_throughput_score", "live_balance_quality_score", "mapleland_similarity_score"],
        key=lambda key: categories[key],
    )
    payload = {
        "targets": SCORE_TARGETS,
        "categories": categories,
        "weakest_dimension": weakest_dimension,
        "signals": {
            **structure_signals,
            **asset_signals,
            **live_balance_signals,
            **maple_similarity_signals,
        },
        "simulation": simulation,
        "review": review,
        "counts": load_counts(),
        "all_thresholds_met": all(categories[key] >= SCORE_TARGETS[key] for key in SCORE_TARGETS),
    }
    write_json_if_changed(EVAL_SCORES_PATH, payload)
    append_jsonl(SCORE_HISTORY_PATH, payload)
    return payload


def record_simulation_result() -> dict[str, object]:
    payload = compute_eval_scores()
    return payload["simulation"]


def score_candidates() -> dict[str, object]:
    return compute_eval_scores()


def update_progress() -> dict[str, object]:
    progress = load_progress()
    counts = load_counts()
    scores = read_json(EVAL_SCORES_PATH, {})
    player_experience = read_json(PLAYER_EXPERIENCE_METRICS_PATH, {})
    categories = scores.get("categories", {})
    previous_design_nodes = int(progress.get("design_nodes", 0))
    progress.update(
        {
            "design_nodes": counts["design_nodes_count"],
            "schema_items": counts["schema_items_count"],
            "balance_rows": counts["balance_rows_count"],
            "liveops_rows": counts["liveops_rows_count"],
            "expansion_assets": counts["expansion_assets_count"],
            "structure_pipeline_score": round(float(categories.get("structure_pipeline_score", 0.0)), 2),
            "asset_throughput_score": round(float(categories.get("asset_throughput_score", 0.0)), 2),
            "live_balance_quality_score": round(float(categories.get("live_balance_quality_score", 0.0)), 2),
            "mapleland_similarity_score": round(float(categories.get("mapleland_similarity_score", 0.0)), 2),
            "overall_efficiency_score": round(float(categories.get("overall_efficiency_score", 0.0)), 2),
            "weakest_dimension": scores.get("weakest_dimension", "structure_pipeline_score"),
            "active_player_bottleneck": player_experience.get("active_player_bottleneck", progress.get("active_player_bottleneck", "first_10_minutes")),
            "overall_player_experience_floor": player_experience.get("overall_player_experience_floor", progress.get("overall_player_experience_floor", "60~62")),
            "first_10_minutes": player_experience.get("ranges", {}).get("first_10_minutes", progress.get("first_10_minutes", "60~62")),
            "first_hour_retention": player_experience.get("ranges", {}).get("first_hour_retention", progress.get("first_hour_retention", "60~62")),
            "day1_return_intent": player_experience.get("ranges", {}).get("day1_return_intent", progress.get("day1_return_intent", "60~62")),
            "last_run_added": max(0, counts["design_nodes_count"] - previous_design_nodes),
            "last_status": "complete" if scores.get("all_thresholds_met") else f"repairing_{scores.get('weakest_dimension', 'structure_pipeline_score')}",
        }
    )
    progress["project_complete"] = bool(scores.get("all_thresholds_met"))
    progress["all_targets_met"] = progress["project_complete"]
    write_json_if_changed(PROGRESS_PATH, progress)
    return progress
