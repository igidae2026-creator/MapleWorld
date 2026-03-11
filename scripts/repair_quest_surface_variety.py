from __future__ import annotations

import csv
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
QUESTS_PATH = ROOT_DIR / "data" / "quests.csv"
NPCS_PATH = ROOT_DIR / "data" / "npcs.csv"

REGION_LABELS = {
    "henesys_plains": "헤네시스 평원",
    "starter_fields": "시작 들판",
    "ellinia_forest": "엘리니아 숲길",
    "perion_rocklands": "페리온 바위지대",
    "kerning_city_shadow": "커닝시티 뒷골목",
    "sleepywood_depths": "슬리피우드 심층",
    "coastal_harbors": "해안 항구지대",
    "orbis_skyrealm": "오르비스 하늘길",
    "ludibrium_clockworks": "루디브리엄 시계구역",
    "elnath_snowfield": "엘나스 설원",
    "minar_mountain": "미나르 산맥",
    "ancient_hidden_domains": "고대 숨은길",
}

NARRATIVE_TEMPLATES = [
    "{npc}은(는) '{quest_name}' 일을 맡기며 {region}의 흐름이 끊기기 전에 손을 써 달라고 부탁한다.",
    "{npc}은(는) {region} 쪽 사냥 리듬이 흐트러졌다며 '{quest_name}' 문제를 정리해 달라고 말한다.",
    "{npc}은(는) 다음 구간으로 넘어가기 전에 {region}에서 '{quest_name}'부터 수습해야 한다고 강조한다.",
    "{npc}은(는) {region}의 발이 끊기면 사냥보다 회복비가 더 무섭다며 '{quest_name}' 일을 먼저 처리해 달라고 한다.",
    "{npc}은(는) {region}을 드나드는 사람들 사이에서 '{quest_name}' 문제가 오래 남아 있었다며 이번에 끝내 달라고 부탁한다.",
    "{npc}은(는) {region}에서 길 흐름이 다시 꼬이기 전에 '{quest_name}' 징후를 정리해 달라고 부탁한다.",
]

GUIDANCE_TEMPLATES = [
    "{region} 쪽에서 {objective_hint}만 채우고 오래 끌지 말고 {npc}에게 바로 돌아와라.",
    "{region}에 들어가면 욕심내지 말고 {objective_hint}부터 마친 뒤 {npc}에게 보고해라.",
    "{region}에서는 한 번에 무리해서 끌지 말고 {objective_hint}를 끝낸 다음 곧장 복귀해라.",
    "{region}에서 사냥 흐름이 꼬이기 전에 {objective_hint}만 정리하고 바로 {npc}에게 돌아와라.",
    "{region} 바깥에서 시간을 빼앗기지 말고 {objective_hint}를 채운 뒤 곧장 {npc}에게 보고해라.",
]


def _read_csv(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    with path.open(encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        return list(reader.fieldnames or []), list(reader)


def _write_csv(path: Path, fieldnames: list[str], rows: list[dict[str, str]]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def _suffix_index(quest_id: str) -> int:
    digits = "".join(ch for ch in quest_id if ch.isdigit())
    return int(digits or "0")


def _quest_region_label(quest_name: str, npc_region: str) -> str:
    words = [word for word in quest_name.split() if word]
    if len(words) >= 2:
        return " ".join(words[:2])
    return REGION_LABELS.get(npc_region, npc_region.replace("_", " "))


def _objective_hint(objectives: str) -> str:
    parts = [part.strip() for part in objectives.split("|") if part.strip()]
    has_kill = any(part.startswith("kill:") for part in parts)
    has_collect = any(part.startswith("collect:") for part in parts)
    if has_kill and has_collect:
        return "처치와 회수 목표"
    if has_kill:
        return "처치 목표"
    if has_collect:
        return "회수 목표"
    if any(part.startswith("boss:") for part in parts):
        return "우두머리 확인"
    return "맡은 일"


def _reward_summary(region: str, reward_exp: str, reward_mesos: str) -> str:
    return f"{region} 다음 구간으로 넘어가기 전 필요한 경험치 흐름과 메소 여유를 챙길 수 있다. ({reward_exp} exp / {reward_mesos} mesos)"


def main() -> int:
    npc_fields, npc_rows = _read_csv(NPCS_PATH)
    _, quest_rows = _read_csv(QUESTS_PATH)
    npc_by_id = {row["id"]: row for row in npc_rows}
    quest_fields = list(quest_rows[0].keys()) if quest_rows else []

    for row in quest_rows:
        npc = npc_by_id.get(row.get("start_npc", ""), {})
        npc_name = npc.get("name", "안내인")
        region = _quest_region_label(row.get("name", ""), npc.get("region", ""))
        objective_hint = _objective_hint(row.get("objectives", ""))
        index = _suffix_index(row.get("quest_id", ""))
        row["narrative"] = NARRATIVE_TEMPLATES[index % len(NARRATIVE_TEMPLATES)].format(
            npc=npc_name,
            region=region,
            quest_name=row.get("name", ""),
        )
        row["guidance"] = GUIDANCE_TEMPLATES[index % len(GUIDANCE_TEMPLATES)].format(
            region=region,
            objective_hint=objective_hint,
            npc=npc_name,
        )
        row["reward_summary"] = _reward_summary(region, row.get("reward_exp", "0"), row.get("reward_mesos", "0"))

    _write_csv(QUESTS_PATH, quest_fields, quest_rows)
    print(QUESTS_PATH)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
