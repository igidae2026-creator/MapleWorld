from __future__ import annotations

import csv
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
DIALOGUES_PATH = ROOT_DIR / "data" / "dialogues.csv"
NPCS_PATH = ROOT_DIR / "data" / "npcs.csv"

REGION_LABELS = {
    "starter_fields": "시작 들판",
    "henesys_plains": "헤네시스 평원",
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

TYPE_TEMPLATES = {
    "greeting": [
        "{npc}이(가) 손을 들어 불렀다. {region}에선 첫걸음보다 돌아오는 타이밍을 아는 쪽이 오래 버틴다.",
        "{npc}이(가) 낮게 말했다. {region}은 서두르는 사람보다 흐름을 읽는 사람 편을 더 오래 들어준다.",
        "{npc}이(가) 먼저 발걸음을 멈추게 했다. {region}에 들어갈 땐 손보다 머리가 먼저 풀려 있어야 한다.",
    ],
    "region_hint": [
        "{region} 쪽은 보기보다 발판 간격이 까다롭다. {personality_hint}",
        "{region}은 길을 아는 사람과 모르는 사람의 소모가 확실히 갈린다. {personality_hint}",
        "{region}에선 한 발 늦게 움직여도 되지만 한 번 욕심내면 물약이 먼저 무너진다. {personality_hint}",
    ],
    "quest_offer": [
        "이번 일은 {region} 초입 흐름이 다시 꼬이기 전에 손을 봐 달라는 부탁이다. {npc}은(는) 지금이 늦기 전이라고 본다.",
        "{npc}은(는) {region}에서 먼저 풀어야 할 일이 생겼다며 잠깐 손을 빌려 달라고 한다.",
        "{region} 쪽이 조용하다고 안심하면 꼭 한 번씩 비용을 크게 치른다. {npc}은(는) 그 전에 일을 끝내고 싶어 한다.",
    ],
    "quest_progress": [
        "좋다. 숫자만 채우지 말고 {region}의 리듬을 같이 익혀. 그래야 다음 구간에서 덜 흔들린다.",
        "{npc}은(는) 네가 서두르지 않는 걸 먼저 본다. {region}은 손보다 흐름을 익힌 사람이 결국 덜 다친다.",
        "지금 페이스면 괜찮다. {region}에선 빠른 사람보다 끊기지 않는 사람이 끝까지 이긴다.",
    ],
    "quest_complete": [
        "이 정도면 손이 풀렸다. {region} 안쪽으로 들어가도 오늘은 리듬을 유지할 수 있겠다.",
        "{npc}이(가) 고개를 끄덕였다. 이 정도면 {region} 다음 구간에서도 물약값에 쫓기진 않을 거다.",
        "좋아, 이번엔 깔끔했다. {region}에서 다시 꼬이지 않으려면 방금 같은 리듬을 기억해 둬라.",
    ],
    "lore": [
        "{region} 사람들은 오래전부터 귀환 타이밍을 놓치면 사냥보다 회복비가 더 무섭다고 말했다. {personality_hint}",
        "{region}에서 오래 버틴 이들은 한 번 크게 벌기보다 오래 살아남는 쪽이 결국 메소를 남긴다고 했다. {personality_hint}",
        "{region}에선 강한 적보다 흐트러진 욕심이 더 자주 사람을 눕힌다고들 한다. {personality_hint}",
    ],
    "boss_rumor": [
        "{npc}은(는) 우두머리가 늘 시끄럽게 오진 않는다고 했다. {region}에선 조용해질 때가 오히려 신호다.",
        "{region}의 우두머리는 발소리보다 공기의 빈틈으로 먼저 티가 난다. {npc}은(는) 그 순간을 놓치지 말라고 한다.",
        "{npc}은(는) {region} 우두머리가 나타나기 전엔 주변 흐름이 먼저 낯설어질 거라고 경고했다.",
    ],
    "shop": [
        "{npc}은(는) 물약과 귀환서는 아끼되 끊기진 말라고 했다. {region}에선 한 번 쓰러지면 오늘 번 메소가 통째로 흔들린다.",
        "{region}에서 흑자를 남기고 싶다면 무기만 보지 말고 소모품 계산부터 하라는 게 {npc}의 버릇이다.",
        "{npc}은(는) {region}에 나가기 전 장비보다 귀환서 장수를 먼저 세어 보라고 말한다.",
    ],
    "warning": [
        "{region}에선 한 번 꼬이면 순식간에 몰린다. {npc}은(는) 오늘은 한 무더기씩 끌지 말라고 못 박는다.",
        "{npc}은(는) {region}에서 욕심낼수록 퇴로가 먼저 지워진다고 경고한다.",
        "{region}은 실수 한 번을 오래 기억하는 곳이다. {npc}은(는) 무리한 몰이를 오늘만큼은 금하라고 한다.",
    ],
}


def _read_csv(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    with path.open(encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        return list(reader.fieldnames or []), list(reader)


def _write_csv(path: Path, fieldnames: list[str], rows: list[dict[str, str]]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def _personality_hint(text: str) -> str:
    if not text:
        return "길 흐름을 모르면 메소보다 먼저 마음이 흔들린다고 덧붙였다."
    cleaned = text.rstrip(". ")
    return cleaned + "."


def main() -> int:
    npc_fields, npc_rows = _read_csv(NPCS_PATH)
    dialogue_fields, dialogue_rows = _read_csv(DIALOGUES_PATH)
    npc_by_id = {row["id"]: row for row in npc_rows}

    for row in dialogue_rows:
        npc = npc_by_id.get(row.get("npc_id", ""), {})
        npc_name = npc.get("name", "주민")
        region = REGION_LABELS.get(npc.get("region", ""), row.get("map_name", "").replace("_", " "))
        personality_hint = _personality_hint(npc.get("personality", ""))
        dialogue_type = row.get("dialogue_type", "greeting")
        templates = TYPE_TEMPLATES.get(dialogue_type)
        if not templates:
            continue
        variant_index = int(row.get("id", "0") or 0) % len(templates)
        row["text"] = templates[variant_index].format(
            npc=npc_name,
            region=region,
            personality_hint=personality_hint,
        )

    _write_csv(DIALOGUES_PATH, dialogue_fields, dialogue_rows)
    print(DIALOGUES_PATH)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
