from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
import unittest


ROOT_DIR = Path(__file__).resolve().parents[1]
ARCH_PROGRESS = ROOT_DIR / "ops" / "codex_state" / "progress.json"
DESIGN_PROGRESS = ROOT_DIR / "offline_ops" / "codex_state" / "progress.json"


class DesignProgressSeparationTest(unittest.TestCase):
    def test_design_progress_writes_offline_state(self) -> None:
        subprocess.run([sys.executable, "metrics_engine/run_quality_eval.py"], cwd=ROOT_DIR, check=True)
        subprocess.run([sys.executable, "ai_evolution_offline/codex/update_progress.py"], cwd=ROOT_DIR, check=True)
        design = json.loads(DESIGN_PROGRESS.read_text(encoding="utf-8"))
        architecture = json.loads(ARCH_PROGRESS.read_text(encoding="utf-8"))
        self.assertIn("active_player_bottleneck", design)
        self.assertNotEqual(str(design.get("overall_player_experience_floor", "")), "")
        self.assertIn("architecture_score", architecture)


if __name__ == "__main__":
    unittest.main()
