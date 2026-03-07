# Security Model

Authority is server-first.

- player identity resolves through `ops/runtime_adapter.lua` and the MSW bridge
- world, channel, runtime, and map scopes are checked on transfer and reward mutation
- distributed rate limiting and exploit scoring sit in front of expanded skill and control-plane actions
- reward duplication pressure, replay verification, and ownership conflict tracking feed governance state
- audit and telemetry sinks retain economy and admin mutations for replay and operator review
