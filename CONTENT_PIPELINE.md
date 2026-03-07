# Content Pipeline

Source of truth is `data/content_registry.lua`.

Flow:

1. Generate structured content in registry form.
2. Load through `data/content_loader.lua`.
3. Validate references with `data/content_validation.lua`.
4. Index search and grouping with `data/content_index.lua`.
5. Project to runtime rows with `data/runtime_tables.lua`.
6. Project to world topology with `data/world_runtime.lua`.

The category catalogs under `data/*/catalog.lua` expose content sections directly for tools and tests.
