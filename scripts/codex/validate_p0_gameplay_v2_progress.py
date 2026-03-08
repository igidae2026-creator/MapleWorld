#!/usr/bin/env python3
import json
import sys
from pathlib import Path

p = Path.home() / "MapleWorld" / "ops" / "codex_state" / "p0_gameplay_v2_progress.json"

try:
    data = json.loads(p.read_text(encoding="utf-8"))
except Exception as e:
    print(f"INVALID_JSON: {e}")
    sys.exit(2)

required = [
    "completed_targets",
    "remaining_targets",
    "current_blocker",
    "last_cycle_summary",
    "regression_risk",
    "next_priority_candidates",
]

missing = [k for k in required if k not in data]
if missing:
    print("MISSING_KEYS:" + ",".join(missing))
    sys.exit(3)

if not isinstance(data["completed_targets"], list):
    print("INVALID_TYPE: completed_targets")
    sys.exit(4)

if not isinstance(data["remaining_targets"], list):
    print("INVALID_TYPE: remaining_targets")
    sys.exit(5)

if not isinstance(data["next_priority_candidates"], list):
    print("INVALID_TYPE: next_priority_candidates")
    sys.exit(6)

print(len(data["remaining_targets"]))
