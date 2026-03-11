from __future__ import annotations

import json
from datetime import datetime, timezone
from typing import Any

from .paths import EVENT_LOG_PATH, ensure_layout


def _timestamp() -> str:
    return datetime.now(timezone.utc).isoformat()


def append_event(event_type: str, payload: dict[str, Any]) -> dict[str, Any]:
    ensure_layout()
    event = {
        "ts": _timestamp(),
        "event_type": event_type,
        "payload": payload,
    }
    with EVENT_LOG_PATH.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(event, sort_keys=True) + "\n")
    return event


def read_recent_events(limit: int = 20) -> list[dict[str, Any]]:
    ensure_layout()
    if limit <= 0:
        return []
    lines = EVENT_LOG_PATH.read_text(encoding="utf-8").splitlines()
    events: list[dict[str, Any]] = []
    for line in lines[-limit:]:
        line = line.strip()
        if not line:
            continue
        events.append(json.loads(line))
    return events
