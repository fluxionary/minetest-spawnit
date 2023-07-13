local s = spawnit.settings

local should_spawn = spawnit.util.should_spawn
local pick_a_cluster = spawnit.util.pick_a_cluster

futil.register_globalstep({
	name = "spawnit:spawn_mobs",
	period = s.spawn_mobs_period,
	catchup = "single",
	func = function(period)
		local num_players = #minetest.get_connected_players()
		for i, def in ipairs(spawnit.registered_spawnings) do
			if should_spawn(def, period, num_players) then
				local cluster = pick_a_cluster(def)
				if cluster and #cluster > 0 then
					for _, pos in ipairs(cluster) do
						local obj
						if def.generate_staticdata then
							obj = minetest.add_entity(pos, def.entity, def.generate_staticdata(pos))
						else
							obj = minetest.add_entity(pos, def.entity)
						end
						local spos = minetest.pos_to_string(pos)
						if obj then
							spawnit.log("action", "spawned %s @ %s", def.entity, spos)
						else
							spawnit.log("warning", "failed to spawn %s @ %s", def.entity, spos)
						end
					end
				end
			end
		end
	end,
})
