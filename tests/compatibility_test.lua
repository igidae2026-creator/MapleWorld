package.path = package.path .. ';./?.lua;../?.lua'
local ServerBootstrap = require('scripts.server_bootstrap')
local world = ServerBootstrap.boot('/path/that/does/not/exist')
assert(world.bootReport.dataSource == 'runtime_tables', 'runtime data fallback not used')
world.scheduler:tick(5)
assert(next(world.spawnSystem.maps['henesys_hunting_ground'].active) ~= nil, 'spawn failed under runtime data fallback')
print('compatibility_test: ok')
