msw_runtime contains only live gameplay code that runs inside MapleStory Worlds.

Allowed:
- event handlers
- gameplay systems
- server-authoritative mutation
- entity/state adapters
- storage adapters strictly required for live gameplay

Forbidden:
- standalone runtime bootstrap
- custom world runtime ownership
- replay engine
- candidate generation
- architecture simulation
- control plane
- cluster/failover/session orchestration
- filesystem CSV loading
