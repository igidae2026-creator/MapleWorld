from __future__ import annotations

import json
import os
import sys
import tempfile
import time
from pathlib import Path

THIS_DIR = Path(__file__).resolve().parent
if str(THIS_DIR) not in sys.path:
    sys.path.insert(0, str(THIS_DIR))

try:
    from .economy_pressure_metrics import write_economy_pressure_metrics
    from .expansion_metrics import write_expansion_metrics
    from .fun_guard_metrics import write_fun_guard_metrics
    from .player_experience_metrics import write_player_experience_metrics
    from .quality_metrics import build_quality_metrics
    from .channel_routing_metrics import write_channel_routing_metrics
    from .checkpoint_stability import write_checkpoint_stability
    from .liveops_override_metrics import write_liveops_override_metrics
    from .world_graph_metrics import write_world_graph_metrics
except ImportError:
    from economy_pressure_metrics import write_economy_pressure_metrics
    from expansion_metrics import write_expansion_metrics
    from fun_guard_metrics import write_fun_guard_metrics
    from player_experience_metrics import write_player_experience_metrics
    from quality_metrics import build_quality_metrics
    from channel_routing_metrics import write_channel_routing_metrics
    from checkpoint_stability import write_checkpoint_stability
    from liveops_override_metrics import write_liveops_override_metrics
    from world_graph_metrics import write_world_graph_metrics

ROOT_DIR = Path(__file__).resolve().parents[1]
RUNS_DIR = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs"
LUA_PATH = RUNS_DIR / "lua_simulation_latest.json"
PYTHON_PATH = RUNS_DIR / "python_simulation_latest.json"
OUTPUT_PATH = RUNS_DIR / "quality_metrics_latest.json"
FUN_GUARD_OUTPUT_PATH = RUNS_DIR / "fun_guard_metrics_latest.json"
EXPANSION_OUTPUT_PATH = RUNS_DIR / "expansion_metrics_latest.json"
WORLD_GRAPH_OUTPUT_PATH = RUNS_DIR / "world_graph_metrics_latest.json"
CHANNEL_ROUTING_OUTPUT_PATH = RUNS_DIR / "channel_routing_metrics_latest.json"
ECONOMY_PRESSURE_OUTPUT_PATH = RUNS_DIR / "economy_pressure_metrics_latest.json"
LIVEOPS_OVERRIDE_OUTPUT_PATH = RUNS_DIR / "liveops_override_metrics_latest.json"
CHECKPOINT_STABILITY_OUTPUT_PATH = RUNS_DIR / "checkpoint_stability_latest.json"
PLAYER_EXPERIENCE_OUTPUT_PATH = RUNS_DIR / "player_experience_metrics_latest.json"


def _read_json_with_retries(path: Path, attempts: int = 5, delay_seconds: float = 0.2) -> dict[str, object]:
    last_error: json.JSONDecodeError | None = None
    for attempt in range(attempts):
        try:
            return json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as error:
            last_error = error
            if attempt == attempts - 1:
                break
            time.sleep(delay_seconds)
    if last_error is not None:
        raise last_error
    return {}


def _atomic_write_json(path: Path, payload: dict[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", delete=False, dir=path.parent, encoding="utf-8") as handle:
        handle.write(json.dumps(payload, indent=2, sort_keys=True) + "\n")
        temp_path = Path(handle.name)
    os.replace(temp_path, path)


def main() -> int:
    lua_data = _read_json_with_retries(LUA_PATH)
    python_data = _read_json_with_retries(PYTHON_PATH)
    payload = build_quality_metrics(lua_data, python_data)
    _atomic_write_json(OUTPUT_PATH, payload)
    fun_guard = write_fun_guard_metrics(output_path=FUN_GUARD_OUTPUT_PATH)
    expansion = write_expansion_metrics(python_data=python_data, output_path=EXPANSION_OUTPUT_PATH)
    world_graph = write_world_graph_metrics(python_data=python_data, output_path=WORLD_GRAPH_OUTPUT_PATH)
    channel_routing = write_channel_routing_metrics(python_data=python_data, output_path=CHANNEL_ROUTING_OUTPUT_PATH)
    economy_pressure = write_economy_pressure_metrics(python_data=python_data, output_path=ECONOMY_PRESSURE_OUTPUT_PATH)
    liveops_override = write_liveops_override_metrics(
        python_data=python_data,
        economy_metrics=economy_pressure,
        routing_metrics=channel_routing,
        output_path=LIVEOPS_OVERRIDE_OUTPUT_PATH,
    )
    write_checkpoint_stability(
        quality=payload,
        fun_guard=fun_guard,
        expansion=expansion,
        world_graph=world_graph,
        channel_routing=channel_routing,
        economy_pressure=economy_pressure,
        liveops_override=liveops_override,
        output_path=CHECKPOINT_STABILITY_OUTPUT_PATH,
    )
    checkpoint = json.loads(CHECKPOINT_STABILITY_OUTPUT_PATH.read_text(encoding="utf-8"))
    player_experience = write_player_experience_metrics(
        quality=payload,
        fun_guard=fun_guard,
        routing=channel_routing,
        economy=economy_pressure,
        liveops=liveops_override,
        checkpoint=checkpoint,
        output_path=PLAYER_EXPERIENCE_OUTPUT_PATH,
        python_data=python_data,
    )
    payload.update(
        {
            "first_10_minutes": player_experience["ranges"]["first_10_minutes"],
            "first_hour_retention": player_experience["ranges"]["first_hour_retention"],
            "day1_return_intent": player_experience["ranges"]["day1_return_intent"],
            "active_player_bottleneck": player_experience["active_player_bottleneck"],
            "overall_player_experience_floor": player_experience["overall_player_experience_floor"],
        }
    )
    _atomic_write_json(OUTPUT_PATH, payload)
    print(OUTPUT_PATH)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
