# Job Queue

This directory holds typed autonomy jobs split by lifecycle state.

- `queued/`
- `running/`
- `done/`
- `failed/`

Jobs should be JSON documents with stable job type, status, payload, attempts, and timestamps.
