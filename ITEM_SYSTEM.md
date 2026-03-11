# Item System

The item layer combines progression, rarity, and economy hooks.

Implemented surfaces:

- equipment slots and equipping in `scripts/item_system.lua`
- rarity and progression metadata from `content_build/content_registry.lua`
- set bonuses and gear power inside `scripts/item_system.lua`
- upgrade paths in content/runtime tables
- drop anticipation and loot visibility through `scripts/drop_system.lua` and `scripts/combat_feedback.lua`
- auction, trade, and price tracking execute in gameplay-facing runtime code, with current `scripts/auction_house.lua` and `scripts/economy_system.lua` treated as transitional residue until absorbed by `msw_runtime/` and `shared_rules/`

Items are not decorative. They drive combat power, set completion, crafting value, and market behavior.
