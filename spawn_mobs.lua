local get_us_time = minetest.get_us_time

local sample_with_indices = futil.random.sample_with_indices

local s = spawnit.settings

local should_spawn = spawnit.util.should_spawn
local pick_a_cluster = spawnit.util.pick_a_cluster
local check_pos_against_def = spawnit.util.check_pos_against_def
local remove_spawn_position = spawnit.util.remove_spawn_position

local function try_spawn_mob(def_index, def)
	local cluster = pick_a_cluster(def_index, def)
	if #cluster == 0 then
		return
	end

	local any_success = false
	for _, pos in ipairs(cluster) do
		local success, should_remove = check_pos_against_def(def, pos)
		if success then
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
				spawnit._add_spawn_waypoint(pos, entity_name)
				if def.after_spawn then
					def.after_spawn(pos, obj)
				end
				any_success = true
			else
				spawnit.log("warning", "failed to spawn %s @ %s", entity_name, spos)
			end
			spawnit._stats.num_spawned = spawnit._stats.num_spawned + 1
			remove_spawn_position(def_index, pos)
		elseif should_remove then
			remove_spawn_position(def_index, pos)
		end
	end

	return any_success
end

futil.register_globalstep({
	name = "spawnit:spawn_mobs",
	period = s.spawn_mobs_period,
	catchup = "single",
	func = function(period)
		local start = get_us_time()
		local players = minetest.get_connected_players()
		local registered_spawns = spawnit.registered_spawns
		local num_spawn_rules = #registered_spawns
		local max_spawn_rules_per_iteration = s.max_spawn_rules_per_iteration
		local successful_spawns = 0
		if num_spawn_rules <= max_spawn_rules_per_iteration then
			registered_spawns = table.copy(registered_spawns)
			table.shuffle(registered_spawns) -- because we may abort before doing all of these, shuffle them to prevent
			-- rules registered early from dominating
			for def_index = 1, num_spawn_rules do
				local def = registered_spawns[def_index]
				if should_spawn(def, period, players) then
					if try_spawn_mob(def_index, def) then
						successful_spawns = successful_spawns + 1
						if successful_spawns >= s.max_spawn_events_per_iteration then
							return
						end
					end
				end
			end
		else
			local sample = sample_with_indices(registered_spawns, max_spawn_rules_per_iteration)
			table.shuffle(sample) -- sampling doesn't actually produce something w/ a random order.
			-- if element 1 is in the sample, it's always at location 1.
			local adjusted_period = period * num_spawn_rules / max_spawn_rules_per_iteration
			for i = 1, max_spawn_rules_per_iteration do
				local def_index, def = unpack(sample[i])
				if should_spawn(def, adjusted_period, players) then
					if try_spawn_mob(def_index, def) then
						successful_spawns = successful_spawns + 1
						if successful_spawns >= s.max_spawn_events_per_iteration then
							return
						end
					end
				end
			end
		end
		spawnit._stats.spawn_mobs_duration = spawnit._stats.spawn_mobs_duration + (get_us_time() - start)
	end,
})
