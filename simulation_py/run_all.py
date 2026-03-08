from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parents[1]
SIM_DIR = ROOT_DIR / "simulation_py"
if str(SIM_DIR) not in sys.path:
    sys.path.insert(0, str(SIM_DIR))

from agents.party_grinder import PROFILE as PARTY_GRINDER
from agents.quest_player import PROFILE as QUEST_PLAYER
from agents.solo_grinder import PROFILE as SOLO_GRINDER
from economy_sim import run_economy
from player_model import PlayerState
from world_sim import run_world

OUTPUT_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs" / "python_simulation_latest.json"


def _stage_for_level(level: int) -> str:
    if level >= 70:
        return "late"
    if level >= 30:
        return "mid"
    return "early"


def _build_population() -> list[PlayerState]:
    profiles = [SOLO_GRINDER, PARTY_GRINDER, QUEST_PLAYER]
    levels = [14, 22, 31, 45, 58, 72]
    population: list[PlayerState] = []
    for index, level in enumerate(levels):
        profile = profiles[index % len(profiles)]
        mesos = 900 + (level * 75) + (index * 180)
        population.append(
            PlayerState(
                level=level,
                mesos=mesos,
                progression_stage=_stage_for_level(level),
                play_style=profile["play_style"],
            )
        )
    return population


def main() -> int:
    loops = 12
    population = _build_population()
    economy = run_economy(population, loops)
    world = run_world(population, loops)
    payload = {
        "generator": "simulation_py.run_all",
        "deterministic": True,
        "population_size": len(population),
        "economy": economy,
        "world": world,
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(OUTPUT_PATH)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
