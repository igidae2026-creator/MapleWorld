from __future__ import annotations

import csv
import json
import re
from collections import Counter, defaultdict
from pathlib import Path
from typing import Iterable


ROOT_DIR = Path(__file__).resolve().parents[1]
ROLE_BANDS_PATH = ROOT_DIR / "data" / "balance" / "maps" / "role_bands.csv"
IDENTITY_PACK_PATH = ROOT_DIR / "data" / "expansions" / "identity" / "starter_world_identity_pack.json"
EARLY_BOSS_PACK_PATH = ROOT_DIR / "data" / "expansions" / "bosses" / "early_chase_boss_pack.json"
RUNTIME_TABLES_PATH = ROOT_DIR / "runtime_tables.lua"


def _load_role_bands() -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    with ROLE_BANDS_PATH.open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            rows.append(
                {
                    "band_id": str(row["band_id"]),
                    "min_level": int(row["min_level"]),
                    "max_level": int(row["max_level"]),
                    "map_id": str(row["map_id"]),
                    "role": str(row["role"]),
                    "throughput_bias": float(row["throughput_bias"]),
                    "reward_bias": float(row["reward_bias"]),
                }
            )
    return rows


def _load_identity_regions() -> list[dict[str, object]]:
    payload = json.loads(IDENTITY_PACK_PATH.read_text(encoding="utf-8"))
    rows: list[dict[str, object]] = []
    for region in payload.get("regions", []):
        level_band = dict(region.get("level_band", {}))
        rows.append(
            {
                "region_id": str(region.get("region_id", "unknown")),
                "min_level": int(level_band.get("min", 1)),
                "max_level": int(level_band.get("max", 30)),
                "tier": "early",
                "source": "identity_pack",
            }
        )
    return rows


def _parse_runtime_regions() -> list[dict[str, object]]:
    text = RUNTIME_TABLES_PATH.read_text(encoding="utf-8")
    pattern = re.compile(r"(\w+)\s*=\s*\{\s*min = (\d+), max = (\d+)")
    rows: list[dict[str, object]] = []
    for match in pattern.finditer(text):
        region_id = match.group(1)
        minimum = int(match.group(2))
        maximum = int(match.group(3))
        tier = "early" if maximum <= 30 else "mid" if maximum <= 80 else "late"
        rows.append(
            {
                "region_id": region_id,
                "min_level": minimum,
                "max_level": maximum,
                "tier": tier,
                "source": "runtime",
            }
        )
    return rows


def _parse_runtime_bosses() -> list[str]:
    text = RUNTIME_TABLES_PATH.read_text(encoding="utf-8")
    block_match = re.search(r"runtime\.boss_respawn_groups = \{(.*?)\n\}", text, re.DOTALL)
    if not block_match:
        return []
    return sorted(set(re.findall(r"'([^']+)'", block_match.group(1))))


def _load_early_bosses() -> list[dict[str, object]]:
    payload = json.loads(EARLY_BOSS_PACK_PATH.read_text(encoding="utf-8"))
    return [dict(row) for row in payload.get("bosses", [])]


def _region_for_level(level: int, regions: list[dict[str, object]]) -> str:
    for region in regions:
        if int(region["min_level"]) <= level <= int(region["max_level"]):
            return str(region["region_id"])
    if not regions:
        return "unknown_region"
    # deterministic nearest fallback
    nearest = min(regions, key=lambda row: abs(level - int(row["min_level"])))
    return str(nearest["region_id"])


def _style_route_weights(style: str) -> dict[str, float]:
    if style == "party_grinder":
        return {"safe": 0.28, "alternative": 0.34, "high_risk_high_reward": 0.38}
    if style == "quest_player":
        return {"safe": 0.22, "alternative": 0.52, "high_risk_high_reward": 0.26}
    return {"safe": 0.40, "alternative": 0.33, "high_risk_high_reward": 0.27}


def build_world_graph(players: Iterable[object], loops: int) -> dict[str, object]:
    role_bands = _load_role_bands()
    identity_regions = _load_identity_regions()
    runtime_regions = _parse_runtime_regions()

    region_rows_by_id: dict[str, dict[str, object]] = {}
    for row in runtime_regions + identity_regions:
        region_rows_by_id[str(row["region_id"])] = row
    regions = list(sorted(region_rows_by_id.values(), key=lambda row: (int(row["min_level"]), str(row["region_id"]))))

    early_bosses = _load_early_bosses()
    runtime_bosses = _parse_runtime_bosses()
    early_boss_ids = {str(row.get("boss_id", "")) for row in early_bosses}

    nodes: list[dict[str, object]] = []
    edges: list[dict[str, object]] = []

    for region in regions:
        node_id = f"region:{region['region_id']}"
        nodes.append(
            {
                "node_id": node_id,
                "node_type": "region",
                "min_level": int(region["min_level"]),
                "max_level": int(region["max_level"]),
                "content_slots": 3 if str(region.get("tier")) == "early" else 2,
                "tier": str(region.get("tier", "mid")),
            }
        )

    map_rows = sorted(role_bands, key=lambda row: (int(row["min_level"]), str(row["map_id"])))
    for row in map_rows:
        map_node_id = f"map:{row['map_id']}"
        nodes.append(
            {
                "node_id": map_node_id,
                "node_type": "map",
                "min_level": int(row["min_level"]),
                "max_level": int(row["max_level"]),
                "role": str(row["role"]),
                "throughput_bias": float(row["throughput_bias"]),
                "reward_bias": float(row["reward_bias"]),
                "content_slots": 1,
            }
        )

        region_id = _region_for_level(int(row["min_level"]), regions)
        edges.append(
            {
                "from": f"region:{region_id}",
                "to": map_node_id,
                "edge_type": "contains",
                "friction": round(max(0.08, 0.28 - float(row["throughput_bias"]) * 0.08), 4),
                "progression_weight": 0.45,
            }
        )

    # progression edges between consecutive regions
    for left, right in zip(regions, regions[1:]):
        band_gap = max(0, int(right["min_level"]) - int(left["max_level"]))
        edges.append(
            {
                "from": f"region:{left['region_id']}",
                "to": f"region:{right['region_id']}",
                "edge_type": "progression",
                "friction": round(min(0.55, 0.16 + band_gap * 0.01), 4),
                "progression_weight": 0.9,
            }
        )

    # dungeon nodes are region-backed instances for higher friction spaces
    for region in regions:
        rid = str(region["region_id"])
        if any(token in rid for token in ("dungeon", "depth", "shadow", "clockwork", "hidden")):
            dungeon_id = f"dungeon:{rid}"
            nodes.append(
                {
                    "node_id": dungeon_id,
                    "node_type": "dungeon",
                    "min_level": int(region["min_level"]),
                    "max_level": int(region["max_level"]),
                    "content_slots": 2,
                }
            )
            edges.append(
                {
                    "from": f"region:{rid}",
                    "to": dungeon_id,
                    "edge_type": "dungeon_access",
                    "friction": 0.34,
                    "progression_weight": 0.7,
                }
            )

    # boss nodes and encounter edges
    for boss in early_bosses:
        boss_id = str(boss.get("boss_id", "unknown"))
        region_id = str(boss.get("region_id", "unknown"))
        level = int(boss.get("recommended_level", 30))
        nodes.append(
            {
                "node_id": f"boss:{boss_id}",
                "node_type": "boss",
                "min_level": level,
                "max_level": max(level, level + 4),
                "content_slots": 2,
                "desirability_hint": max(
                    float(item.get("desirability", 0.0)) for item in list(boss.get("chase_items", []))
                )
                if list(boss.get("chase_items", []))
                else 0.7,
            }
        )
        edges.append(
            {
                "from": f"region:{region_id}",
                "to": f"boss:{boss_id}",
                "edge_type": "encounter",
                "friction": 0.38,
                "progression_weight": 0.8,
            }
        )

    # include runtime bosses that are not in early pack as lightweight nodes
    for boss_id in runtime_bosses:
        if boss_id in early_boss_ids:
            continue
        nodes.append(
            {
                "node_id": f"boss:{boss_id}",
                "node_type": "boss",
                "min_level": 30,
                "max_level": 120,
                "content_slots": 1,
                "desirability_hint": 0.75,
            }
        )

    # visit simulation over players and loops
    node_visits: Counter[str] = Counter()
    edge_traversals: Counter[str] = Counter()
    route_counts: Counter[str] = Counter()
    expected_visits: Counter[str] = Counter()

    map_rows_by_band: dict[str, list[dict[str, object]]] = defaultdict(list)
    for row in map_rows:
        map_rows_by_band[str(row["band_id"])].append(row)

    band_order = sorted(
        {
            (str(row["band_id"]), int(row["min_level"]), int(row["max_level"]))
            for row in map_rows
        },
        key=lambda row: row[1],
    )

    for player in players:
        level = int(getattr(player, "level", 1))
        style = str(getattr(player, "play_style", "solo_grinder"))
        current_region = _region_for_level(level, regions)
        region_node = f"region:{current_region}"

        active_band = None
        for band_id, minimum, maximum in band_order:
            if minimum <= level <= maximum:
                active_band = band_id
                break
        if active_band is None and band_order:
            active_band = band_order[0][0]

        for _ in range(loops):
            node_visits[region_node] += 1
            expected_visits[region_node] += 1
            if not active_band:
                continue
            route_weights = _style_route_weights(style)
            band_rows = map_rows_by_band.get(active_band, [])
            if not band_rows:
                continue
            for row in band_rows:
                map_node = f"map:{row['map_id']}"
                role = str(row["role"])
                expected_visits[map_node] += 1
                role_weight = route_weights.get(role, 0.33)
                visit_weight = max(0.1, role_weight * float(row["throughput_bias"]))
                node_visits[map_node] += visit_weight
                edge_key = f"{region_node}->{map_node}"
                edge_traversals[edge_key] += visit_weight
                route_counts[f"{active_band}:{role}"] += visit_weight

            # push periodic progression travel
            if level >= 20:
                next_region = None
                for region in regions:
                    if int(region["min_level"]) > level:
                        next_region = str(region["region_id"])
                        break
                if next_region:
                    to_node = f"region:{next_region}"
                    edge_traversals[f"{region_node}->{to_node}"] += 0.35
                    route_counts[f"progression:{current_region}->{next_region}"] += 0.35

    return {
        "nodes": nodes,
        "edges": edges,
        "node_visits": {key: round(float(value), 4) for key, value in sorted(node_visits.items())},
        "edge_traversals": {key: round(float(value), 4) for key, value in sorted(edge_traversals.items())},
        "route_counts": {key: round(float(value), 4) for key, value in sorted(route_counts.items())},
        "expected_visits": {key: int(value) for key, value in sorted(expected_visits.items())},
    }
