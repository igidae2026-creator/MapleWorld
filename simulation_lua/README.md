simulation_lua is an offline-only deterministic Lua simulation slice.

Responsibilities:
- consume repository-local shared rules and built content data
- run fast combat, progression, drop, and boss proxy simulations
- emit machine-readable outputs for offline evaluation

Non-responsibilities:
- no MSW runtime imports
- no live gameplay ownership
- no runtime mutation or control-plane behavior
