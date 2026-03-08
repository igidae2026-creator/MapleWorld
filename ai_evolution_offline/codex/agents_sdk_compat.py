#!/usr/bin/env python3

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable

from design_pipeline import CANDIDATES_DIR, RUNS_DIR, ensure_dir, ensure_state_layout, graph_snapshot, read_json, write_json_if_changed


@dataclass
class MCPServer:
    name: str
    instruction: str
    cycle_id: str

    def candidate_dir(self, role: str) -> Path:
        ensure_state_layout()
        path = CANDIDATES_DIR / self.cycle_id / role
        ensure_dir(path)
        return path

    def run_dir(self) -> Path:
        ensure_state_layout()
        path = RUNS_DIR / self.cycle_id
        ensure_dir(path)
        return path

    def read_graph_snapshot(self, frontier_limit: int | None = None) -> dict[str, Any]:
        snapshot = graph_snapshot(frontier_limit=frontier_limit)
        return {
            "frontier": snapshot["frontier"],
            "graph_stats": snapshot["graph_stats"],
            "progress": snapshot["progress"],
            "index_size": len(snapshot["index"]),
            "node_map": snapshot["node_map"],
        }

    def write_candidate_json(self, role: str, name: str, payload: dict[str, Any]) -> Path:
        path = self.candidate_dir(role) / f"{name}.json"
        write_json_if_changed(path, payload)
        return path

    def read_candidate_json(self, role: str, name: str) -> dict[str, Any]:
        return read_json(self.candidate_dir(role) / f"{name}.json", {})

    def write_run_report(self, name: str, payload: dict[str, Any]) -> Path:
        path = self.run_dir() / f"{name}.json"
        write_json_if_changed(path, payload)
        return path


@dataclass
class Agent:
    name: str
    instructions: str
    handler: Callable[[dict[str, Any], MCPServer], dict[str, Any]]


class Runner:
    @staticmethod
    def run(agent: Agent, input_data: dict[str, Any], mcp_server: MCPServer) -> dict[str, Any]:
        result = agent.handler(input_data, mcp_server)
        mcp_server.write_run_report(
            f"{agent.name}_result",
            {
                "agent": agent.name,
                "instructions": agent.instructions,
                "result": result,
            },
        )
        return result
