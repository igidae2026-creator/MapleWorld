from __future__ import annotations

import json
import math
from collections import Counter, defaultdict
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
RUNS_DIR = ROOT_DIR / "offline_ops" / "codex_state" / "simulation_runs"
OUTPUT_PATH = RUNS_DIR / "world_graph_metrics_latest.json"


def _clamp(value: float, floor: float = 0.0, ceiling: float = 1.0) -> float:
    return max(floor, min(ceiling, value))


def _load_python_data() -> dict[str, object]:
    return json.loads((RUNS_DIR / "python_simulation_latest.json").read_text(encoding="utf-8"))


def _entropy(distribution: dict[str, float]) -> float:
    total = sum(distribution.values()) or 1.0
    weights = [value / total for value in distribution.values() if value > 0]
    return -sum(weight * math.log(weight, 2) for weight in weights)


def _safe_ratio(num: float, den: float) -> float:
    return num / den if den > 0 else 0.0


def build_world_graph_metrics(python_data: dict[str, object] | None = None) -> dict[str, object]:
    payload = python_data or _load_python_data()
    world = dict(payload.get("world", {}))
    graph = dict(world.get("world_graph_model", {}))
    nodes = list(graph.get("nodes", []))
    edges = list(graph.get("edges", []))
    visits = {str(k): float(v) for k, v in dict(graph.get("node_visits", {})).items()}
    expected = {str(k): float(v) for k, v in dict(graph.get("expected_visits", {})).items()}
    traversals = {str(k): float(v) for k, v in dict(graph.get("edge_traversals", {})).items()}
    routes = {str(k): float(v) for k, v in dict(graph.get("route_counts", {})).items()}

    node_lookup = {str(node.get("node_id", "")): node for node in nodes}

    utilization_by_node: dict[str, float] = {}
    for node_id in node_lookup:
        actual = visits.get(node_id, 0.0)
        exp = max(1.0, expected.get(node_id, 1.0))
        utilization_by_node[node_id] = round(actual / exp, 4)

    # Core metrics
    active_node_ids = [
        node_id
        for node_id in node_lookup
        if expected.get(node_id, 0.0) > 0.0 or visits.get(node_id, 0.0) > 0.0
    ]
    utilization_values = [utilization_by_node[node_id] for node_id in active_node_ids] or list(utilization_by_node.values())
    avg_utilization = sum(utilization_values) / max(1, len(utilization_values))
    normalized_node_utilization = _clamp(avg_utilization / 1.0)

    content_slots = [float(node_lookup[node_id].get("content_slots", 1.0)) for node_id in node_lookup]
    avg_density = sum(content_slots) / max(1, len(content_slots))
    # MapleWorld's graph carries density mostly through many 2-slot route nodes plus a smaller
    # set of 3-slot anchors, so normalizing against 3.0 suppresses legitimate content scale-out.
    normalized_content_density = _clamp(avg_density / 2.6)

    visited_nodes = sum(1 for node_id in active_node_ids if visits.get(node_id, 0.0) > 0.0)
    reachable_nodes = max(1, len(active_node_ids))
    transition_count = sum(1 for value in traversals.values() if value > 0.0)
    edge_count = max(1, len(edges))
    exploration_flow = _clamp((visited_nodes / max(1, reachable_nodes)) * 0.7 + (transition_count / edge_count) * 0.3)

    path_entropy_raw = _entropy(routes)
    path_entropy = _clamp(path_entropy_raw / math.log(max(2, len(routes)), 2)) if routes else 0.0

    edge_friction: dict[str, float] = {}
    for edge in edges:
        key = f"{edge.get('from')}->{edge.get('to')}"
        edge_friction[key] = float(edge.get("friction", 0.25))
    weighted_friction = 0.0
    traversal_weight = 0.0
    for edge_key, count in traversals.items():
        weighted_friction += float(count) * edge_friction.get(edge_key, 0.25)
        traversal_weight += float(count)
    travel_friction = _clamp(_safe_ratio(weighted_friction, traversal_weight), 0.0, 0.95)

    # Risks
    dead_zones: list[dict[str, object]] = []
    overcrowded_nodes: list[dict[str, object]] = []

    for node_id, utilization in sorted(utilization_by_node.items()):
        exp = expected.get(node_id, 0.0)
        if exp >= 6.0 and utilization < 0.22:
            dead_zones.append(
                {
                    "node_id": node_id,
                    "utilization": round(utilization, 4),
                    "expected_visits": exp,
                }
            )
        if utilization > 1.35 and visits.get(node_id, 0.0) >= 5.0:
            overcrowded_nodes.append(
                {
                    "node_id": node_id,
                    "utilization": round(utilization, 4),
                    "actual_visits": round(visits.get(node_id, 0.0), 4),
                }
            )

    in_flow: Counter[str] = Counter()
    out_degree: Counter[str] = Counter()
    for edge in edges:
        src = str(edge.get("from", ""))
        dst = str(edge.get("to", ""))
        out_degree[src] += 1
        flow = float(traversals.get(f"{src}->{dst}", 0.0))
        in_flow[dst] += flow

    total_flow = sum(in_flow.values()) or 1.0
    exploration_bottlenecks: list[dict[str, object]] = []
    for node_id, flow in in_flow.items():
        share = flow / total_flow
        if share > 0.32 and out_degree.get(node_id, 0) <= 1:
            exploration_bottlenecks.append(
                {
                    "node_id": node_id,
                    "flow_share": round(share, 4),
                    "out_degree": int(out_degree.get(node_id, 0)),
                }
            )

    reasons: list[str] = []
    if len(dead_zones) >= 2:
        reasons.append(f"dead zones detected: {len(dead_zones)}")
    if len(overcrowded_nodes) >= 2:
        reasons.append(f"overcrowded nodes detected: {len(overcrowded_nodes)}")
    if len(exploration_bottlenecks) >= 3:
        reasons.append(f"exploration bottlenecks detected: {len(exploration_bottlenecks)}")
    if path_entropy < 0.62:
        reasons.append(f"path entropy below floor: {path_entropy:.4f} < 0.6200")
    if exploration_flow < 0.42:
        reasons.append(f"exploration flow below floor: {exploration_flow:.4f} < 0.4200")

    return {
        "node_utilization": round(normalized_node_utilization, 4),
        "content_density": round(normalized_content_density, 4),
        "exploration_flow": round(exploration_flow, 4),
        "path_entropy": round(path_entropy, 4),
        "travel_friction": round(travel_friction, 4),
        "dead_zones": dead_zones,
        "overcrowded_nodes": overcrowded_nodes,
        "exploration_bottlenecks": exploration_bottlenecks,
        "counts": {
            "nodes": len(nodes),
            "edges": len(edges),
            "visited_nodes": visited_nodes,
            "reachable_nodes": reachable_nodes,
        },
        "status": "reject" if reasons else "allow",
        "reasons": reasons,
    }


def write_world_graph_metrics(
    python_data: dict[str, object] | None = None,
    output_path: Path = OUTPUT_PATH,
) -> dict[str, object]:
    payload = build_world_graph_metrics(python_data)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return payload
