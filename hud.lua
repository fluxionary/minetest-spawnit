local f = string.format

local s = spawnit.settings
local S = spawnit.S

spawnit.hud = futil.define_hud("spawnit:hud", {
	period = s.hud_update_period,
	enabled_by_default = false,
	get_hud_data = spawnit.get_and_reset_stats,
	get_hud_def = function(player, stats)
		if not minetest.check_player_privs(player, s.hud_priv) then
			spawnit.hud:set_enabled(player, false)
			return {}
		end

		local lines
		if s.track_memory_usage then
			lines = {
				f("minetest lua memory usage = %.1fMiB", stats.all_mt_lua_memory_usage / 1024),
				f("approx spawnit memory usage = %.1fMiB", stats.approx_memory_usage / (1024 * 1024)),
			}
		else
			lines = {}
		end

		if stats.avg_lag then
			table.insert(lines, f("actual server lag (a ratio) = %.1f", stats.avg_lag))
		end

		table.insert_all(lines, {
			f("server max_lag = %.2f", stats.max_lag),
			f("#registered_spawns = %i", stats.registered_spawns),
			f("#active_object_blocks = %i", stats.active_object_blocks),
			f("#nearby_blocks = %i", stats.nearby_blocks),
			f("#cached_block_spawns = %i", stats.cached_blocks),
			f("#calculating_blocks = %i", stats.calculating_blocks),
			f("#async_queue_size = %i", stats.async_queue_size),
			f("#callback_queue_size = %i", stats.callback_queue_size),
			f("ao_calc_usage = %.1fus/s", stats.ao_calc_usage),
			f("async_queue_usage = %.1fus/s", stats.async_queue_usage),
			f("async_callback_usage = %.1fus/s", stats.async_callback_usage),
			f("spawn_mobs_usage = %.1fus/s", stats.spawn_mobs_usage),
			f("#spawned = %i", stats.num_spawned),
			f("total #spawned = %i", stats.total_spawned),
			f("active_entities = %i", stats.active_entities),
			f("hud data gen time = %ius", stats.stats_gen_time),
		})
		local text = table.concat(lines, "\n")
		return {
			hud_elem_type = "text",
			text = text,
			number = 0xFFFFFF,
			direction = 0, -- left to right
			position = { x = 1, y = 1 },
			alignment = { x = -1, y = -1 },
			offset = { x = -10, y = -10 },
			style = 1,
		}
	end,
})

if not minetest.registered_privileges[s.debug_priv] then
	minetest.register_privilege(s.debug_priv, {
		description = S("spawnit hud priv"),
		give_to_singleplayer = true,
		give_to_admin = true,
	})
end

minetest.register_chatcommand("toggle_spawnit_hud", {
	description = S("toggle spawnit hud"),
	privs = { [s.debug_priv] = true },
	func = function(name)
		local player = minetest.get_player_by_name(name)
		if not player then
			return false, "you are not a connected player"
		end
		local enabled = spawnit.hud:toggle_enabled(player)
		if enabled then
			return true, "hud enabled"
		else
			return true, "hud disabled"
		end
	end,
})
