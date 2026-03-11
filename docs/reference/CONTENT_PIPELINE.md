# Content Pipeline

Source of truth is `content_build/content_registry.lua`.

Flow:

1. Generate structured content in registry form.
2. Load through `content_build/content_loader.lua`.
3. Validate references with `content_build/content_validation.lua`.
4. Index search and grouping with `content_build/content_index.lua`.
5. Project to runtime rows with `data/runtime_tables.lua`.
6. Project to world topology with `deleted (world runtime ownership removed from live runtime)`.

The category catalogs under `data/*/catalog.lua` expose content sections directly for tools and tests.
