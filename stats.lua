spawnit.stats = {
	last_measure_time = os.clock(),
	ao_calc_duration = 0,
	get_ao_blocks_duration = 0,
	async_callback_duration = 0,
	spawn_mobs_duration = 0,
}

function spawnit.get_and_reset_stats()
	local stats = {}
	stats.registered_spawns = #spawnit.registered_spawns
	stats.active_object_blocks = futil.table.size(spawnit.visibility_by_hpos)
	stats.nearby_blocks = futil.table.size(spawnit.nearby_players_by_hpos)

	local calculating_blocks = 0
	local cached_blocks = 0
	for _, spawn_poss in pairs(spawnit.spawn_poss_by_hpos) do
		if spawn_poss == "calculating" then
			calculating_blocks = calculating_blocks + 1
		else
			cached_blocks = cached_blocks + 1
		end
	end
	stats.calculating_blocks = calculating_blocks
	stats.cached_blocks = cached_blocks

	local now = os.clock()
	local elapsed = now - spawnit.stats.last_measure_time
	stats.ao_calc_usage = math.round((spawnit.stats.ao_calc_duration / elapsed) * 1e6)
	stats.get_ao_blocks_usage = math.round((spawnit.stats.get_ao_blocks_duration / elapsed) * 1e6)
	stats.async_callback_usage = math.round((spawnit.stats.async_callback_duration / elapsed) * 1e6)
	stats.spawn_mobs_usage = math.round((spawnit.stats.spawn_mobs_duration / elapsed) * 1e6)

	spawnit.stats.last_measure_time = now
	spawnit.stats.ao_calc_duration = 0
	spawnit.stats.get_ao_blocks_duration = 0
	spawnit.stats.async_callback_duration = 0
	spawnit.stats.spawn_mobs_duration = 0

	return stats
end
