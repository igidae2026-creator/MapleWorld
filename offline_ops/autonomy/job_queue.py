from __future__ import annotations

import json
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .event_log import append_event
from .paths import DONE_DIR, FAILED_DIR, QUEUED_DIR, RUNNING_DIR, ensure_layout


def _timestamp() -> str:
    return datetime.now(timezone.utc).isoformat()


def _job_path(directory: Path, job_id: str) -> Path:
    return directory / f"{job_id}.json"


def _write_job(path: Path, payload: dict[str, Any]) -> None:
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def enqueue_job(job_type: str, payload: dict[str, Any], priority: int = 100) -> dict[str, Any]:
    ensure_layout()
    job_id = f"{job_type}-{uuid.uuid4().hex[:12]}"
    job = {
        "job_id": job_id,
        "job_type": job_type,
        "priority": priority,
        "status": "queued",
        "created_at": _timestamp(),
        "updated_at": _timestamp(),
        "attempts": 0,
        "payload": payload,
    }
    _write_job(_job_path(QUEUED_DIR, job_id), job)
    append_event("job_enqueued", {"job_id": job_id, "job_type": job_type, "priority": priority})
    return job


def list_jobs(status: str) -> list[dict[str, Any]]:
    ensure_layout()
    directory = {
        "queued": QUEUED_DIR,
        "running": RUNNING_DIR,
        "done": DONE_DIR,
        "failed": FAILED_DIR,
    }[status]
    jobs: list[dict[str, Any]] = []
    for path in sorted(directory.glob("*.json")):
        jobs.append(json.loads(path.read_text(encoding="utf-8")))
    return jobs


def claim_next_job(worker_id: str) -> dict[str, Any] | None:
    ensure_layout()
    queued = sorted(
        list_jobs("queued"),
        key=lambda job: (int(job.get("priority", 100)), str(job.get("created_at", "")), str(job["job_id"])),
    )
    if not queued:
        return None
    job = queued[0]
    queued_path = _job_path(QUEUED_DIR, str(job["job_id"]))
    running_path = _job_path(RUNNING_DIR, str(job["job_id"]))
    if not queued_path.exists():
        return None
    job["status"] = "running"
    job["worker_id"] = worker_id
    job["attempts"] = int(job.get("attempts", 0)) + 1
    job["updated_at"] = _timestamp()
    queued_path.unlink()
    _write_job(running_path, job)
    append_event("job_claimed", {"job_id": job["job_id"], "worker_id": worker_id})
    return job


def finish_job(job_id: str, outcome: str, result: dict[str, Any] | None = None) -> dict[str, Any]:
    ensure_layout()
    if outcome not in {"done", "failed"}:
        raise ValueError(f"unsupported outcome: {outcome}")
    running_path = _job_path(RUNNING_DIR, job_id)
    if not running_path.exists():
        raise FileNotFoundError(f"running job not found: {job_id}")
    job = json.loads(running_path.read_text(encoding="utf-8"))
    job["status"] = outcome
    job["updated_at"] = _timestamp()
    job["result"] = result or {}
    target_dir = DONE_DIR if outcome == "done" else FAILED_DIR
    running_path.unlink()
    _write_job(_job_path(target_dir, job_id), job)
    append_event(f"job_{outcome}", {"job_id": job_id, "result": job["result"]})
    return job
