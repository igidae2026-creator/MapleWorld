metrics_engine is an offline-only quality evaluation slice.

Responsibilities:
- read simulation outputs from Lua and Python layers
- compute coarse proxy metrics as machine-readable ranges
- avoid fake precision and avoid claiming direct player-fun truth

Non-responsibilities:
- no MSW runtime imports
- no gameplay ownership
- no live operations authority
