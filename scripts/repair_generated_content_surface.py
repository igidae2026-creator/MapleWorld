from __future__ import annotations

import csv
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
NPCS_PATH = ROOT_DIR / "data" / "npcs.csv"
DIALOGUES_PATH = ROOT_DIR / "data" / "dialogues.csv"
QUESTS_PATH = ROOT_DIR / "data" / "quests.csv"

HANGUL_CHARS = tuple("가나다라마바사아자차카타파하거너더러머버서어저처커터퍼호")
PLACEHOLDER_TOKENS = (
    "dbexp_",
    "points toward",
    "warns about",
    "quest_offer",
    "quest_progress",
    "quest_complete",
    "region_hint",
    "boss_rumor",
    "starter fields",
    "campaign",
    "onboarding",
)

REGION_LABELS = {
    "starter_fields": "시작 들판",
    "henesys_plains": "헤네시스 평원",
    "ellinia_forest": "엘리니아 숲길",
    "perion_rocklands": "페리온 바위능선",
    "kerning_city_shadow": "커닝시티 뒷골목",
    "sleepywood_depths": "슬리피우드 심층",
    "ancient_hidden_domains": "고대 숨겨진 터",
    "coastal_harbors": "해안 항구지대",
    "elnath_snowfield": "엘나스 설원",
    "ludibrium_clockwork": "루디브리엄 시계구역",
    "minar_mountain": "미나르 산맥",
    "orbis_skyrealm": "오르비스 하늘길",
}

ROLE_NAME_POOLS = {
    "shopkeeper": ["도윤", "미라", "상구", "주희", "해성", "서윤", "태오", "소명", "민석", "예린"],
    "questgiver": ["이안", "하린", "도현", "나래", "유찬", "다온", "선우", "채은", "기람", "세린"],
    "townfolk": ["복남", "정희", "순덕", "동팔", "가람", "유라", "명진", "나영", "철수", "보라"],
    "traveler": ["도란", "지후", "연호", "태린", "해담", "소율", "무진", "가온", "연우", "시온"],
    "guard": ["강혁", "태건", "민호", "수호", "준서", "도겸", "선율", "지안", "현욱", "재인"],
    "scholar": ["서하", "유진", "로아", "현설", "지담", "은재", "도은", "새봄", "하율", "문결"],
    "smith": ["담철", "무석", "현강", "온유", "우빈", "진호", "단비", "은솔", "기태", "라온"],
    "ferryman": ["창호", "연수", "범수", "해진", "윤태", "마루", "시후", "하늘", "단우", "재하"],
    "guide": ["루아", "시아", "도하", "하람", "연지", "수인", "태율", "다인", "이든", "하준"],
    "hidden_story": ["수상한 노인", "낡은 전령", "그늘의 목격자", "숨은 기록관", "새벽의 전갈", "남겨진 탐색자"],
}

ROLE_TITLES = {
    "shopkeeper": "잡화상",
    "questgiver": "의뢰인",
    "townfolk": "주민",
    "traveler": "길손",
    "guard": "경비병",
    "scholar": "학자",
    "smith": "대장장이",
    "ferryman": "나룻배지기",
    "guide": "안내인",
    "hidden_story": "수상한 인물",
}

ROLE_TRAITS = {
    "shopkeeper": "물약값과 귀환 타이밍을 먼저 따진다.",
    "questgiver": "사람을 시키기 전에 길이 얼마나 험한지 꼭 확인한다.",
    "townfolk": "사냥꾼 발걸음만 봐도 오늘 흐름이 좋은지 읽어낸다.",
    "traveler": "길의 위험을 과장하지 않지만 욕심 많은 초심자는 바로 알아본다.",
    "guard": "안전을 중시하지만 겁만 주는 타입은 아니다.",
    "scholar": "몬스터 습성과 드랍 흐름을 기록으로 남긴다.",
    "smith": "장비보다 손에 익은 리듬이 먼저라고 믿는다.",
    "ferryman": "돌아오는 길이 끊기면 사냥 기세도 함께 끊긴다고 본다.",
    "guide": "처음 온 사람도 길을 잃지 않게 짧고 분명하게 설명한다.",
    "hidden_story": "다들 놓치는 징후를 오래 기억하고 있다.",
}

DIALOGUE_OPENERS = {
    "greeting": "{npc}이 손짓했다. {region} 쪽은 서두를수록 물약이 먼저 바닥난다.",
    "region_hint": "{map_label}로 가기 전에 발판 간격부터 익혀. 여기선 길을 아는 사람이 오래 버틴다.",
    "quest_offer": "할 일 하나 맡길까. {region} 초입이 조용한 날이 더 위험할 때가 있다.",
    "quest_progress": "서두르지 마. 숫자보다 흐름을 익히는 쪽이 다음 사냥을 편하게 만든다.",
    "quest_complete": "좋아. 이제 손이 좀 풀렸겠지. 이 정도 리듬이면 더 안쪽도 버틸 만하다.",
    "lore": "{region} 사람들은 오래전부터 귀환 타이밍을 놓치면 사냥보다 회복비가 더 무섭다고 말했다.",
    "boss_rumor": "우두머리는 늘 크게 티 내며 오지 않는다. 조용해질 때가 오히려 신호다.",
    "shop": "물약과 귀환서는 아끼되 끊기진 마. 욕심내다 한 번 쓰러지면 오늘 번 메소가 다 날아간다.",
    "warning": "{map_label}에선 한 번 꼬이면 몰려온다. 무리해서 한 무더기씩 끌지 마.",
}

QUEST_NAME_PATTERNS = {
    "collection": ["흩어진 징표 수습", "빠진 보급 자루", "젖은 재료 꾸러미", "남겨진 흔적 모으기"],
    "boss": ["길목을 막은 우두머리", "무너진 경계의 주인", "조용해진 길의 징조", "귀환길을 끊은 놈"],
    "delivery": ["늦기 전에 전할 말", "돌아오는 길의 부탁", "초입 보급 전달", "경계선 소식 전하기"],
    "mixed": ["초입 정리와 표식 회수", "사냥 흔적 정돈", "엉킨 길목 수습", "발판 아래 정리"],
}


def _read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def _write_csv(path: Path, rows: list[dict[str, str]], fieldnames: list[str]) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def _has_hangul(text: str) -> bool:
    return any(ch in text for ch in HANGUL_CHARS)


def _needs_rewrite(text: str) -> bool:
    lowered = text.lower()
    return any(token in lowered for token in PLACEHOLDER_TOKENS) or not _has_hangul(text)


def _region_label(region: str) -> str:
    return REGION_LABELS.get(region, region.replace("_", " "))


def _map_label(map_name: str) -> str:
    if map_name == "forest_edge":
        return "숲 가장자리"
    for marker, suffix in (("_town_", "마을"), ("_combat_", "사냥터"), ("_hidden_", "숨은길")):
        if marker in map_name:
            prefix, tail = map_name.split(marker, 1)
            return f"{_region_label(prefix)} {suffix} {tail}"
    return map_name.replace("_", " ")


def _name_for(role: str, numeric_id: int) -> str:
    pool = ROLE_NAME_POOLS.get(role, ["이름없는 사람"])
    base = pool[(numeric_id - 1) % len(pool)]
    title = ROLE_TITLES.get(role, "주민")
    if role == "hidden_story":
        return base
    return f"{base} {title}"


def _stable_number(text: str) -> int:
    try:
        return int(text)
    except ValueError:
        return sum(ord(ch) for ch in text)


def _classify_quest(row: dict[str, str]) -> str:
    objectives = str(row.get("objectives", ""))
    lower_name = str(row.get("name", "")).lower()
    if ":1" in objectives and "boss" in objectives:
        return "boss"
    if "delivery" in lower_name:
        return "delivery"
    if "collect:" in objectives and "kill:" not in objectives:
        return "collection"
    return "mixed"


def repair_npcs() -> dict[str, tuple[str, str, str, str]]:
    rows = _read_csv(NPCS_PATH)
    fieldnames = list(rows[0].keys())
    npc_meta: dict[str, tuple[str, str, str, str]] = {}
    for row in rows:
        npc_id = _stable_number(row["id"])
        role = row["role"]
        region = row["region"]
        map_name = row["map_name"]
        if _needs_rewrite(row["name"]) or _needs_rewrite(row.get("personality", "")):
            row["name"] = _name_for(role, npc_id)
            row["personality"] = f"{_region_label(region)}에서 오래 버틴 {ROLE_TITLES.get(role, '주민')}이다. {ROLE_TRAITS.get(role, '길의 흐름을 읽는다.')}"
        npc_meta[row["id"]] = (row["name"], role, region, map_name)
    _write_csv(NPCS_PATH, rows, fieldnames)
    return npc_meta


def repair_dialogues(npc_meta: dict[str, tuple[str, str, str, str]]) -> None:
    rows = _read_csv(DIALOGUES_PATH)
    fieldnames = list(rows[0].keys())
    for row in rows:
        base_text = str(row.get("text", ""))
        if not _needs_rewrite(base_text):
            continue
        npc_name, _, region, _ = npc_meta.get(row["npc_id"], ("이방인", "townfolk", "starter_fields", row["map_name"]))
        region_label = _region_label(region)
        map_label = _map_label(row["map_name"])
        dialogue_type = row.get("dialogue_type", "greeting")
        template = DIALOGUE_OPENERS.get(dialogue_type, "{npc}이 낮게 말했다. {region}은 익숙해질수록 더 욕심을 부르게 된다.")
        row["text"] = template.format(npc=npc_name, region=region_label, map_label=map_label)
    _write_csv(DIALOGUES_PATH, rows, fieldnames)


def repair_quests(npc_meta: dict[str, tuple[str, str, str, str]]) -> None:
    rows = _read_csv(QUESTS_PATH)
    fieldnames = list(rows[0].keys())
    for idx, row in enumerate(rows, start=1):
        name = str(row.get("name", ""))
        narrative = str(row.get("narrative", ""))
        guidance = str(row.get("guidance", ""))
        reward_summary = str(row.get("reward_summary", ""))
        if not any(_needs_rewrite(text) for text in (name, narrative, guidance, reward_summary)):
            continue
        quest_type = _classify_quest(row)
        start_npc = row.get("start_npc", "")
        npc_name, _, region, map_name = npc_meta.get(start_npc, ("마을 사람", "townfolk", "starter_fields", "starter_fields_town_01"))
        region_label = _region_label(region)
        map_label = _map_label(map_name)
        pattern_pool = QUEST_NAME_PATTERNS[quest_type]
        quest_no = idx % 100
        row["name"] = f"{region_label} {pattern_pool[(idx - 1) % len(pattern_pool)]}"
        row["narrative"] = f"{npc_name}은 {region_label} 초입의 흐름을 바로잡기 위해 사냥 흔적과 남겨진 재료를 정리해 달라고 부탁한다."
        row["reward_summary"] = f"{region_label} 다음 구간으로 넘어가기 전 필요한 메소와 물약 여유를 챙길 수 있다."
        row["guidance"] = f"{map_label} 쪽에서 무리하게 끌지 말고 목표만 채운 뒤 바로 돌아와 보고해."
    _write_csv(QUESTS_PATH, rows, fieldnames)


def main() -> int:
    npc_meta = repair_npcs()
    repair_dialogues(npc_meta)
    repair_quests(npc_meta)
    print("repaired generated content surface")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
