from __future__ import annotations

import csv
import json
import re
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT_DIR / "offline_ops" / "codex_state" / "governance"
STATUS_PATH = OUTPUT_DIR / "content_authenticity_status.json"
LEDGER_PATH = OUTPUT_DIR / "content_authenticity_history.jsonl"

NPCS_PATH = ROOT_DIR / "data" / "npcs.csv"
DIALOGUES_PATH = ROOT_DIR / "data" / "dialogues.csv"
QUESTS_PATH = ROOT_DIR / "data" / "quests.csv"

HANGUL_RE = re.compile(r"[가-힣]")
DIGIT_SUFFIX_RE = re.compile(r"\b\d+\b")
SLUG_RE = re.compile(r"[a-z]+_[a-z0-9_]+")

PLACEHOLDER_TOKENS = (
    "dbexp_",
    "points toward",
    "warns about",
    "quest_offer",
    "quest_progress",
    "quest_complete",
    "region_hint",
    "boss_rumor",
    "starter_fields",
)

GENERIC_ROLE_TOKENS = {
    "shopkeeper",
    "questgiver",
    "townfolk",
    "traveler",
    "guard",
    "scholar",
    "smith",
    "ferryman",
}


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def _ratio(numerator: int, denominator: int) -> float:
    if denominator <= 0:
        return 0.0
    return round(numerator / denominator, 4)


def _is_placeholder_npc(row: dict[str, str]) -> bool:
    name = str(row.get("name", ""))
    personality = str(row.get("personality", ""))
    lowered = f"{name} {personality}".lower()
    return (
        any(token in lowered for token in PLACEHOLDER_TOKENS)
        or any(token in lowered for token in GENERIC_ROLE_TOKENS)
        or bool(DIGIT_SUFFIX_RE.search(name))
        or bool(SLUG_RE.search(lowered))
        or not HANGUL_RE.search(name)
    )


def _is_placeholder_dialogue(row: dict[str, str]) -> bool:
    text = str(row.get("text", ""))
    lowered = text.lower()
    return (
        any(token in lowered for token in PLACEHOLDER_TOKENS)
        or bool(SLUG_RE.search(lowered))
        or not HANGUL_RE.search(text)
    )


def _is_placeholder_quest(row: dict[str, str]) -> bool:
    name = str(row.get("name", ""))
    narrative = str(row.get("narrative", ""))
    guidance = str(row.get("guidance", ""))
    text = f"{name} {narrative} {guidance}".lower()
    return (
        any(token in text for token in PLACEHOLDER_TOKENS)
        or bool(SLUG_RE.search(text))
        or not HANGUL_RE.search(name + narrative + guidance)
    )


def _top_counter(counter: Counter[str], limit: int = 8) -> list[dict[str, object]]:
    return [{"key": key, "count": count} for key, count in counter.most_common(limit)]


def build_status() -> dict[str, object]:
    npcs = _read_csv(NPCS_PATH)
    dialogues = _read_csv(DIALOGUES_PATH)
    quests = _read_csv(QUESTS_PATH)

    npc_placeholder = 0
    dialogue_placeholder = 0
    quest_placeholder = 0
    korean_dialogues = 0
    korean_npcs = 0
    korean_quests = 0

    npc_regions = Counter()
    dialogue_maps = Counter()
    quest_starts = Counter()

    for row in npcs:
        if HANGUL_RE.search(str(row.get("name", ""))) or HANGUL_RE.search(str(row.get("personality", ""))):
            korean_npcs += 1
        if _is_placeholder_npc(row):
            npc_placeholder += 1
            npc_regions[str(row.get("region", "unknown"))] += 1

    for row in dialogues:
        if HANGUL_RE.search(str(row.get("text", ""))):
            korean_dialogues += 1
        if _is_placeholder_dialogue(row):
            dialogue_placeholder += 1
            dialogue_maps[str(row.get("map_name", "unknown"))] += 1

    for row in quests:
        if HANGUL_RE.search(str(row.get("name", "")) + str(row.get("narrative", "")) + str(row.get("guidance", ""))):
            korean_quests += 1
        if _is_placeholder_quest(row):
            quest_placeholder += 1
            quest_starts[str(row.get("start_npc", "unknown"))] += 1

    ratios = {
        "npc_placeholder_ratio": _ratio(npc_placeholder, len(npcs)),
        "dialogue_placeholder_ratio": _ratio(dialogue_placeholder, len(dialogues)),
        "quest_placeholder_ratio": _ratio(quest_placeholder, len(quests)),
        "npc_korean_surface_ratio": _ratio(korean_npcs, len(npcs)),
        "dialogue_korean_surface_ratio": _ratio(korean_dialogues, len(dialogues)),
        "quest_korean_surface_ratio": _ratio(korean_quests, len(quests)),
    }

    pass_status = (
        ratios["npc_placeholder_ratio"] <= 0.35
        and ratios["dialogue_placeholder_ratio"] <= 0.35
        and ratios["quest_placeholder_ratio"] <= 0.45
        and ratios["dialogue_korean_surface_ratio"] >= 0.45
        and ratios["npc_korean_surface_ratio"] >= 0.30
        and ratios["quest_korean_surface_ratio"] >= 0.40
    )

    payload = {
        "generated_at_utc": _utc_now(),
        "status": "pass" if pass_status else "fail",
        "counts": {
            "npcs": len(npcs),
            "dialogues": len(dialogues),
            "quests": len(quests),
            "placeholder_npcs": npc_placeholder,
            "placeholder_dialogues": dialogue_placeholder,
            "placeholder_quests": quest_placeholder,
        },
        "ratios": ratios,
        "blocking_hotspots": {
            "npc_regions": _top_counter(npc_regions),
            "dialogue_maps": _top_counter(dialogue_maps),
            "quest_start_npcs": _top_counter(quest_starts),
        },
        "repair_priorities": [
            "replace template NPC names and personalities with authored Korean-facing identities",
            "rewrite dialogue text away from schema filler and id-bearing English placeholders",
            "rewrite quest names and narrative/guidance into lived Korean player motivation",
        ],
    }
    return payload


def main() -> int:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    payload = build_status()
    STATUS_PATH.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    with LEDGER_PATH.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(payload, sort_keys=True) + "\n")
    print(STATUS_PATH)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
