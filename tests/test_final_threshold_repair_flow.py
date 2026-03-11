from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from contextlib import ExitStack
from pathlib import Path
from unittest import mock
import unittest

from offline_ops.autonomy import event_log, job_queue, paths, snapshots, supervisor


ROOT_DIR = Path(__file__).resolve().parents[1]
FINAL_EVAL_PATH = ROOT_DIR / "offline_ops" / "codex_state" / "final_threshold_eval.json"


class FinalThresholdRepairFlowTest(unittest.TestCase):
    def _patch_autonomy_paths(self, root: Path) -> ExitStack:
        autonomy_dir = root / "offline_ops" / "autonomy"
        state_dir = autonomy_dir / "state"
        jobs_dir = autonomy_dir / "jobs"
        queued_dir = jobs_dir / "queued"
        running_dir = jobs_dir / "running"
        done_dir = jobs_dir / "done"
        failed_dir = jobs_dir / "failed"
        event_log_path = autonomy_dir / "events.jsonl"
        design_graph_dir = root / "data" / "design_graph"
        stack = ExitStack()
        patches = [
            mock.patch.object(paths, "ROOT_DIR", root),
            mock.patch.object(paths, "AUTONOMY_DIR", autonomy_dir),
            mock.patch.object(paths, "STATE_DIR", state_dir),
            mock.patch.object(paths, "JOBS_DIR", jobs_dir),
            mock.patch.object(paths, "QUEUED_DIR", queued_dir),
            mock.patch.object(paths, "RUNNING_DIR", running_dir),
            mock.patch.object(paths, "DONE_DIR", done_dir),
            mock.patch.object(paths, "FAILED_DIR", failed_dir),
            mock.patch.object(paths, "EVENT_LOG_PATH", event_log_path),
            mock.patch.object(event_log, "EVENT_LOG_PATH", event_log_path),
            mock.patch.object(job_queue, "QUEUED_DIR", queued_dir),
            mock.patch.object(job_queue, "RUNNING_DIR", running_dir),
            mock.patch.object(job_queue, "DONE_DIR", done_dir),
            mock.patch.object(job_queue, "FAILED_DIR", failed_dir),
            mock.patch.object(snapshots, "STATE_DIR", state_dir),
            mock.patch.object(supervisor, "ROOT_DIR", root),
            mock.patch.object(supervisor, "DESIGN_GRAPH_DIR", design_graph_dir),
            mock.patch.object(supervisor, "DESIGN_GRAPH_INDEX_PATH", design_graph_dir / "index.json"),
            mock.patch.object(supervisor, "DESIGN_GRAPH_MANIFEST_PATH", design_graph_dir / "manifest.json"),
            mock.patch.object(supervisor, "EXTERNAL_AUTONOMY_SHARD_PATH", design_graph_dir / "external_material_autonomy.json"),
            mock.patch.object(supervisor, "FINAL_THRESHOLD_REPAIRS_PATH", root / "offline_ops" / "codex_state" / "final_threshold_repairs.jsonl"),
            mock.patch.object(supervisor, "P0_QUEUE_PATH", root / "offline_ops" / "codex_state" / "p0_queue.txt"),
        ]
        for patcher in patches:
            stack.enter_context(patcher)
        return stack

    def test_supervisor_consumes_repair_gap_job(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            with self._patch_autonomy_paths(root):
                supervisor.bootstrap()
                job_queue.enqueue_job(
                    "repair_final_threshold_gap",
                    {"criterion": "quality_gate_fail_closed", "repair_action": "repair fail-closed gate"},
                    priority=10,
                )
                result = supervisor.run_once(worker_id="final-threshold-test")
                self.assertEqual(result["next_action"], "queued_final_threshold_repair")
                self.assertTrue((root / "offline_ops" / "codex_state" / "final_threshold_repairs.jsonl").exists())
                self.assertIn(
                    "FINAL-quality_gate_fail_closed",
                    (root / "offline_ops" / "codex_state" / "p0_queue.txt").read_text(encoding="utf-8"),
                )

    def test_final_threshold_eval_enqueues_missing_repairs_when_not_ready(self) -> None:
        threshold_path = ROOT_DIR / "offline_ops" / "codex_state" / "thresholds" / "latest_status.json"
        original_threshold = threshold_path.read_text(encoding="utf-8")
        original_eval = FINAL_EVAL_PATH.read_text(encoding="utf-8") if FINAL_EVAL_PATH.exists() else None
        try:
            payload = json.loads(original_threshold)
            payload["status"]["execution_threshold_met"] = False
            payload["thresholds"]["execution"] = 80.0
            threshold_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
            subprocess.run([sys.executable, "scripts/run_final_threshold_eval.py"], cwd=ROOT_DIR, check=True)
            final_eval = json.loads(FINAL_EVAL_PATH.read_text(encoding="utf-8"))
            self.assertFalse(final_eval["final_threshold_ready"])
            self.assertIn("closed_loop_completion", final_eval["failed_criteria"])
            self.assertTrue(any(item["criterion"] == "closed_loop_completion" for item in final_eval["next_required_repairs"]))
        finally:
            threshold_path.write_text(original_threshold, encoding="utf-8")
            if original_eval is not None:
                FINAL_EVAL_PATH.write_text(original_eval, encoding="utf-8")


if __name__ == "__main__":
    unittest.main()
