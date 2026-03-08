# Security Model

Authority is server-first.

- player identity can no longer depend on a giant bridge; runtime-facing identity and authority must be rebuilt explicitly inside `msw_runtime/`
- world, channel, runtime, and map scopes are checked on transfer and reward mutation
- distributed rate limiting and exploit scoring sit in front of expanded skill and control-plane actions
- reward duplication pressure, replay verification, and ownership conflict tracking feed governance state
- audit and telemetry sinks retain economy and admin mutations for replay and operator review
