from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path


TOP_AUTHORITY = {
    "GOAL.md",
    "METAOS_CONSTITUTION.md",
    "RULE_CARDS.jsonl",
    "CHECKLIST_LAYER1_목표조건.md",
    "CHECKLIST_LAYER2_모듈책임.md",
    "CHECKLIST_LAYER3_REPO매핑.md",
    "CHECKLIST_METHOD_패치.md",
    "COVERAGE_AUDIT.csv",
    "CONFLICT_LOG.csv",
}


@dataclass(frozen=True)
class MaterialDecision:
    scope_fit: str
    authority_fit: str
    upgrade_value: str
    action: str
    reason: str


def classify_material(path: str) -> MaterialDecision:
    raw_path = Path(path)
    name = raw_path.name
    suffix = raw_path.suffix.lower()
    normalized = path.replace("\\", "/").lstrip("./")

    if name in TOP_AUTHORITY:
        return MaterialDecision(
            scope_fit="governance",
            authority_fit="top",
            upgrade_value="high",
            action="promote",
            reason="matches top-authority surface",
        )

    if (
        normalized.startswith("data/")
        or normalized.startswith("shared_rules/")
        or normalized.startswith("scripts/")
        or normalized.startswith("metrics_engine/")
        or normalized.startswith("tests/")
    ):
        return MaterialDecision(
            scope_fit="implementation",
            authority_fit="repo",
            upgrade_value="medium",
            action="queue_review",
            reason="implementation-facing material inside governed execution scope",
        )

    if suffix in {".md", ".txt", ".csv", ".json", ".jsonl"}:
        return MaterialDecision(
            scope_fit="candidate",
            authority_fit="unknown",
            upgrade_value="unknown",
            action="queue_review",
            reason="textual or structured material requires scoped review",
        )

    return MaterialDecision(
        scope_fit="unknown",
        authority_fit="unknown",
        upgrade_value="low",
        action="reject",
        reason="material does not match a governed intake surface",
    )
