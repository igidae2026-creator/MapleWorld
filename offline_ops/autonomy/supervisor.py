from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

from .event_log import append_event, read_recent_events
from .job_queue import claim_next_job, enqueue_job, finish_job, list_jobs
from .paths import ensure_layout
from .policy import classify_material
from .snapshots import read_snapshot, write_snapshot

ROOT_DIR = Path(__file__).resolve().parents[2]
DESIGN_GRAPH_DIR = ROOT_DIR / "data" / "design_graph"
DESIGN_GRAPH_INDEX_PATH = DESIGN_GRAPH_DIR / "index.json"
DESIGN_GRAPH_MANIFEST_PATH = DESIGN_GRAPH_DIR / "manifest.json"
EXTERNAL_AUTONOMY_SHARD_PATH = DESIGN_GRAPH_DIR / "external_material_autonomy.json"
FINAL_THRESHOLD_REPAIRS_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "final_threshold_repairs.jsonl"
P0_QUEUE_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "p0_queue.txt"


def _read_json(path: Path, default: Any) -> Any:
    if not path.exists():
        return default
    return json.loads(path.read_text(encoding="utf-8"))


def _write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def _normalize_material_path(path: str) -> str:
    candidate = Path(path)
    try:
        if candidate.is_absolute():
            return candidate.resolve().relative_to(ROOT_DIR.resolve()).as_posix()
    except Exception:
        return candidate.as_posix()
    return candidate.as_posix().lstrip("./")


def _material_node_id(normalized_path: str) -> str:
    digest = hashlib.sha1(normalized_path.encode("utf-8")).hexdigest()[:12]
    slug = "".join(char if char.isalnum() else "_" for char in normalized_path).strip("_")
    slug = slug[:64] or "material"
    return f"external_material_autonomy.{slug}.{digest}"


def _should_promote(scope_fit: str, authority_fit: str, upgrade_value: str, action: str) -> bool:
    if action == "promote":
        return True
    return (
        scope_fit in {"governance", "implementation"}
        and authority_fit in {"top", "repo"}
        and upgrade_value in {"medium", "high"}
    )


def _update_external_intake_snapshot(
    *,
    last_promoted_material: str | None = None,
    last_rejected_material: str | None = None,
    pending_delta: int = 0,
) -> dict[str, Any]:
    current = read_snapshot("external_intake").get("payload", {})
    pending = max(0, int(current.get("pending_candidates", 0)) + pending_delta)
    payload = {
        "pending_candidates": pending,
        "last_promoted_material": last_promoted_material
        if last_promoted_material is not None
        else current.get("last_promoted_material"),
        "last_rejected_material": last_rejected_material
        if last_rejected_material is not None
        else current.get("last_rejected_material"),
        "promoted_count": int(current.get("promoted_count", 0)),
        "rejected_count": int(current.get("rejected_count", 0)),
    }
    if last_promoted_material is not None:
        payload["promoted_count"] += 1
    if last_rejected_material is not None:
        payload["rejected_count"] += 1
    return write_snapshot("external_intake", payload)


def _promote_material(payload: dict[str, Any]) -> dict[str, Any]:
    normalized_path = _normalize_material_path(str(payload["path"]))
    DESIGN_GRAPH_DIR.mkdir(parents=True, exist_ok=True)

    node_id = _material_node_id(normalized_path)
    shard = _read_json(
        EXTERNAL_AUTONOMY_SHARD_PATH,
        {
            "domain": "external_material_autonomy",
            "nodes": [
                {
                    "id": "external_material_autonomy",
                    "layer": 1,
                    "domain": "external_material_autonomy",
                }
            ],
        },
    )
    nodes = list(shard.get("nodes", []))
    if not any(node.get("id") == "external_material_autonomy" for node in nodes):
        nodes.insert(
            0,
            {
                "id": "external_material_autonomy",
                "layer": 1,
                "domain": "external_material_autonomy",
            },
        )
    material_node = {
        "id": node_id,
        "layer": 2,
        "parent": "external_material_autonomy",
        "domain": "external_material_autonomy",
        "material_path": normalized_path,
        "scope_fit": payload["scope_fit"],
        "authority_fit": payload["authority_fit"],
        "upgrade_value": payload["upgrade_value"],
        "reason": payload["reason"],
        "source_job_type": payload.get("source_job_type", "classify_external_material"),
        "promotion_state": "promoted",
    }
    existing_idx = next((idx for idx, node in enumerate(nodes) if node.get("id") == node_id), None)
    if existing_idx is None:
        nodes.append(material_node)
    else:
        nodes[existing_idx] = {**nodes[existing_idx], **material_node}
    shard["domain"] = "external_material_autonomy"
    shard["nodes"] = nodes
    _write_json(EXTERNAL_AUTONOMY_SHARD_PATH, shard)

    index_payload = _read_json(DESIGN_GRAPH_INDEX_PATH, {"index": {}})
    index = dict(index_payload.get("index", {}))
    index["external_material_autonomy"] = True
    index[node_id] = True
    index_payload["index"] = index
    _write_json(DESIGN_GRAPH_INDEX_PATH, index_payload)

    manifest = _read_json(
        DESIGN_GRAPH_MANIFEST_PATH,
        {"node_count": 0, "frontier_count": 0, "max_layer": 0, "domains": [], "shards": []},
    )
    domains = sorted(set(str(domain) for domain in manifest.get("domains", [])) | {"external_material_autonomy"})
    manifest["domains"] = domains
    manifest["max_layer"] = max(int(manifest.get("max_layer", 0)), 2)
    shard_count = len(nodes)
    shards = [entry for entry in manifest.get("shards", []) if entry.get("domain") != "external_material_autonomy"]
    shards.append(
        {
            "domain": "external_material_autonomy",
            "path": "data/design_graph/external_material_autonomy.json",
            "count": shard_count,
        }
    )
    manifest["shards"] = sorted(shards, key=lambda entry: str(entry.get("domain", "")))
    manifest["node_count"] = max(int(manifest.get("node_count", 0)), shard_count)
    manifest["frontier_count"] = max(int(manifest.get("frontier_count", 0)), max(0, shard_count - 1))
    _write_json(DESIGN_GRAPH_MANIFEST_PATH, manifest)

    _update_external_intake_snapshot(last_promoted_material=normalized_path, pending_delta=-1)
    append_event(
        "material_promoted",
        {
            "path": normalized_path,
            "node_id": node_id,
            "scope_fit": payload["scope_fit"],
            "authority_fit": payload["authority_fit"],
            "upgrade_value": payload["upgrade_value"],
        },
    )
    return {
        "path": normalized_path,
        "node_id": node_id,
        "shard_path": str(EXTERNAL_AUTONOMY_SHARD_PATH.relative_to(ROOT_DIR)),
    }


def _append_final_threshold_repair(payload: dict[str, Any]) -> dict[str, Any]:
    record = {
        "criterion": str(payload.get("criterion", "")).strip(),
        "repair_action": str(payload.get("repair_action", "")).strip(),
    }
    FINAL_THRESHOLD_REPAIRS_PATH.parent.mkdir(parents=True, exist_ok=True)
    with FINAL_THRESHOLD_REPAIRS_PATH.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(record, sort_keys=True) + "\n")
    queue_line = f"[ ] FINAL-{record['criterion']} {record['repair_action']}"
    existing = P0_QUEUE_PATH.read_text(encoding="utf-8") if P0_QUEUE_PATH.exists() else ""
    if queue_line not in existing:
        with P0_QUEUE_PATH.open("a", encoding="utf-8") as handle:
            if existing and not existing.endswith("\n"):
                handle.write("\n")
            handle.write(queue_line + "\n")
    append_event("final_threshold_repair_registered", record)
    write_snapshot(
        "system_health",
        {
            "status": "repairing_final_threshold",
            "last_error": None,
            "regression_budget_remaining": 3,
            "active_repair_criterion": record["criterion"],
        },
    )
    return record


def bootstrap() -> None:
    ensure_layout()
    write_snapshot(
        "system_health",
        {
            "status": "idle",
            "last_error": None,
            "regression_budget_remaining": 3,
        },
    )
    write_snapshot(
        "active_bottleneck",
        {
            "bottleneck_key": "economy_coherence",
            "source": "bootstrap_default",
            "confidence": "unknown",
        },
    )
    write_snapshot(
        "external_intake",
        {
            "pending_candidates": 0,
            "last_promoted_material": None,
            "last_rejected_material": None,
            "promoted_count": 0,
            "rejected_count": 0,
        },
    )
    append_event("autonomy_bootstrap", {"status": "ok"})


def status() -> dict[str, Any]:
    ensure_layout()
    return {
        "system_health": read_snapshot("system_health"),
        "active_bottleneck": read_snapshot("active_bottleneck"),
        "external_intake": read_snapshot("external_intake"),
        "queued_jobs": list_jobs("queued"),
        "running_jobs": list_jobs("running"),
        "recent_events": read_recent_events(limit=10),
    }


def ingest_material(path: str) -> dict[str, Any]:
    decision = classify_material(path)
    normalized_path = _normalize_material_path(path)
    payload = {
        "path": normalized_path,
        "scope_fit": decision.scope_fit,
        "authority_fit": decision.authority_fit,
        "upgrade_value": decision.upgrade_value,
        "recommended_action": decision.action,
        "reason": decision.reason,
    }
    append_event("material_classified", payload)
    if decision.action in {"promote", "queue_review"}:
        job = enqueue_job("classify_external_material", payload, priority=40 if decision.action == "promote" else 70)
        _update_external_intake_snapshot(pending_delta=1)
        return {"decision": decision.action, "job": job}
    _update_external_intake_snapshot(last_rejected_material=normalized_path)
    return {"decision": decision.action, "payload": payload}


def run_once(worker_id: str = "supervisor") -> dict[str, Any]:
    ensure_layout()
    job = claim_next_job(worker_id=worker_id)
    if not job:
        write_snapshot("system_health", {"status": "idle", "last_error": None, "regression_budget_remaining": 3})
        return {"status": "idle"}

    result = {
        "handled_job_type": job["job_type"],
        "job_id": job["job_id"],
    }
    if job["job_type"] == "classify_external_material":
        payload = dict(job.get("payload", {}))
        payload["source_job_type"] = job["job_type"]
        if _should_promote(
            str(payload.get("scope_fit", "")),
            str(payload.get("authority_fit", "")),
            str(payload.get("upgrade_value", "")),
            str(payload.get("recommended_action", "")),
        ):
            promoted = _promote_material(payload)
            result["next_action"] = "promoted_to_design_graph"
            result["promotion"] = promoted
        else:
            normalized_path = _normalize_material_path(str(payload.get("path", "")))
            _update_external_intake_snapshot(last_rejected_material=normalized_path, pending_delta=-1)
            append_event(
                "material_rejected",
                {
                    "path": normalized_path,
                    "scope_fit": payload.get("scope_fit"),
                    "authority_fit": payload.get("authority_fit"),
                    "upgrade_value": payload.get("upgrade_value"),
                },
            )
            result["next_action"] = "rejected_after_policy"
        finish_job(str(job["job_id"]), "done", result)
    elif job["job_type"] == "repair_final_threshold_gap":
        payload = dict(job.get("payload", {}))
        result["repair"] = _append_final_threshold_repair(payload)
        result["next_action"] = "queued_final_threshold_repair"
        finish_job(str(job["job_id"]), "done", result)
    else:
        result["next_action"] = "unhandled_job_type"
        finish_job(str(job["job_id"]), "failed", result)
    write_snapshot("system_health", {"status": "active", "last_error": None, "regression_budget_remaining": 3})
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description="MapleWorld autonomy supervisor skeleton")
    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser("bootstrap", help="create autonomy layout and baseline snapshots")
    subparsers.add_parser("status", help="print current autonomy status")

    ingest_parser = subparsers.add_parser("ingest", help="classify and queue an external material")
    ingest_parser.add_argument("path", help="material path or identifier")

    run_once_parser = subparsers.add_parser("run-once", help="claim and process one queued job")
    run_once_parser.add_argument("--worker-id", default="supervisor", help="worker identifier")

    args = parser.parse_args()

    if args.command == "bootstrap":
        bootstrap()
        print(json.dumps({"status": "ok", "action": "bootstrap"}, indent=2, sort_keys=True))
        return 0
    if args.command == "status":
        print(json.dumps(status(), indent=2, sort_keys=True))
        return 0
    if args.command == "ingest":
        print(json.dumps(ingest_material(args.path), indent=2, sort_keys=True))
        return 0
    if args.command == "run-once":
        print(json.dumps(run_once(worker_id=args.worker_id), indent=2, sort_keys=True))
        return 0
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
