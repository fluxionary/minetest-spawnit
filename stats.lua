spawnit.stats = {
	last_measure_time = minetest.get_us_time(),

	ao_calc_duration = 0,
	get_ao_blocks_duration = 0,
	async_queue_duration = 0,
	async_callback_duration = 0,
	spawn_mobs_duration = 0,

	num_spawned = 0,
}

function spawnit.get_and_reset_stats()
	local start = minetest.get_us_time()
	local stats = {}
	stats.registered_spawns = #spawnit.registered_spawns
	stats.active_object_blocks = futil.table.size(spawnit.visibility_by_hpos)
	stats.nearby_blocks = futil.table.size(spawnit.nearby_players_by_hpos)

	local calculating_blocks = 0
	local cached_blocks = 0
	for _, spawn_poss in pairs(spawnit.spawn_poss_by_block_hpos) do
		if spawn_poss == "calculating" then
			calculating_blocks = calculating_blocks + 1
		else
			cached_blocks = cached_blocks + 1
		end
	end
	stats.calculating_blocks = calculating_blocks
	stats.cached_blocks = cached_blocks

	local now = minetest.get_us_time()
	local elapsed = (now - spawnit.stats.last_measure_time) / 1e6
	stats.ao_calc_usage = spawnit.stats.ao_calc_duration / elapsed
	stats.get_ao_blocks_usage = spawnit.stats.get_ao_blocks_duration / elapsed
	stats.async_queue_usage = spawnit.stats.async_queue_duration / elapsed
	stats.async_callback_usage = spawnit.stats.async_callback_duration / elapsed
	stats.spawn_mobs_usage = spawnit.stats.spawn_mobs_duration / elapsed

	stats.async_queue_size = spawnit.find_spawn_poss_queue:size()
	stats.callback_queue_size = spawnit.callback_queue:size()

	stats.approx_memory_usage = futil.estimate_memory_usage(spawnit)

	stats.num_spawned = spawnit.stats.num_spawned

	spawnit.stats.last_measure_time = now
	spawnit.stats.ao_calc_duration = 0
	spawnit.stats.get_ao_blocks_duration = 0
	spawnit.stats.async_queue_duration = 0
	spawnit.stats.async_callback_duration = 0
	spawnit.stats.spawn_mobs_duration = 0
	spawnit.stats.num_spawned = 0

	stats.stats_gen_time = minetest.get_us_time() - start

	return stats
end
