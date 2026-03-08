package.path = package.path .. ';./?.lua;../?.lua'

local tmpOutput = '/tmp/mapleworld_architecture_phase2_cycle.out'
local command = 'python3 ai_evolution_offline/codex/run_architecture_cycle.py > ' .. tmpOutput
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
local progress = readFile('offline_ops/codex_state/progress.json')

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
assert(summary:match('"meso_velocity_control"%s*:%s*[%d%.]+') ~= nil, 'meso velocity control missing')
assert(summary:match('"rollback_boundary_clarity"%s*:%s*[%d%.]+') ~= nil, 'rollback boundary clarity missing')
assert(summary:match('"social_density_anchor_quality"%s*:%s*[%d%.]+') ~= nil, 'social density anchor quality missing')

print('architecture_phase2_cycle_test: ok')
