local get_us_time = minetest.get_us_time

local table_size = futil.table.size

local s = spawnit.settings

spawnit._stats = {
	last_measure_time = minetest.get_us_time(),

	ao_calc_duration = 0,
	async_queue_duration = 0,
	async_callback_duration = 0,
	spawn_mobs_duration = 0,

	num_spawned = 0,
	total_spawned = 0,
}

function spawnit._get_and_reset_stats()
	local start = get_us_time()
	local stats = {}
	stats.registered_spawns = #spawnit.registered_spawns
	stats.active_object_blocks = table_size(spawnit._visibility_by_block_hpos)
	stats.nearby_blocks = table_size(spawnit._nearby_players_by_block_hpos)
	stats.active_entities = table_size(minetest.luaentities)

	local calculating_blocks = 0
	local cached_blocks = 0
	for _, spawn_poss in pairs(spawnit._spawn_poss_by_block_hpos) do
		if spawn_poss == "calculating" then
			calculating_blocks = calculating_blocks + 1
		else
			cached_blocks = cached_blocks + 1
		end
	end
	stats.calculating_blocks = calculating_blocks
	stats.cached_blocks = cached_blocks

	stats.max_lag = minetest.get_server_max_lag()

	local now = minetest.get_us_time()
	local elapsed = (now - spawnit._stats.last_measure_time) / 1e6
	stats.ao_calc_usage = spawnit._stats.ao_calc_duration / elapsed
	stats.async_queue_usage = spawnit._stats.async_queue_duration / elapsed
	stats.async_callback_usage = spawnit._stats.async_callback_duration / elapsed
	stats.spawn_mobs_usage = spawnit._stats.spawn_mobs_duration / elapsed

	stats.async_queue_size = spawnit._find_spawn_poss_queue:size()
	stats.callback_queue_size = spawnit._callback_queue:size()

	if s.track_memory_usage then
		stats.all_mt_lua_memory_usage = collectgarbage("count")
		stats.approx_memory_usage = futil.estimate_memory_usage(spawnit)
	end

	stats.num_spawned = spawnit._stats.num_spawned
	stats.total_spawned = spawnit._stats.total_spawned + spawnit._stats.num_spawned

	spawnit._stats.last_measure_time = now
	spawnit._stats.ao_calc_duration = 0
	spawnit._stats.async_queue_duration = 0
	spawnit._stats.async_callback_duration = 0
	spawnit._stats.spawn_mobs_duration = 0
	spawnit._stats.num_spawned = 0
	spawnit._stats.total_spawned = stats.total_spawned

	stats.stats_gen_time = get_us_time() - start

	if spawnit.has.mesecons_debug then
		stats.avg_lag = mesecons_debug.avg_lag
	end

	return stats
end
