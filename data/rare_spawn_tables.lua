local RareSpawns = {
    henesys_fields = {
        cadence = 'frequent',
        baselineChance = 0.05,
        elite = { mobId = 'henesys_mob_04', rewardBias = 'starter_upgrade', trigger = 'route_streak' },
        rares = {
            { mobId = 'henesys_mob_03', chance = 0.05, reward = 'henesys_material_01', behavior = 'rushdown' },
            { mobId = 'henesys_mob_04', chance = 0.03, reward = 'henesys_bronze_blade', behavior = 'anchor' },
        },
    },
    ellinia_fields = {
        cadence = 'frequent',
        baselineChance = 0.055,
        elite = { mobId = 'ellinia_mob_04', rewardBias = 'mana_route', trigger = 'combo_chain' },
        rares = {
            { mobId = 'ellinia_mob_03', chance = 0.04, reward = 'ellinia_material_02', behavior = 'teleport' },
            { mobId = 'ellinia_mob_04', chance = 0.025, reward = 'ellinia_arcane_focus', behavior = 'caster_anchor' },
        },
    },
    perion_fields = {
        cadence = 'steady',
        baselineChance = 0.06,
        elite = { mobId = 'perion_mob_04', rewardBias = 'defense_upgrade', trigger = 'dense_pull' },
        rares = {
            { mobId = 'perion_mob_03', chance = 0.045, reward = 'perion_material_03', behavior = 'slam' },
            { mobId = 'perion_mob_04', chance = 0.03, reward = 'perion_obsidian_armor', behavior = 'juggernaut' },
        },
    },
    kerning_fields = {
        cadence = 'volatile',
        baselineChance = 0.07,
        elite = { mobId = 'kerning_mob_04', rewardBias = 'market_spike', trigger = 'stealth_clear' },
        rares = {
            { mobId = 'kerning_mob_03', chance = 0.055, reward = 'kerning_material_04', behavior = 'ambush' },
            { mobId = 'kerning_mob_04', chance = 0.035, reward = 'kerning_shadow_claw', behavior = 'assassin' },
        },
    },
    ludibrium_fields = {
        cadence = 'scheduled',
        baselineChance = 0.065,
        elite = { mobId = 'ludibrium_mob_04', rewardBias = 'party_upgrade', trigger = 'party_presence' },
        rares = {
            { mobId = 'ludibrium_mob_03', chance = 0.05, reward = 'ludibrium_material_05', behavior = 'phase_shift' },
            { mobId = 'ludibrium_mob_04', chance = 0.03, reward = 'ludibrium_clock_blade', behavior = 'clock_anchor' },
        },
    },
    leafre_fields = {
        cadence = 'scheduled',
        baselineChance = 0.075,
        elite = { mobId = 'leafre_mob_04', rewardBias = 'boss_readiness', trigger = 'high_altitude_clear' },
        rares = {
            { mobId = 'leafre_mob_03', chance = 0.055, reward = 'leafre_material_06', behavior = 'dive' },
            { mobId = 'leafre_mob_04', chance = 0.035, reward = 'dragon_scale_core', behavior = 'predator' },
        },
    },
}

return RareSpawns
