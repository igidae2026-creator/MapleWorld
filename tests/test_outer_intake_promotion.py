from __future__ import annotations

import json
import tempfile
from contextlib import ExitStack
from pathlib import Path
from unittest import mock
import unittest

from offline_ops.autonomy import event_log, job_queue, paths, snapshots, supervisor


class OuterIntakePromotionTest(unittest.TestCase):
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
        ]
        for patcher in patches:
            stack.enter_context(patcher)
        return stack

    def test_supervisor_promotes_top_authority_material_into_design_graph(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            with self._patch_autonomy_paths(root):
                supervisor.bootstrap()
                result = supervisor.ingest_material("GOAL.md")
                self.assertEqual(result["decision"], "promote")

                run_result = supervisor.run_once(worker_id="outer-intake-test")
                self.assertEqual(run_result["next_action"], "promoted_to_design_graph")

                shard_path = root / "data" / "design_graph" / "external_material_autonomy.json"
                index_path = root / "data" / "design_graph" / "index.json"
                manifest_path = root / "data" / "design_graph" / "manifest.json"
                external_intake_path = root / "offline_ops" / "autonomy" / "state" / "external_intake.json"

                shard = json.loads(shard_path.read_text(encoding="utf-8"))
                self.assertEqual(shard["domain"], "external_material_autonomy")
                self.assertTrue(any(node.get("material_path") == "GOAL.md" for node in shard["nodes"]))

                index = json.loads(index_path.read_text(encoding="utf-8"))
                self.assertTrue(index["index"]["external_material_autonomy"])
                self.assertIn(run_result["promotion"]["node_id"], index["index"])

                manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
                self.assertIn("external_material_autonomy", manifest["domains"])
                self.assertTrue(
                    any(entry.get("domain") == "external_material_autonomy" for entry in manifest["shards"])
                )

                external_intake = json.loads(external_intake_path.read_text(encoding="utf-8"))
                self.assertEqual(external_intake["payload"]["last_promoted_material"], "GOAL.md")
                self.assertEqual(external_intake["payload"]["pending_candidates"], 0)
                self.assertEqual(external_intake["payload"]["promoted_count"], 1)

    def test_supervisor_auto_promotes_repo_scoped_material_after_review(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            with self._patch_autonomy_paths(root):
                supervisor.bootstrap()
                result = supervisor.ingest_material("data/balance/maps/role_bands.csv")
                self.assertEqual(result["decision"], "queue_review")

                run_result = supervisor.run_once(worker_id="outer-intake-test")
                self.assertEqual(run_result["next_action"], "promoted_to_design_graph")

                shard_path = root / "data" / "design_graph" / "external_material_autonomy.json"
                shard = json.loads(shard_path.read_text(encoding="utf-8"))
                promoted = [
                    node
                    for node in shard["nodes"]
                    if node.get("material_path") == "data/balance/maps/role_bands.csv"
                ]
                self.assertEqual(len(promoted), 1)


if __name__ == "__main__":
    unittest.main()
