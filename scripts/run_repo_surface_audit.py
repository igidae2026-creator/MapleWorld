from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT_DIR / "offline_ops" / "codex_state" / "governance"
STATUS_PATH = OUTPUT_DIR / "repo_surface_status.json"
LEDGER_PATH = OUTPUT_DIR / "repo_surface_history.jsonl"

ROOT_AUTHORITY_FILES = {
    "AGENTS.md",
    "CHECKLIST_LAYER1_목표조건.md",
    "CHECKLIST_LAYER2_모듈책임.md",
    "CHECKLIST_LAYER3_REPO매핑.md",
    "CHECKLIST_METHOD_패치.md",
    "DOCS_CANON.md",
    "GOAL.md",
    "METAOS_CONSTITUTION.md",
    "README.md",
    "UNIVERSAL_FINAL_THRESHOLD_BUNDLE.md",
}

SURFACE_GROUPS = {
    "runtime": ["msw_runtime", "shared_rules", "content_build"],
    "offline_control": ["offline_ops", "offline_ops/autonomy", "offline_ops/codex_state"],
    "evaluation": ["metrics_engine", "simulation_py", "simulation_lua", "tests"],
    "generation_and_execution": ["ai_evolution_offline", "scripts", "scripts/codex"],
    "data_and_design_graph": ["data", "data/design_graph", "data/balance", "data/liveops"],
    "documentation": ["docs/standards", "docs/guards", "docs/reference", "docs/legacy", "docs/operations"],
}

EXPECTED_DOC_PATHS = {
    "autonomy_target": "docs/standards/AUTONOMY_TARGET.md",
    "korean_player_feel": "docs/standards/KOREAN_PLAYER_FEEL_STANDARD.md",
    "documentation_map": "docs/standards/DOCUMENTATION_MAP.md",
    "autonomy_stack": "docs/operations/AUTONOMY_STACK.md",
    "ai_fun_guard": "docs/guards/AI_FUN_GUARD.md",
    "canon_lock": "docs/guards/CANON_LOCK.md",
    "gameplay_variance_rules": "docs/guards/GAMEPLAY_VARIANCE_RULES.md",
}

TRANSITIONAL_EXPECTATIONS = {
    "ops_is_prompt_only": ["ops/prompts", "ops/codex_state"],
    "msw_runtime_has_entry_state": ["msw_runtime/entry", "msw_runtime/state"],
    "offline_autonomy_has_event_queue_state": [
        "offline_ops/autonomy/event_log.py",
        "offline_ops/autonomy/job_queue.py",
        "offline_ops/autonomy/snapshots.py",
        "offline_ops/autonomy/supervisor.py",
    ],
}


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _exists(rel_path: str) -> bool:
    return (ROOT_DIR / rel_path).exists()


def build_status() -> dict[str, object]:
    root_markdown = sorted(path.name for path in ROOT_DIR.glob("*.md"))
    unexpected_root_markdown = [name for name in root_markdown if name not in ROOT_AUTHORITY_FILES]

    surface_groups = {
        name: {
            "paths": paths,
            "all_present": all(_exists(path) for path in paths),
        }
        for name, paths in SURFACE_GROUPS.items()
    }
    expected_docs = {
        name: {
            "path": rel_path,
            "present": _exists(rel_path),
        }
        for name, rel_path in EXPECTED_DOC_PATHS.items()
    }
    transitional = {
        name: {
            "paths": paths,
            "all_present": all(_exists(path) for path in paths),
        }
        for name, paths in TRANSITIONAL_EXPECTATIONS.items()
    }

    status = {
        "root_authority_surface_clean": len(unexpected_root_markdown) == 0,
        "surface_groups_present": all(item["all_present"] for item in surface_groups.values()),
        "document_buckets_present": all(item["present"] for item in expected_docs.values()),
        "transitional_boundaries_intact": all(item["all_present"] for item in transitional.values()),
    }

    payload = {
        "generated_at_utc": _utc_now(),
        "status": "pass" if all(status.values()) else "fail",
        "checks": status,
        "unexpected_root_markdown": unexpected_root_markdown,
        "surface_groups": surface_groups,
        "expected_docs": expected_docs,
        "transitional_boundaries": transitional,
    }
    return payload


def main() -> int:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    payload = build_status()
    STATUS_PATH.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    with LEDGER_PATH.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(payload, sort_keys=True) + "\n")
    print(STATUS_PATH)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
