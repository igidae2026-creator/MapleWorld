#!/usr/bin/env python3

from __future__ import annotations

import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
POLICY_PATH = ROOT / "ai_evolution_offline" / "codex" / "bottleneck_policy.json"
PLAYER_METRICS_PATH = ROOT / "offline_ops" / "codex_state" / "simulation_runs" / "player_experience_metrics_latest.json"
ECONOMY_PRESSURE_PATH = ROOT / "offline_ops" / "codex_state" / "simulation_runs" / "economy_pressure_metrics_latest.json"
EARLY02_REBALANCE_REPORT = ROOT / "offline_ops" / "codex_state" / "simulation_runs" / "early02_rebalance_candidates.json"
EARLY02_SHADOW_RELIEF_REPORT = ROOT / "offline_ops" / "codex_state" / "simulation_runs" / "early02_shadow_relief_candidates.json"


def extract_field(text: str, field: str) -> str:
    lines = text.splitlines()
    capture = False
    for line in lines:
        if capture:
            if not line.strip():
                return ""
            return line.strip()
        if line.strip() == f"{field}:":
            capture = True
    return ""


def extract_files(text: str) -> list[str]:
    files: list[str] = []
    capture = False
    for line in text.splitlines():
        stripped = line.strip()
        if stripped == "FILES:":
            capture = True
            continue
        if capture and stripped == "PATCH_BOUNDARY:":
            break
        if capture and stripped.startswith("- "):
            files.append(stripped[2:].replace("`", "").strip())
    return files


def normalize_rel_path(raw_path: str) -> str:
    candidate = Path(raw_path)
    if candidate.is_absolute():
        try:
            return str(candidate.resolve().relative_to(ROOT.resolve()))
        except Exception:
            return raw_path
    return raw_path


def top_economy_pressure_node() -> str:
    top_nodes = top_economy_pressure_nodes()
    if not top_nodes:
        return ""
    first = dict(top_nodes[0])
    return str(first.get("node", "")).strip()


def top_economy_pressure_nodes() -> list[dict[str, object]]:
    if not ECONOMY_PRESSURE_PATH.exists():
        return []
    payload = json.loads(ECONOMY_PRESSURE_PATH.read_text(encoding="utf-8"))
    top_nodes = payload.get("top_pressure_nodes", [])
    if not isinstance(top_nodes, list) or not top_nodes:
        return []
    return [dict(item) for item in top_nodes]


def early02_floor_locked() -> bool:
    role_bands_path = ROOT / "data" / "balance" / "maps" / "role_bands.csv"
    if not role_bands_path.exists():
        return False
    rows = []
    header: list[str] | None = None
    for line in role_bands_path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        parts = line.split(",")
        if header is None:
            header = parts
            continue
        rows.append(dict(zip(header, parts)))
    subset = [row for row in rows if str(row.get("band_id", "")) == "early_02"]
    if len(subset) < 3:
        return False
    throughput = [float(row.get("throughput_bias", 0.0) or 0.0) for row in subset]
    rewards = [float(row.get("reward_bias", 0.0) or 0.0) for row in subset]
    return (max(throughput) - min(throughput)) <= 0.1200001 and (max(rewards) - min(rewards)) <= 0.1400001


def early02_rebalance_exhausted() -> bool:
    if not EARLY02_REBALANCE_REPORT.exists():
        return False
    payload = json.loads(EARLY02_REBALANCE_REPORT.read_text(encoding="utf-8"))
    return str(payload.get("recommendation", "")).strip() == "same-band early_02 rebalance exhausted"


def early02_shadow_relief_exhausted() -> bool:
    if not EARLY02_SHADOW_RELIEF_REPORT.exists():
        return False
    payload = json.loads(EARLY02_SHADOW_RELIEF_REPORT.read_text(encoding="utf-8"))
    return str(payload.get("recommendation", "")).strip() == "same-band early_02 shadow relief exhausted"


def next_non_early02_pressure_node() -> str:
    blocked = {
        "map:perion_rockfall_edge",
        "map:ellinia_lower_canopy",
        "map:lith_harbor_coast_road",
    }
    for item in top_economy_pressure_nodes():
        node = str(item.get("node", "")).strip()
        if node.startswith("map:") and node not in blocked:
            return node
    return ""


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: validate_bottleneck_scope.py <decision_file>", file=sys.stderr)
        return 2
    decision_path = Path(sys.argv[1])
    if not decision_path.exists():
        print(f"decision file does not exist: {decision_path}")
        return 1
    decision_text = decision_path.read_text(encoding="utf-8")
    key = extract_field(decision_text, "BOTTLENECK_KEY")
    files = extract_files(decision_text)
    player_metrics = json.loads(PLAYER_METRICS_PATH.read_text(encoding="utf-8"))
    active_key = str(player_metrics.get("active_player_bottleneck", "")).strip()
    policy = json.loads(POLICY_PATH.read_text(encoding="utf-8"))

    if not key:
        print("missing BOTTLENECK_KEY")
        return 1
    if key not in policy:
        print(f"unknown bottleneck key: {key}")
        return 1
    if active_key and key != active_key:
        print(f"bottleneck key does not match active player bottleneck: {key} != {active_key}")
        return 1
    if not files:
        print("missing decision files")
        return 1

    allowed_roots = set(policy[key]["allowed_roots"])
    preferred_paths = [str(path) for path in policy[key]["preferred_paths"]]
    touched_preferred = False
    for raw_path in files:
        rel_path = normalize_rel_path(raw_path)
        root = rel_path.split("/", 1)[0]
        if root not in allowed_roots:
            print(f"file outside allowed roots for {key}: {rel_path}")
            return 1
        if any(rel_path == pref or rel_path.startswith(pref.rstrip("/") + "/") for pref in preferred_paths):
            touched_preferred = True

    if not touched_preferred:
        allowed_hint = ", ".join(sorted(preferred_paths))
        print(
            f"decision does not touch a preferred path for bottleneck {key}; "
            f"use one of: {allowed_hint}"
        )
        return 1

    if key == "economy_coherence":
        top_node = top_economy_pressure_node()
        lowered_hotspot_only = (
            "perion_rockfall_edge" in decision_text
            and "ellinia_lower_canopy" not in decision_text
            and "lith_harbor_coast_road" not in decision_text
        )
        touched_map_balance = any(
            rel_path == "data/balance/maps/role_bands.csv"
            or rel_path.startswith("data/balance/maps/")
            for rel_path in (normalize_rel_path(path) for path in files)
        )
        if top_node.startswith("map:") and not touched_map_balance:
            print(
                "economy_coherence is currently driven by a map-scoped top pressure node; "
                "decision must touch data/balance/maps/role_bands.csv or another data/balance/maps/* path"
            )
            return 1
        if top_node == "map:perion_rockfall_edge" and touched_map_balance and early02_floor_locked() and lowered_hotspot_only:
            print(
                "early_02 spread floors are already at the guarded minimum; "
                "reject one-map perion_rockfall_edge-only reduction and choose a compatible early_02 rebalance"
            )
            return 1
        if top_node == "map:perion_rockfall_edge" and touched_map_balance and (early02_rebalance_exhausted() or early02_shadow_relief_exhausted()):
            next_node = next_non_early02_pressure_node()
            mentions_early02 = (
                "early_02" in decision_text
                or "perion_rockfall_edge" in decision_text
                or "ellinia_lower_canopy" in decision_text
                or "lith_harbor_coast_road" in decision_text
            )
            if mentions_early02:
                print(
                    "same-band early_02 rebalance is exhausted; "
                    "reject repeated early_02 hotspot edits and pivot to the next map-scoped pressure node"
                )
                return 1
            if next_node:
                next_name = next_node.split(":", 1)[1]
                if next_name not in decision_text:
                    print(
                        "same-band early_02 rebalance is exhausted; "
                        f"decision must target the next map-scoped pressure node: {next_name}"
                    )
                    return 1

    print("PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
