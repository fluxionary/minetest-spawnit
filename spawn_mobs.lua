local math_huge = math.huge
local math_random = math.random

local shuffle = table.shuffle

local get_biome_data = minetest.get_biome_data
local get_biome_name = minetest.get_biome_name
local get_natural_light = minetest.get_natural_light
local get_node_light = minetest.get_node_light
local get_objects_inside_radius = minetest.get_objects_inside_radius
local get_position_from_hash = minetest.get_position_from_hash
local get_timeofday = minetest.get_timeofday
local get_us_time = minetest.get_us_time
local hash_node_position = minetest.hash_node_position
local pos_to_string = minetest.pos_to_string

local get_blockpos = futil.vector.get_blockpos
local in_bounds = futil.math.in_bounds
local is_player = futil.is_player
local random_choice = futil.random.choice
local random_sample = futil.random.sample
local sample_with_indices = futil.random.sample_with_indices

local s = spawnit.settings

local function is_valid_player(player, def)
	local pos = player:get_pos():round()

	return in_bounds(def.min_y, pos.y, def.max_y)
end

-- probabilistic; should return true approximately once per `def.chance` seconds, if other conditions are met
local function should_spawn(def, period, players)
	local num_players = 0
	if def.per_player then
		for i = 1, #players do
			if is_valid_player(players[i], def) then
				num_players = num_players + 1
			end
		end
	else
		for i = 1, #players do
			if is_valid_player(players[i], def) then
				num_players = 1
				break
			end
		end
	end

	if num_players == 0 then
		return false
	end

	local r = math_random()
	if r >= (period * num_players) / (def.chance * s.spawn_chance_multiplier) then
		return false
	end

	if def.max_active > 0 and spawnit._get_active_count(def.entity_name) >= def.max_active then
		return false
	end

	local tod = get_timeofday()
	if def.min_time_of_day < def.max_time_of_day then
		if not (def.min_time_of_day <= tod and tod <= def.max_time_of_day) then
			return false
		end
	else
		if not (tod <= def.min_time_of_day or def.max_time_of_day <= tod) then
			return false
		end
	end

	if def.should_spawn and not def.should_spawn() then
		return false
	end

	return true
end

-- do some specific checks about whether to add a position to a cluster
-- rvs: first is whether the position is valid currently, second is whether to remove it from the pool of positions
local function check_pos_for_cluster(def, pos)
	local light = get_node_light(pos)
	if not light then
		-- indicates location isn't loaded
		return false, true
	end

	if not in_bounds(def.min_node_light, light, def.max_node_light) then
		return false, false -- light might change
	end

	if not in_bounds(def.min_natural_light, get_natural_light(pos), def.max_natural_light) then
		return false, false -- light might change
	end

	-- protection could have changed, so check again
	if (not def.spawn_in_protected) and minetest.is_protected(pos, def.entity_name) then
		return false, true
	end

	local biome = def.biome
	local bdata
	if #biome > 0 then
		bdata = get_biome_data(pos)
		if bdata then -- get_biome_data can fail and return nil? i'm not sure why, but it's documented.
			local biome_name = get_biome_name(bdata.biome)
			local biome_matches = false
			for i = 1, #biome do
				if biome_name:match(biome[i]) then
					biome_matches = true
					break
				end
			end
			if not biome_matches then
				return false, true
			end
		end
	end

	if def.min_heat > -math_huge or def.max_heat < math_huge then
		bdata = bdata or get_biome_data(pos)
		if bdata then
			local heat = bdata.heat
			if not in_bounds(def.min_heat, heat, def.max_heat) then
				return false, true
			end
		end
	end

	if def.min_humidity > -math_huge or def.max_humidity < math_huge then
		bdata = bdata or get_biome_data(pos)
		if bdata then
			local humidity = bdata.humidity
			if not in_bounds(def.min_humidity, humidity, def.max_humidity) then
				return false, true
			end
		end
	end

	if def.check_pos then
		local success, should_remove = def.check_pos(pos)
		if not success then
			return false, should_remove
		end
	end

	local registered_pos_checks = spawnit.registered_pos_checks
	for i = 1, #registered_pos_checks do
		local success, should_remove = registered_pos_checks[i](pos, def)
		if not success then
			return false, should_remove
		end
	end

	return true, true
end

-- for a given spawn definition, pick a cluster of positions to spawn some mobs, if possible
-- the points in the cluster will all be from the same mapblock
local function pick_a_cluster(def_index, def)
	local block_hposs_set = spawnit._block_hposs_by_def[def_index]
	if not block_hposs_set or block_hposs_set:size() == 0 then
		-- nowhere to spawn
		return {}
	end
	local block_hposs_list = {}
	for block_hpos in block_hposs_set:iterate() do
		if rawget(spawnit._visibility_by_block_hpos, block_hpos) then
			block_hposs_list[#block_hposs_list + 1] = block_hpos
		end
	end
	local poss = {}
	if #block_hposs_list > s.pick_cluster_trials then
		block_hposs_list = random_sample(block_hposs_list, s.pick_cluster_trials)
	end

	shuffle(block_hposs_list)

	for i = 1, #block_hposs_list do
		local block_hpos = block_hposs_list[i]
		local spawn_poss = spawnit._spawn_poss_by_block_hpos[block_hpos]
		if spawn_poss then
			local hpos_set = spawn_poss:get_hpos_set(def_index)
			local filtered = {}
			for hpos in hpos_set:iterate() do
				local pos = get_position_from_hash(hpos)
				local success, should_remove = check_pos_for_cluster(def, pos)
				if success then
					filtered[#filtered + 1] = pos
				elseif should_remove then
					hpos_set:remove(hpos)
				end
			end
			if #filtered >= def.cluster then
				-- we've found a good cluster
				poss = filtered
				break
			elseif #filtered > #poss then
				-- better than anything we've found previously
				poss = filtered
			end
		end
	end
	if #poss <= def.cluster then
		return poss
	elseif def.cluster == 1 then
		return { random_choice(poss) }
	else
		return random_sample(poss, def.cluster)
	end
end

-- are there already too many of the same kind or of any kind according to the definition?
local function too_many_in_area(def, pos)
	local max_in_area = def.max_in_area
	local max_any_in_area = def.max_any_in_area
	if max_in_area > 0 or max_any_in_area > 0 then
		local relevant_mobs = spawnit._relevant_mobs
		local radius = def.max_in_area_radius
		local count = 0
		local any_count = 0
		local objs = get_objects_inside_radius(pos, radius)
		for i = 1, #objs do
			local name = (objs[i]:get_luaentity() or {}).name
			if name then
				if max_in_area > 0 and name == def.entity_name then
					count = count + 1
					if count >= max_in_area then
						return true
					end
				end
				if max_any_in_area > 0 and relevant_mobs:contains(name) then
					any_count = any_count + 1
					if any_count >= max_any_in_area then
						return true
					end
				end
			end
		end
	end

	return false
end

-- if the definition sets a min or max distance from player, make sure the pos respects those bounds
local function wrong_distance_to_players(def, pos)
	if def.min_player_distance >= 0 and def.max_player_distance >= 0 then
		local objs = get_objects_inside_radius(pos, def.max_player_distance)
		local found_any = false
		for i = 1, #objs do
			local obj = objs[i]
			if is_player(obj) then
				if pos:distance(obj:get_pos()) <= def.min_player_distance then
					found_any = false
					break
				else
					found_any = true
				end
			end
		end
		if not found_any then
			return true
		end
	elseif def.min_player_distance >= 0 then
		local objs = get_objects_inside_radius(pos, def.min_player_distance)
		for i = 1, #objs do
			if is_player(objs[i]) then
				return true
			end
		end
	elseif def.max_player_distance >= 0 then
		local objs = get_objects_inside_radius(pos, def.max_player_distance)
		local found_any = false
		for i = 1, #objs do
			if is_player(objs[i]) then
				found_any = true
				break
			end
		end
		if not found_any then
			return true
		end
	end

	return false
end

local function check_pos_against_def(def, pos)
	if too_many_in_area(def, pos) then
		return false, false
	end

	if wrong_distance_to_players(def, pos) then
		return false, false
	end

	return true
end

local function remove_spawn_position(def_index, pos)
	local hpos = hash_node_position(pos)
	local blockpos = get_blockpos(pos)
	local block_hpos = hash_node_position(blockpos)
	local spawn_poss = spawnit._spawn_poss_by_block_hpos[block_hpos]
	if spawn_poss and spawn_poss:remove_hpos(def_index, hpos) then
		spawnit._block_hposs_by_def[def_index]:remove(block_hpos)
	end
end

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
			local spos = pos_to_string(pos)
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

-- once every `spawn_mobs_period`, pick some spawn definitions and try to spawn things according to them
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
			-- because we may abort before doing all of these, shuffle them to prevent
			-- rules registered earlier from dominating
			table.shuffle(registered_spawns)
			for def_index = 1, num_spawn_rules do
				local def = registered_spawns[def_index]
				if should_spawn(def, period, players) then
					if try_spawn_mob(def_index, def) then
						successful_spawns = successful_spawns + 1
						if successful_spawns >= s.max_spawn_events_per_iteration then
							break
						end
					end
				end
			end
		else
			local sample = sample_with_indices(registered_spawns, max_spawn_rules_per_iteration)
			-- sampling doesn't actually produce something w/ a random order.
			-- if element 1 is in the sample, it's always at location 1.
			table.shuffle(sample)
			local adjusted_period = period * num_spawn_rules / max_spawn_rules_per_iteration
			for i = 1, max_spawn_rules_per_iteration do
				local def_index, def = unpack(sample[i])
				if should_spawn(def, adjusted_period, players) then
					if try_spawn_mob(def_index, def) then
						successful_spawns = successful_spawns + 1
						if successful_spawns >= s.max_spawn_events_per_iteration then
							break
						end
					end
				end
			end
		end
		spawnit._stats.spawn_mobs_duration = spawnit._stats.spawn_mobs_duration + (get_us_time() - start)
	end,
})
