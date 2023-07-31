local math_ceil = math.ceil
local math_cos = math.cos
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_pi = math.pi
local math_random = math.random
local math_sqrt = math.sqrt

local shuffle = table.shuffle

local deg2rad = futil.math.deg2rad
local equals = futil.equals
local get_block_center = futil.vector.get_block_center
local get_blockpos = futil.vector.get_blockpos
local in_bounds = futil.math.in_bounds
local random_choice = futil.random.choice
local random_sample = futil.random.sample

local get_node_light = minetest.get_node_light
local get_natural_light = minetest.get_natural_light
local get_objects_inside_radius = minetest.get_objects_inside_radius
local get_position_from_hash = minetest.get_position_from_hash
local get_timeofday = minetest.get_timeofday
local hash_node_position = minetest.hash_node_position

local MAP_BLOCKSIZE = minetest.MAP_BLOCKSIZE
local BLOCK_MAX_RADIUS = math.sqrt(3) / 2 * MAP_BLOCKSIZE

local active_block_range = tonumber(minetest.settings:get("active_block_range")) or 4
local active_object_send_range_blocks = tonumber(minetest.settings:get("active_object_send_range_blocks")) or 8
local movement_walk_speed = tonumber(minetest.settings:get("movement_speed_walk")) or 4.0

local max_object_distance = MAP_BLOCKSIZE * (math_max(active_block_range, active_object_send_range_blocks) + 1)

local s = spawnit.settings

spawnit.util = {}

function spawnit.util.spawns_near_something(def)
	local near = def.near
	for i = 1, #near do
		if near[i] == "any" then
			return false
		end
	end

	return true
end

function spawnit.util.spawns_on_something(def)
	local on = def.on
	for i = 1, #on do
		if on[i] == "any" then
			return false
		end
	end

	return true
end

function spawnit.util.is_full_nodebox(nodebox)
	return nodebox.type == "regular"
		or (nodebox.type == "fixed" and equals(nodebox.fixed, { -0.5, -0.5, -0.5, 0.5, 0.5, 0.5 }))
end

local function min_x_offset(cb)
	return math_min(0, math_floor(cb[1] + 0.5))
end

local function min_y_offset(cb)
	return math_min(0, math_floor(cb[2] + 0.5))
end

local function min_z_offset(cb)
	return math_min(0, math_floor(cb[3] + 0.5))
end

local function max_x_offset(cb)
	return math_max(0, math_ceil(cb[4] - 0.5))
end

local function max_y_offset(cb)
	return math_max(0, math_ceil(cb[5] - 0.5))
end

local function max_z_offset(cb)
	return math_max(0, math_ceil(cb[6] - 0.5))
end

function spawnit.util.get_in_entity_indices(def, va, i)
	local cb = def.collisionbox
	local pos0 = va:position(i)
	local x0, y0, z0 = pos0.x, pos0.y, pos0.z
	local indices = {}
	for y = y0 + min_y_offset(cb), y0 + max_y_offset(cb) do
		for x = x0 + min_x_offset(cb), x0 + max_x_offset(cb) do
			for z = z0 + min_z_offset(cb), z0 + max_z_offset(cb) do
				indices[#indices + 1] = va:index(x, y, z)
			end
		end
	end
	return indices
end

function spawnit.util.get_under_entity_indices(def, va, i)
	local cb = def.collisionbox
	local pos0 = va:position(i)
	local x0, y0, z0 = pos0.x, pos0.y, pos0.z
	local indices = {}
	local y = y0 + min_y_offset(cb) - 1
	for x = x0 + min_x_offset(cb), x0 + max_x_offset(cb) do
		for z = z0 + min_z_offset(cb), z0 + max_z_offset(cb) do
			indices[#indices + 1] = va:index(x, y, z)
		end
	end
	return indices
end

-- get positions inside or touching the entity on 6 faces. doesn't include edges and corners of the bounding box
function spawnit.util.get_near_entity_indices(def, va, i)
	local cb = def.collisionbox
	local pos0 = va:position(i)
	local x0, y0, z0 = pos0.x, pos0.y, pos0.z
	local min_x, max_x = x0 + min_x_offset(cb), x0 + max_x_offset(cb)
	local min_y, max_y = y0 + min_y_offset(cb), y0 + max_y_offset(cb)
	local min_z, max_z = z0 + min_z_offset(cb), z0 + max_z_offset(cb)
	local indices = spawnit.util.get_in_entity_indices(def, va, i) -- consider things inside to be near too!
	do -- left x face
		local x = min_x - 1
		for y = min_y, max_y do
			for z = min_z, max_z do
				indices[#indices + 1] = va:index(x, y, z)
			end
		end
	end
	do -- right x face
		local x = max_x + 1
		for y = min_y, max_y do
			for z = min_z, max_z do
				indices[#indices + 1] = va:index(x, y, z)
			end
		end
	end
	do -- bottom y face
		local y = min_y - 1
		for x = min_x, max_x do
			for z = min_z, max_z do
				indices[#indices + 1] = va:index(x, y, z)
			end
		end
	end
	do -- top y face
		local y = max_y + 1
		for x = min_x, max_x do
			for z = min_z, max_z do
				indices[#indices + 1] = va:index(x, y, z)
			end
		end
	end
	do -- low z face
		local z = min_z - 1
		for x = min_x, max_x do
			for y = min_y, max_y do
				indices[#indices + 1] = va:index(x, y, z)
			end
		end
	end
	do -- high z face
		local z = max_z + 1
		for x = min_x, max_x do
			for y = min_y, max_y do
				indices[#indices + 1] = va:index(x, y, z)
			end
		end
	end
	return indices
end

local function is_valid_player(player, def)
	local pos = player:get_pos():round()

	return in_bounds(def.min_y, pos.y, def.max_y)
end

-- probabilistic; should return true approximately once per `def.chance` seconds, if other conditions are met
function spawnit.util.should_spawn(def, period, players)
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
function spawnit.util.pick_a_cluster(def_index, def)
	local block_hposs_set = spawnit._block_hposs_by_def[def_index]
	if not block_hposs_set or block_hposs_set:size() == 0 then
		-- nowhere to spawn
		return {}
	end
	local block_hposs_list = {}
	for block_hpos in block_hposs_set:iterate() do
		block_hposs_list[#block_hposs_list + 1] = block_hpos
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

-- is a block at a blockpos considered to be "within the sight of a player" given where they're looking?
-- https://github.com/minetest/minetest/blob/4a14a187991c25e8942a7c032b74c468872a51c7/src/util/numeric.cpp#L117-L171
function spawnit.util.is_block_in_sight(blockpos, camera_pos, camera_dir, camera_fov, r_blocks)
	local r_nodes = r_blocks * MAP_BLOCKSIZE
	local center = get_block_center(blockpos)
	local relative = center - camera_pos
	local d = math_max(0, relative:length() - BLOCK_MAX_RADIUS)
	if d == 0 then
		return true
	elseif d > r_nodes then
		return false
	end

	local adjdist = BLOCK_MAX_RADIUS / math_cos((math_pi - camera_fov) / 2)
	local blockpos_adj = center - (camera_pos - camera_dir * adjdist)
	local dforward = blockpos_adj:dot(camera_dir)
	local cosangle = dforward / blockpos_adj:length()
	return cosangle >= math_cos(camera_fov * 0.55)
end

-- we have no way of telling what the client's desired FOV is. if the server isn't overriding it, assume 72 degrees.
function spawnit.util.get_fov(player)
	local fov, is_multiplier = player:get_fov()
	if is_multiplier then
		fov = 72 * fov
	elseif fov == 0 then
		fov = 72
	end
	return deg2rad(fov)
end

-- if a block is too far from a player, we will remove it from the cached data.
function spawnit.util.is_too_far(player_pos, block_hpos)
	local blockpos = get_position_from_hash(block_hpos)
	local center = get_block_center(blockpos)
	local dx = (player_pos.x - center.x) ^ 2
	local dy = (player_pos.y - center.y) ^ 2
	local dz = (player_pos.z - center.z) ^ 2
	local too_far_horizontal_ratio = s.too_far_horizontal_ratio ^ 2
	local too_far_vertical_ratio = s.too_far_vertical_ratio ^ 2
	local weighted_distance = math_sqrt((dx + dz) / too_far_horizontal_ratio + dy / too_far_vertical_ratio)
	return weighted_distance > max_object_distance
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
			if minetest.is_player(obj) then
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
			if minetest.is_player(objs[i]) then
				return true
			end
		end
	elseif def.max_player_distance >= 0 then
		local objs = get_objects_inside_radius(pos, def.max_player_distance)
		local found_any = false
		for i = 1, #objs do
			if minetest.is_player(objs[i]) then
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

function spawnit.util.check_pos_against_def(def, pos)
	if too_many_in_area(def, pos) then
		return false, false
	end

	if wrong_distance_to_players(def, pos) then
		return false, false
	end

	return true
end

function spawnit.util.remove_spawn_position(def_index, pos)
	local hpos = hash_node_position(pos)
	local blockpos = get_blockpos(pos)
	local block_hpos = hash_node_position(blockpos)
	local spawn_poss = spawnit._spawn_poss_by_block_hpos[block_hpos]
	if spawn_poss and spawn_poss:remove_hpos(def_index, hpos) then
		spawnit._block_hposs_by_def[def_index]:remove(block_hpos)
	end
end

-- used by the async callback. the async env can't check for protection, so we have to do it in the main thread.
function spawnit.util.cull_protected_positions(hpos_set_by_def)
	local is_protected = minetest.is_protected
	for def_index, hpos_set in pairs(hpos_set_by_def) do
		local spawn_def = spawnit.registered_spawns[def_index]
		if not spawn_def.spawn_in_protected then
			local entity = spawn_def.entity_name
			local any_left = false
			for hpos in hpos_set:iterate() do
				if is_protected(get_position_from_hash(hpos), entity) then
					hpos_set:remove(hpos)
				else
					any_left = true
				end
			end
			if not any_left then
				hpos_set_by_def[def_index] = nil
			end
		end
	end
end

function spawnit.util.is_moving_too_fast(obj)
	local max_speed = s.player_move_too_fast_ratio * movement_walk_speed
	local attached = obj:get_attach()
	while attached do
		obj = attached
		attached = obj:get_attach()
	end

	if obj:get_velocity():length() >= max_speed then
		return true
	end
end

if INIT == "game" then
	-- util is also loaded by the async env, but player info and e.g. register_on_joinplayer is not available there

	local previous_pos_and_look_by_player_name = {}

	minetest.register_on_joinplayer(function(player)
		local player_name = player:get_player_name()
		previous_pos_and_look_by_player_name[player_name] = { player:get_pos(), player:get_look_dir() }
	end)

	minetest.register_on_leaveplayer(function(player)
		local player_name = player:get_player_name()
		previous_pos_and_look_by_player_name[player_name] = nil
	end)

	-- used to check whether a player's active blocks need to be updated
	function spawnit.util.has_changed_pos_or_look(player)
		local player_name = player:get_player_name()
		local pos = player:get_pos()
		local look = player:get_look_dir()
		local previous_pos, previous_look = unpack(previous_pos_and_look_by_player_name[player_name])
		previous_pos_and_look_by_player_name[player_name] = { pos, look }
		if active_object_send_range_blocks <= active_block_range then
			return not pos:equals(previous_pos)
		else
			return not (pos:equals(previous_pos) and look:equals(previous_look))
		end
	end
end
