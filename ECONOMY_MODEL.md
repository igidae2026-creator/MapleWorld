# Economy Model

The economy is designed for a single-world market.

- live economy mutation is executed by the gameplay runtime under `msw_runtime/`
- portable pricing, sink, and abuse rules should converge into `shared_rules/`
- current `scripts/economy_system.lua`, `scripts/trading_system.lua`, and `scripts/auction_house.lua` are transitional runtime residue, not long-term ownership targets
- offline tuning, simulation, and intervention selection stay in `offline_ops/`, `metrics_engine/`, and `simulation_py/`
- market visibility is exposed through `world:getEconomyReport()` as a gameplay report surface, not a runtime control plane

Stability controls:

- suspicious flow detection
- sink pressure tracking
- price signal history
- audit events for trades and shop actions
- player-driven pricing through auction listings
- inflation guardrails using faucet/sink ratio and market spread checks
- duplicate reward and duplicate item-instance detection through runtime guards
- high-value trade incident surfacing and self-trade blocking
