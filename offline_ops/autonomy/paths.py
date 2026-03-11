from __future__ import annotations

from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[2]
AUTONOMY_DIR = ROOT_DIR / "offline_ops" / "autonomy"
STATE_DIR = AUTONOMY_DIR / "state"
JOBS_DIR = AUTONOMY_DIR / "jobs"
QUEUED_DIR = JOBS_DIR / "queued"
RUNNING_DIR = JOBS_DIR / "running"
DONE_DIR = JOBS_DIR / "done"
FAILED_DIR = JOBS_DIR / "failed"
EVENT_LOG_PATH = AUTONOMY_DIR / "events.jsonl"


def ensure_layout() -> None:
    for path in (
        AUTONOMY_DIR,
        STATE_DIR,
        JOBS_DIR,
        QUEUED_DIR,
        RUNNING_DIR,
        DONE_DIR,
        FAILED_DIR,
    ):
        path.mkdir(parents=True, exist_ok=True)
    if not EVENT_LOG_PATH.exists():
        EVENT_LOG_PATH.write_text("", encoding="utf-8")
