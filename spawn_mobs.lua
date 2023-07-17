local s = spawnit.settings

local should_spawn = spawnit.util.should_spawn
local pick_a_cluster = spawnit.util.pick_a_cluster
local final_check = spawnit.util.final_check

futil.register_globalstep({
	name = "spawnit:spawn_mobs",
	period = s.spawn_mobs_period,
	catchup = "single",
	func = function(period)
		local start = os.clock()
		local num_players = #minetest.get_connected_players()
		for n, def in ipairs(spawnit.registered_spawns) do
			local should = should_spawn(def, period, num_players)
			if should then
				local cluster = pick_a_cluster(n, def)
				if #cluster > 0 then
					for _, pos in ipairs(cluster) do
						if final_check(def, pos) then
							local obj
							if def.generate_staticdata then
								obj = minetest.add_entity(pos, def.entity, def.generate_staticdata(pos))
							else
								obj = minetest.add_entity(pos, def.entity)
							end
							local spos = minetest.pos_to_string(pos)
							if obj then
								spawnit.log("action", "spawned %s @ %s", def.entity, spos)
								-- TODO: remove pos from possible positions
								if def.after_spawn then
									def.after_spawn(pos, obj)
								end
							else
								spawnit.log("warning", "failed to spawn %s @ %s", def.entity, spos)
							end
						end
					end
				end
			end
		end
		spawnit.stats.spawn_mobs_duration = spawnit.stats.spawn_mobs_duration + (os.clock() - start)
	end,
})
