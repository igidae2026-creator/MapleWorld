from dataclasses import dataclass


@dataclass
class PlayerState:
    level: int
    mesos: int
    progression_stage: str
    play_style: str
    archetype: str
