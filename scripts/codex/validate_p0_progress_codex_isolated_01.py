#!/usr/bin/env python3
import json
import sys
from pathlib import Path

p = Path.home() / "MapleWorld" / "ops" / "codex_state" / "p0_prog_codex_isolated_01.json"

try:
    data = json.loads(p.read_text(encoding="utf-8"))
except Exception as e:
    print(f"INVALID_JSON: {e}")
    sys.exit(2)

required = [
    "goal",
    "total_items",
    "completed_items",
    "completed_runs",
    "items",
]

missing = [k for k in required if k not in data]
if missing:
    print("MISSING_KEYS:" + ",".join(missing))
    sys.exit(3)

if not isinstance(data["items"], list):
    print("INVALID_TYPE: items")
    sys.exit(4)

if int(data["total_items"]) != 52:
    print("INVALID_TOTAL_ITEMS")
    sys.exit(5)

if len(data["items"]) != 52:
    print("INVALID_ITEM_COUNT")
    sys.exit(6)

allowed_status = {"pending", "in_progress", "complete"}
required_item_keys = {
    "id",
    "key",
    "tier",
    "status",
    "completion_percent",
    "last_touched_files",
    "notes",
}

completed = 0
for index, item in enumerate(data["items"], start=1):
    if not isinstance(item, dict):
        print(f"INVALID_ITEM_TYPE:{index}")
        sys.exit(7)
    missing_item_keys = sorted(required_item_keys - set(item))
    if missing_item_keys:
        print(f"MISSING_ITEM_KEYS:{index}:{','.join(missing_item_keys)}")
        sys.exit(8)
    if item["status"] not in allowed_status:
        print(f"INVALID_STATUS:{index}:{item['status']}")
        sys.exit(9)
    if not isinstance(item["last_touched_files"], list):
        print(f"INVALID_LAST_TOUCHED_FILES:{index}")
        sys.exit(10)
    if item["status"] == "complete":
        completed += 1

remaining = len(data["items"]) - completed
print(remaining)
