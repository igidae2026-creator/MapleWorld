return {
    local_dev = { channels = 2, shards = 1, replay = 'strict' },
    integration = { channels = 4, shards = 2, replay = 'strict' },
    production = { channels = 12, shards = 4, replay = 'anchor+continuous' },
}
