local f = string.format

local s = spawnit.settings
local S = spawnit.S

spawnit._hud = futil.define_hud("spawnit:hud", {
	period = s.hud_update_period,
	enabled_by_default = false,
	get_hud_data = spawnit._get_and_reset_stats,
	get_hud_def = function(player, stats)
		if not minetest.check_player_privs(player, s.hud_priv) then
			spawnit._hud:set_enabled(player, false)
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
			table.insert(lines, f("lag ratio (dtime / dedicated_server_step) = %.1f", stats.avg_lag))
		end

		table.insert_all(lines, {
			f("server max_lag = %.2fs", stats.max_lag),
			f("#registered spawn rules = %i", stats.registered_spawns),
			f("#active object mapblocks = %i", stats.active_object_blocks),
			f("#mapblocks near players = %i", stats.nearby_blocks),
			f("#mapblocks with cached positions = %i", stats.cached_blocks),
			f("#mapblocks being processed = %i", stats.calculating_blocks),
			f("#async_queue (size) = %i", stats.async_queue_size),
			f("#callback_queue (size) = %i", stats.callback_queue_size),
			f("active mapblock analysis usage = %.1fus/s", stats.ao_calc_usage),
			f("async queue usage = %.1fus/s", stats.async_queue_usage),
			f("async callback usage = %.1fus/s", stats.async_callback_usage),
			f("spawn mobs usage = %.1fus/s", stats.spawn_mobs_usage),
			f("#spawned this step = %i", stats.num_spawned),
			f("#spawned since startup = %i", stats.total_spawned),
			f("#active_entities = %i", stats.active_entities),
			f("gen time for this HUD = %ius", stats.stats_gen_time),
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
		description = S("spawnit debug priv"),
		give_to_singleplayer = true,
		give_to_admin = true,
	})
end

minetest.register_chatcommand("spawnit_hud", {
	description = S("toggle spawnit hud"),
	privs = { [s.debug_priv] = true },
	func = function(name)
		local player = minetest.get_player_by_name(name)
		if not player then
			return false, "you are not a connected player"
		end
		local enabled = spawnit._hud:toggle_enabled(player)
		if enabled then
			return true, "hud enabled"
		else
			return true, "hud disabled"
		end
	end,
})
