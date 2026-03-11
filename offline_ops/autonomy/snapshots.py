from __future__ import annotations

import json
from datetime import datetime, timezone
from typing import Any

from .paths import STATE_DIR, ensure_layout


def _timestamp() -> str:
    return datetime.now(timezone.utc).isoformat()


def _snapshot_path(name: str):
    return STATE_DIR / f"{name}.json"


def write_snapshot(name: str, payload: dict[str, Any]) -> dict[str, Any]:
    ensure_layout()
    document = {
        "snapshot_type": name,
        "updated_at": _timestamp(),
        "payload": payload,
    }
    _snapshot_path(name).write_text(
        json.dumps(document, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    return document


def read_snapshot(name: str) -> dict[str, Any]:
    ensure_layout()
    path = _snapshot_path(name)
    if not path.exists():
        return {
            "snapshot_type": name,
            "updated_at": None,
            "payload": {},
        }
    return json.loads(path.read_text(encoding="utf-8"))
