# Content Model

Content is generated and loaded through:

- `content_build/content_registry.lua`
- `content_build/content_loader.lua`
- `content_build/content_index.lua`
- `content_build/content_validation.lua`

Supported content domains:

- maps
- mobs and rare variants
- bosses with mechanics
- items and equipment families
- quests and main progression arcs
- jobs and skill trees
- NPC dialogues
- drop tables
- economy and world-event definitions

Runtime-connected support tables:

- `data/regional_progression_tables.lua`: region ladder, milestone rewards, valued drops, and social-loop identity.
- `data/rare_spawn_tables.lua`: map-by-map elite cadence, reward bias, and rare behavior definitions.
- `deleted (world runtime ownership removed from live runtime)`: spawn placement, route metadata, and map runtime bindings derived from loaded content.
