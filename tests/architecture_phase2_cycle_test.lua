package.path = package.path .. ';./?.lua;../?.lua'

local tmpOutput = '/tmp/mapleworld_architecture_phase2_cycle.out'
local command = 'python3 scripts/codex/run_architecture_cycle.py > ' .. tmpOutput
local ok = os.execute(command)
assert(ok == true or ok == 0, 'phase2 architecture cycle runner failed')

local function readFile(path)
    local handle = assert(io.open(path, 'r'))
    local content = handle:read('*a')
    handle:close()
    return content
end

local summary = readFile('data/architecture_selected/last_cycle_summary.json')
local active = readFile('data/architecture_selected/active_architecture.json')
local manifest = readFile('data/architecture_candidates/current_cycle/manifest.json')
local progress = readFile('ops/codex_state/progress.json')

assert(summary:match('"cycle_type"%s*:%s*"phase2_bounded"') ~= nil, 'phase2 cycle type missing')
assert(summary:match('"level_band_bottleneck_quality"%s*:%s*[%d%.]+') ~= nil, 'level band score missing')
assert(summary:match('"field_ladder_progression_quality"%s*:%s*[%d%.]+') ~= nil, 'field ladder score missing')
assert(summary:match('"boss_cadence_lockout_quality"%s*:%s*[%d%.]+') ~= nil, 'boss cadence score missing')
assert(active:match('"mapleland_similarity_score"%s*:%s*[%d%.]+') ~= nil, 'mapleland similarity missing')
assert(active:match('"weakest_dimension"%s*:%s*"[^"]+"') ~= nil, 'weakest dimension missing')
assert(progress:match('"architecture_last_status"%s*:%s*"bounded_phase2_cycle_complete"') ~= nil, 'progress state not updated')

local variantCount = tonumber(manifest:match('"variant_count"%s*:%s*(%d+)'))
assert(variantCount ~= nil and variantCount >= 3 and variantCount <= 5, 'variant count escaped bounded range')

local selectedVariant = summary:match('"selected_variant_id"%s*:%s*"([^"]+)"')
assert(selectedVariant ~= nil and selectedVariant ~= 'baseline', 'phase2 cycle did not select a meaningful repair variant')

local socialAnchor = tonumber(summary:match('"social_density_anchor_quality"%s*:%s*([%d%.]+)'))
assert(socialAnchor ~= nil and socialAnchor >= 95, 'social anchor pressure did not improve enough')

local consumableBurn = tonumber(summary:match('"consumable_burn_pressure"%s*:%s*([%d%.]+)'))
assert(consumableBurn ~= nil and consumableBurn >= 90, 'consumable burn pressure remains too weak')

local mesoVelocity = tonumber(summary:match('"meso_velocity_control"%s*:%s*([%d%.]+)'))
assert(mesoVelocity ~= nil and mesoVelocity >= 90, 'meso velocity control remains too loose')

local rollbackClarity = tonumber(summary:match('"rollback_boundary_clarity"%s*:%s*([%d%.]+)'))
assert(rollbackClarity ~= nil and rollbackClarity >= 95, 'rollback boundary clarity did not improve enough')

local levelBand = tonumber(summary:match('"level_band_bottleneck_quality"%s*:%s*([%d%.]+)'))
assert(levelBand ~= nil and levelBand >= 85, 'level band bottleneck quality remains too weak')

local bossCadence = tonumber(summary:match('"boss_cadence_lockout_quality"%s*:%s*([%d%.]+)'))
assert(bossCadence ~= nil and bossCadence >= 90, 'boss cadence still distorts field progression')

print('architecture_phase2_cycle_test: ok')
