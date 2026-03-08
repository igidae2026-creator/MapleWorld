from __future__ import annotations

from pathlib import Path
import unittest


ROOT_DIR = Path(__file__).resolve().parents[1]
PROMPT_PATH = ROOT_DIR / "ai_evolution_offline" / "prompts" / "agent6_content.txt"
LOOP_PATH = ROOT_DIR / "ai_evolution_offline" / "codex" / "run_bottleneck_loop.sh"
COORDINATOR_PATH = ROOT_DIR / "ai_evolution_offline" / "prompts" / "coordinator.txt"


class Agent6ContentPromptSmokeTest(unittest.TestCase):
    def test_agent6_prompt_and_references_exist(self) -> None:
        self.assertTrue(PROMPT_PATH.is_file())
        self.assertIn("CONTENT_SCORES:", PROMPT_PATH.read_text(encoding="utf-8"))
        loop_text = LOOP_PATH.read_text(encoding="utf-8")
        self.assertIn("agent6_content.txt", loop_text)
        self.assertIn('agent6.txt', loop_text)
        coordinator_text = COORDINATOR_PATH.read_text(encoding="utf-8")
        self.assertIn("6. Content", coordinator_text)


if __name__ == "__main__":
    unittest.main()
