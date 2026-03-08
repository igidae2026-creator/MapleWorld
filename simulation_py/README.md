simulation_py is an offline-only Python simulation slice.

Responsibilities:
- run a bounded player, world, and economy proxy simulation
- model small populations and play-style mixes deterministically
- emit machine-readable reports for offline evaluation

Non-responsibilities:
- no MSW runtime imports
- no live gameplay ownership
- no external services or non-stdlib dependencies
