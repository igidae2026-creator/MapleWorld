# Content Model

Content is generated and loaded through:

- `data/content_registry.lua`
- `data/content_loader.lua`
- `data/content_index.lua`
- `data/content_validation.lua`

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
- `data/world_runtime.lua`: spawn placement, route metadata, and map runtime bindings derived from loaded content.
