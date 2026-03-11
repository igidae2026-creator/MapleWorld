from __future__ import annotations

import csv
import json
import re
from datetime import datetime, timezone
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
STATE_DIR = ROOT_DIR / "offline_ops" / "codex_state" / "governance"
OUTPUT_PATH = STATE_DIR / "gameplay_depth_status.json"
NPCS_PATH = ROOT_DIR / "data" / "npcs.csv"
QUESTS_PATH = ROOT_DIR / "data" / "quests.csv"
DIALOGUES_PATH = ROOT_DIR / "data" / "dialogues.csv"
ROUTING_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs" / "channel_routing_metrics_latest.json"


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle))


def _normalized_unique_ratio(rows: list[dict[str, str]], field: str) -> float:
    texts = [(row.get(field) or "").strip() for row in rows if (row.get(field) or "").strip()]
    if not texts:
        return 0.0
    normalized = {re.sub(r"\d+", "<n>", text) for text in texts}
    return round(len(normalized) / len(texts), 4)


def build_gameplay_depth_status() -> dict[str, object]:
    npcs = _read_csv(NPCS_PATH)
    quests = _read_csv(QUESTS_PATH)
    dialogues = _read_csv(DIALOGUES_PATH)
    routing = json.loads(ROUTING_PATH.read_text(encoding="utf-8")) if ROUTING_PATH.exists() else {}
    exploration = dict(routing.get("exploration_stagnation", {}))

    npc_regions = {row.get("region", "").strip() for row in npcs if row.get("region", "").strip()}
    quest_starters = {row.get("start_npc", "").strip() for row in quests if row.get("start_npc", "").strip()}
    dialogue_maps = {row.get("map_name", "").strip() for row in dialogues if row.get("map_name", "").strip()}

    thresholds = {
        "npc_count_min": 900,
        "quest_count_min": 1000,
        "dialogue_count_min": 18000,
        "npc_region_count_min": 10,
        "quest_start_npc_count_min": 20,
        "dialogue_map_count_min": 800,
        "quest_narrative_unique_ratio_min": 0.22,
        "quest_guidance_unique_ratio_min": 0.08,
        "dialogue_text_unique_ratio_min": 0.05,
        "transition_total_min": 70,
        "exploration_stagnation_max": 0.56,
    }
    metrics = {
        "npc_count": len(npcs),
        "quest_count": len(quests),
        "dialogue_count": len(dialogues),
        "npc_region_count": len(npc_regions),
        "quest_start_npc_count": len(quest_starters),
        "dialogue_map_count": len(dialogue_maps),
        "quest_narrative_unique_ratio": _normalized_unique_ratio(quests, "narrative"),
        "quest_guidance_unique_ratio": _normalized_unique_ratio(quests, "guidance"),
        "dialogue_text_unique_ratio": _normalized_unique_ratio(dialogues, "text"),
        "transition_total": int(exploration.get("transition_total", 0) or 0),
        "exploration_stagnation_index": float(exploration.get("index", 1.0) or 1.0),
        "exploration_stagnation_status": str(exploration.get("status", "missing")),
    }

    failures: list[str] = []
    if metrics["npc_count"] < thresholds["npc_count_min"]:
        failures.append("npc_count_below_floor")
    if metrics["quest_count"] < thresholds["quest_count_min"]:
        failures.append("quest_count_below_floor")
    if metrics["dialogue_count"] < thresholds["dialogue_count_min"]:
        failures.append("dialogue_count_below_floor")
    if metrics["npc_region_count"] < thresholds["npc_region_count_min"]:
        failures.append("npc_region_count_below_floor")
    if metrics["quest_start_npc_count"] < thresholds["quest_start_npc_count_min"]:
        failures.append("quest_start_npc_count_below_floor")
    if metrics["dialogue_map_count"] < thresholds["dialogue_map_count_min"]:
        failures.append("dialogue_map_count_below_floor")
    if metrics["quest_narrative_unique_ratio"] < thresholds["quest_narrative_unique_ratio_min"]:
        failures.append("quest_narrative_variety_below_floor")
    if metrics["quest_guidance_unique_ratio"] < thresholds["quest_guidance_unique_ratio_min"]:
        failures.append("quest_guidance_variety_below_floor")
    if metrics["dialogue_text_unique_ratio"] < thresholds["dialogue_text_unique_ratio_min"]:
        failures.append("dialogue_text_variety_below_floor")
    if metrics["transition_total"] < thresholds["transition_total_min"]:
        failures.append("transition_total_below_floor")
    if metrics["exploration_stagnation_index"] > thresholds["exploration_stagnation_max"]:
        failures.append("exploration_stagnation_too_high")
    if metrics["exploration_stagnation_status"] != "allow":
        failures.append("exploration_stagnation_not_allow")

    return {
        "generated_at_utc": _utc_now(),
        "artifact": str(OUTPUT_PATH.relative_to(ROOT_DIR)),
        "status": "pass" if not failures else "fail",
        "metrics": metrics,
        "thresholds": thresholds,
        "failures": failures,
    }


def main() -> int:
    payload = build_gameplay_depth_status()
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(OUTPUT_PATH)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
