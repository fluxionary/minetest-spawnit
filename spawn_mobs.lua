local get_us_time = minetest.get_us_time

local sample_with_indices = futil.random.sample_with_indices

local s = spawnit.settings

local should_spawn = spawnit.util.should_spawn
local pick_a_cluster = spawnit.util.pick_a_cluster
local final_check = spawnit.util.final_check
local remove_spawn_position = spawnit.util.remove_spawn_position

local function try_spawn_mob(def_index, def)
	local cluster = pick_a_cluster(def_index, def)
	if #cluster == 0 then
		return
	end

	for _, pos in ipairs(cluster) do
		if final_check(def, pos) then
			local entity_name
			if type(def.entity_name) == "string" then
				entity_name = def.entity_name
			else
				entity_name = def.chooser:next()
			end

			local obj
			if def.generate_staticdata then
				obj = minetest.add_entity(pos, entity_name, def.generate_staticdata(pos))
			else
				obj = minetest.add_entity(pos, entity_name)
			end
			local spos = minetest.pos_to_string(pos)
			if obj then
				spawnit.log("action", "spawned %s @ %s", entity_name, spos)
				if def.after_spawn then
					def.after_spawn(pos, obj)
				end
			else
				spawnit.log("warning", "failed to spawn %s @ %s", entity_name, spos)
			end
			spawnit.stats.num_spawned = spawnit.stats.num_spawned + 1
			remove_spawn_position(def_index, pos)
		end
	end
end

futil.register_globalstep({
	name = "spawnit:spawn_mobs",
	period = s.spawn_mobs_period,
	catchup = "single",
	func = function(period)
		local start = get_us_time()
		local num_players = #minetest.get_connected_players()
		local registered_spawns = spawnit.registered_spawns
		local num_spawn_rules = #registered_spawns
		local max_spawn_rules_per_iteration = s.max_spawn_rules_per_iteration
		if num_spawn_rules <= max_spawn_rules_per_iteration then
			for def_index = 1, num_spawn_rules do
				local def = registered_spawns[def_index]
				if should_spawn(def, period, num_players) then
					try_spawn_mob(def_index, def)
				end
			end
		else
			local sample = sample_with_indices(registered_spawns, max_spawn_rules_per_iteration)
			for i = 1, max_spawn_rules_per_iteration do
				local def_index, def = unpack(sample[i])
				if should_spawn(def, period * num_spawn_rules / max_spawn_rules_per_iteration, num_players) then
					try_spawn_mob(def_index, def)
				end
			end
		end
		spawnit.stats.spawn_mobs_duration = spawnit.stats.spawn_mobs_duration + (get_us_time() - start)
	end,
})
