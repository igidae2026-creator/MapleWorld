#!/usr/bin/env python3

from __future__ import annotations

import json
import os
import time

from agents_sdk_compat import Agent, MCPServer, Runner
from design_pipeline import (
    GENERATED_BALANCE_PATH,
    GENERATED_CANDIDATES_PATH,
    GENERATED_EXPANSIONS_PATH,
    GENERATED_LIVEOPS_PATH,
    GENERATED_SCHEMA_PATH,
    PROMPTS_DIR,
    RUNS_DIR,
    append_jsonl,
    choose_emphasis_domains,
    ensure_state_layout,
    generate_balance_candidates,
    generate_expansion_candidates,
    generate_graph_candidates,
    generate_liveops_candidates,
    generate_schema_candidates,
    initialize_design_graph,
    merge_balance_candidates,
    merge_expansion_candidates,
    merge_graph_candidates,
    merge_liveops_candidates,
    merge_schema_candidates,
    repair_generated_assets,
    read_json,
    read_text_if_exists,
    regenerate_frontier,
    review_generated_assets,
    score_candidates,
    simulate_world,
    update_progress,
    write_json_if_changed,
    CYCLE_LOG_PATH,
)


def next_cycle_id() -> str:
    ensure_state_layout()
    return f"cycle_{int(time.time() * 1000)}_{os.getpid()}"


def generator_handler(input_data: dict[str, object], mcp: MCPServer) -> dict[str, object]:
    payload = generate_graph_candidates(
        emphasis_domains=list(input_data.get("emphasis_domains", [])),
        frontier_limit=int(input_data.get("frontier_limit", 64)),
    )
    mcp.write_candidate_json(
        "generator",
        "design_node_batch",
        {
            "temp_path": str(GENERATED_CANDIDATES_PATH),
            "candidate_count": len(payload.get("items", [])),
            "emphasis_domains": payload.get("emphasis_domains", []),
        },
    )
    return {"temp_path": str(GENERATED_CANDIDATES_PATH), "candidate_count": len(payload.get("items", []))}


def critic_handler(input_data: dict[str, object], mcp: MCPServer) -> dict[str, object]:
    review = review_generated_assets()
    repair = repair_generated_assets(review)
    reviewed = {
        "graph_candidate_count": len(read_json(GENERATED_CANDIDATES_PATH, {"items": []}).get("items", [])),
        "balance_temp_path": str(GENERATED_BALANCE_PATH),
        "liveops_temp_path": str(GENERATED_LIVEOPS_PATH),
        "expansions_temp_path": str(GENERATED_EXPANSIONS_PATH),
        "review": review,
        "repair": repair,
    }
    mcp.write_candidate_json("critic", "candidate_review", reviewed)
    return reviewed


def merger_handler(input_data: dict[str, object], mcp: MCPServer) -> dict[str, object]:
    merge_preview = {
        "graph_temp_path": str(GENERATED_CANDIDATES_PATH),
        "schema_temp_path": str(GENERATED_SCHEMA_PATH),
        "balance_temp_path": str(GENERATED_BALANCE_PATH),
        "liveops_temp_path": str(GENERATED_LIVEOPS_PATH),
        "expansions_temp_path": str(GENERATED_EXPANSIONS_PATH),
    }
    mcp.write_candidate_json("merger", "merge_plan", merge_preview)
    return merge_preview


def simulator_handler(input_data: dict[str, object], mcp: MCPServer) -> dict[str, object]:
    simulation = simulate_world()
    mcp.write_candidate_json("simulator", "simulation_report", simulation)
    return simulation


def supervisor_handler(input_data: dict[str, object], mcp: MCPServer) -> dict[str, object]:
    payload = {
        "status": input_data["progress"].get("last_status", "complete"),
        "progress": input_data["progress"],
        "emphasis_domains": input_data["emphasis_domains"],
    }
    mcp.write_candidate_json("supervisor", "cycle_summary", payload)
    return payload


def build_agents() -> dict[str, Agent]:
    return {
        "generator": Agent("generator", read_text_if_exists(PROMPTS_DIR / "generator.md"), generator_handler),
        "critic": Agent("critic", read_text_if_exists(PROMPTS_DIR / "critic.md"), critic_handler),
        "merger": Agent("merger", read_text_if_exists(PROMPTS_DIR / "merger.md"), merger_handler),
        "simulator": Agent("simulator", read_text_if_exists(PROMPTS_DIR / "simulator.md"), simulator_handler),
        "supervisor": Agent("supervisor", read_text_if_exists(PROMPTS_DIR / "supervisor.md"), supervisor_handler),
    }


def run_generation_cycle(
    emphasis_domains: list[str] | None = None,
    weakest_dimension: str | None = None,
) -> dict[str, object]:
    ensure_state_layout()
    cycle_id = next_cycle_id()
    mcp = MCPServer(
        name="codex-design-mcp",
        instruction="Coordinate generator, critic, merger, simulator, and supervisor through candidate JSON files.",
        cycle_id=cycle_id,
    )
    agents = build_agents()
    emphasis_domains = emphasis_domains or choose_emphasis_domains(weakest_dimension=weakest_dimension)

    initialize_design_graph()
    regenerate_frontier()
    append_jsonl(
        CYCLE_LOG_PATH,
        {
            "cycle_id": cycle_id,
            "phase": "start",
            "emphasis_domains": emphasis_domains,
            "weakest_dimension": weakest_dimension,
        },
    )

    generator_result = Runner.run(
        agents["generator"],
        {"emphasis_domains": emphasis_domains, "frontier_limit": 64},
        mcp,
    )
    schema_candidate = generate_schema_candidates()
    balance_candidate = generate_balance_candidates()
    liveops_candidate = generate_liveops_candidates()
    expansions_candidate = generate_expansion_candidates()
    critic_result = Runner.run(agents["critic"], {"temp_path": generator_result["temp_path"]}, mcp)
    score_before_merge = score_candidates()
    merger_result = Runner.run(agents["merger"], {}, mcp)

    graph_stats = merge_graph_candidates()
    regenerate_frontier()
    schema_stats = merge_schema_candidates()
    balance_stats = merge_balance_candidates()
    liveops_stats = merge_liveops_candidates()
    expansion_stats = merge_expansion_candidates()
    simulation_after_merge = Runner.run(agents["simulator"], {}, mcp)
    score_after_merge = score_candidates()
    progress = update_progress()

    supervisor_result = Runner.run(
        agents["supervisor"],
        {"progress": progress, "emphasis_domains": emphasis_domains},
        mcp,
    )

    summary = {
        "cycle_id": cycle_id,
        "emphasis_domains": emphasis_domains,
        "generator_result": generator_result,
        "critic_result": critic_result,
        "merger_result": merger_result,
        "score_before_merge": score_before_merge,
        "score_after_merge": score_after_merge,
        "simulation_after_merge": simulation_after_merge,
        "graph_stats": graph_stats,
        "schema_candidate_count": len(schema_candidate.get("items", [])),
        "schema_stats": schema_stats,
        "balance_sections": sorted(balance_candidate.keys()),
        "balance_stats": balance_stats,
        "liveops_sections": sorted(liveops_candidate.keys()),
        "liveops_stats": liveops_stats,
        "expansion_sections": sorted(expansions_candidate.keys()),
        "expansion_stats": expansion_stats,
        "progress": progress,
        "supervisor_result": supervisor_result,
    }

    write_json_if_changed(RUNS_DIR / cycle_id / "cycle_summary.json", summary)
    append_jsonl(
        CYCLE_LOG_PATH,
        {
            "cycle_id": cycle_id,
            "phase": "complete",
            "design_nodes": progress["design_nodes"],
            "schema_items": progress["schema_items"],
            "balance_rows": progress["balance_rows"],
            "liveops_rows": progress["liveops_rows"],
            "expansion_assets": progress["expansion_assets"],
            "structure_pipeline_score": progress["structure_pipeline_score"],
            "asset_throughput_score": progress["asset_throughput_score"],
            "live_balance_quality_score": progress["live_balance_quality_score"],
            "mapleland_similarity_score": progress["mapleland_similarity_score"],
            "overall_efficiency_score": progress["overall_efficiency_score"],
            "project_complete": progress["project_complete"],
        },
    )
    print(json.dumps(summary, ensure_ascii=True, indent=2))
    return summary


if __name__ == "__main__":
    run_generation_cycle()
