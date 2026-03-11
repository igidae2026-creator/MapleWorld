from __future__ import annotations

import json
import shutil
from datetime import datetime, timezone
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
THRESHOLD_DIR = ROOT_DIR / "offline_ops" / "codex_state" / "thresholds"
AUX_DIR = THRESHOLD_DIR / "metaos_aux"
SNAPSHOT_DIR = AUX_DIR / "latest"
HISTORY_PATH = AUX_DIR / "snapshot_history.jsonl"

SOURCE_CANDIDATES = [
    Path("/tmp/metaos_threshold_autonomy_clean"),
    Path("/tmp/metaos_threshold_autonomy_live"),
    Path("/tmp/metaos_threshold_autonomy"),
    Path("/tmp/metaos_threshold_autonomy_clean_dev5"),
    Path("/tmp/metaos_threshold_autonomy_clean_dev4"),
    Path("/tmp/metaos_threshold_autonomy_clean_dev3"),
    Path("/tmp/metaos_threshold_autonomy_clean_dev2"),
    Path("/tmp/metaos_threshold_autonomy_clean_dev"),
]

REQUIRED_FILES = ("latest_status.json", "long_soak_report.json", "regression_watch.json")


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _pick_source_dir() -> Path | None:
    for candidate in SOURCE_CANDIDATES:
        if all((candidate / name).exists() for name in REQUIRED_FILES):
            return candidate
    return None


def main() -> int:
    source_dir = _pick_source_dir()
    if source_dir is None:
        print("no metaos aux source found")
        return 0

    SNAPSHOT_DIR.mkdir(parents=True, exist_ok=True)
    copied: list[str] = []
    for name in REQUIRED_FILES:
        src = source_dir / name
        dst = SNAPSHOT_DIR / name
        shutil.copyfile(src, dst)
        copied.append(name)

    payload = {
        "generated_at_utc": _utc_now(),
        "source_dir": str(source_dir),
        "files": copied,
    }
    HISTORY_PATH.parent.mkdir(parents=True, exist_ok=True)
    with HISTORY_PATH.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(payload, sort_keys=True) + "\n")
    print(SNAPSHOT_DIR)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
