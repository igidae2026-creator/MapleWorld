# Player Progression

Player progression is layered on top of the existing runtime rather than replacing it.

Core systems:

- `scripts/player_class_system.lua`
- `scripts/job_system.lua`
- `scripts/stat_system.lua`
- `scripts/skill_system.lua`
- `scripts/buff_debuff_system.lua`
- `scripts/progression_system.lua`

Loop:

1. Create player state inside the server runtime.
2. Choose a job branch and allocate stats.
3. Learn skills with SP and reinforce a build direction.
4. Upgrade gear, complete sets, and push higher-level routes and bosses.
5. Use quests, parties, guilds, and world events to accelerate progression.
