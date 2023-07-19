local math_ceil = math.ceil
local math_cos = math.cos
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_pi = math.pi
local math_random = math.random

local choice = futil.random.choice
local deg2rad = futil.math.deg2rad
local equals = futil.equals
local get_block_center = futil.vector.get_block_center
local get_blockpos = futil.vector.get_blockpos
local sample = futil.random.sample

local get_node_light = minetest.get_node_light
local get_objects_inside_radius = minetest.get_objects_inside_radius
local get_position_from_hash = minetest.get_position_from_hash
local get_timeofday = minetest.get_timeofday
local get_us_time = minetest.get_us_time
local hash_node_position = minetest.hash_node_position

local MAP_BLOCKSIZE = minetest.MAP_BLOCKSIZE
local BLOCK_MAX_RADIUS = math.sqrt(3) / 2 * MAP_BLOCKSIZE

local active_block_range = tonumber(minetest.settings:get("active_block_range")) or 4
local active_object_send_range_blocks = tonumber(minetest.settings:get("active_object_send_range_blocks")) or 8
local movement_walk_speed = tonumber(minetest.settings:get("movement_speed_walk")) or 4.0

local max_object_distance = math.sqrt(3)
	* MAP_BLOCKSIZE
	* (math_max(active_block_range, active_object_send_range_blocks) + 1)

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

function spawnit.util.get_in_entity_indices(def, va, i)
	local cb = def.collisionbox
	local pos0 = va:position(i)
	local x0, y0, z0 = pos0.x, pos0.y, pos0.z
	local indices = {}
	for y = y0 + math_min(0, math_floor(cb[2] + 0.5)), y0 + math_max(0, math_ceil(cb[5] - 0.5)) do
		for x = x0 + math_min(0, math_floor(cb[1] + 0.5)), x0 + math_max(0, math_ceil(cb[4] - 0.5)) do
			for z = z0 + math_min(0, math_floor(cb[3] + 0.5)), z0 + math_max(0, math_ceil(cb[6] - 0.5)) do
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
	local y = y0 + math_floor(cb[2] + 0.5) - 1
	for x = x0 + math_min(0, math_floor(cb[1] + 0.5)), x0 + math_max(0, math_ceil(cb[4] - 0.5)) do
		for z = z0 + math_min(0, math_floor(cb[3] + 0.5)), z0 + math_max(0, math_ceil(cb[6] - 0.5)) do
			indices[#indices + 1] = va:index(x, y, z)
		end
	end
	return indices
end

-- get nodes touching the entity on 6 faces. does't (usually?) include edges and corners of the bounding box
-- TODO this is confusing, is there a way we can make the calculations easier to understand?
function spawnit.util.get_near_entity_indices(def, va, i)
	local cb = def.collisionbox
	local pos0 = va:position(i)
	local x0, y0, z0 = pos0.x, pos0.y, pos0.z
	local indices = {}
	do -- left x face
		local x = x0 + math_floor(cb[1] + 0.5) - 1
		for y = y0 + math_min(0, math_floor(cb[2] + 0.5)), y0 + math_max(0, math_ceil(cb[5] - 0.5)) do
			for z = z0 + math_min(0, math_floor(cb[3] + 0.5)), z0 + math_max(0, math_ceil(cb[6] - 0.5)) do
				indices[#indices + 1] = va:index(x, y, z)
			end
		end
	end
	do -- right x face
		local x = x0 + math_ceil(cb[4] - 0.5) + 1
		for y = y0 + math_min(0, math_floor(cb[2] + 0.5)), y0 + math_max(0, math_ceil(cb[5] - 0.5)) do
			for z = z0 + math_min(0, math_floor(cb[3] + 0.5)), z0 + math_max(0, math_ceil(cb[6] - 0.5)) do
				indices[#indices + 1] = va:index(x, y, z)
			end
		end
	end
	do -- bottom y face
		local y = y0 + math_floor(cb[2] + 0.5) - 1
		for x = x0 + math_min(0, math_floor(cb[1] + 0.5)), x0 + math_max(0, math_ceil(cb[4] - 0.5)) do
			for z = z0 + math_min(0, math_floor(cb[3] + 0.5)), z0 + math_max(0, math_ceil(cb[6] - 0.5)) do
				indices[#indices + 1] = va:index(x, y, z)
			end
		end
	end
	do -- top y face
		local y = y0 + math_ceil(cb[5] - 0.5) + 1
		for x = x0 + math_min(0, math_floor(cb[1] + 0.5)), x0 + math_max(0, math_ceil(cb[4] - 0.5)) do
			for z = z0 + math_min(0, math_floor(cb[3] + 0.5)), z0 + math_max(0, math_ceil(cb[6] - 0.5)) do
				indices[#indices + 1] = va:index(x, y, z)
			end
		end
	end
	do -- low z face
		local z = z0 + math_floor(cb[3] + 0.5) - 1
		for x = x0 + math_min(0, math_floor(cb[1] + 0.5)), x0 + math_max(0, math_ceil(cb[4] - 0.5)) do
			for y = y0 + math_min(0, math_floor(cb[2] + 0.5)), y0 + math_max(0, math_ceil(cb[5] - 0.5)) do
				indices[#indices + 1] = va:index(x, y, z)
			end
		end
	end
	do -- high z face
		local z = z0 + math_ceil(cb[6] - 0.5) + 1
		for x = x0 + math_min(0, math_floor(cb[1] + 0.5)), x0 + math_max(0, math_ceil(cb[4] - 0.5)) do
			for y = y0 + math_min(0, math_floor(cb[2] + 0.5)), y0 + math_max(0, math_ceil(cb[5] - 0.5)) do
				indices[#indices + 1] = va:index(x, y, z)
			end
		end
	end
	return indices
end

-- probabilistic; should return true approximately once per `def.chance` seconds, if other conditions are met
function spawnit.util.should_spawn(def, period, num_players)
	local r = math_random()
	if def.per_player then
		if r >= (period * num_players) / (def.chance * s.spawn_chance_multiplier) then
			return false
		end
	else
		if r >= period / (def.chance * s.spawn_chance_multiplier) then
			return false
		end
	end

	if def.max_active and def.max_active > 0 and spawnit.get_active_count(def.entity_name) >= def.max_active then
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
local function check_pos_for_cluster(def, pos)
	local light = get_node_light(pos)
	if not light then
		-- indicates location isn't loaded
		return false
	end

	-- TODO: use futil.math.in_bounds
	if def.min_light > light or light > def.max_light then
		return false
	end

	-- TODO: should we also check artificial and natural light? probably

	-- protection could have changed, so check again
	if (not def.spawn_in_protected) and minetest.is_protected(pos, def.entity_name) then
		return false
	end

	if def.check_pos and not def.check_pos(pos) then
		return false
	end

	return true
end

-- for a given spawn definition, pick a cluster of positions to spawn some mobs, if possible
-- the cluster will all reside within the same mapblock
function spawnit.util.pick_a_cluster(def_index, def)
	local block_hposs_set = spawnit.block_hposs_by_def[def_index]
	if not block_hposs_set or block_hposs_set:size() == 0 then
		-- nowhere to spawn
		return {}
	end
	local block_hposs_list = {}
	for block_hpos in block_hposs_set:iterate() do
		block_hposs_list[#block_hposs_list + 1] = block_hpos
	end
	local poss = {}
	for _ = 1, 5 do
		-- TODO: we ought to keep from checking the same block twice here (futil.random.sample?)
		local block_hpos = block_hposs_list[math_random(#block_hposs_list)]
		local spawn_poss = spawnit.spawn_poss_by_block_hpos[block_hpos]
		if spawn_poss then
			local hpos_set = spawn_poss:get_hpos_set(def_index)
			local filtered = {}
			for hpos in hpos_set:iterate() do
				local pos = get_position_from_hash(hpos)
				if check_pos_for_cluster(def, pos) then
					filtered[#filtered + 1] = pos
				end
				-- TODO: should we remove the position if it's not fit? i guess light levels can change...
			end
			if #filtered >= def.cluster then
				poss = filtered
				break
			elseif #filtered > #poss then
				poss = filtered
			end
		end
	end
	if #poss <= def.cluster then
		return poss
	elseif def.cluster == 1 then
		return { choice(poss) }
	else
		return sample(poss, def.cluster)
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
	return player_pos:distance(center) > s.too_far_ratio * max_object_distance
end

function spawnit.util.final_check(def, pos)
	-- TODO: rename this
	if def.max_in_area and def.max_in_area > 0 then
		local radius = def.max_in_area_radius
		local count = 0
		local objs = get_objects_inside_radius(pos, radius)
		for i = 1, #objs do
			local e = objs[i]:get_luaentity()
			if e and e.name == def.entity_name then
				count = count + 1
				if count >= def.max_in_area then
					return false
				end
			end
		end
	end

	if def.min_player_distance and def.max_player_distance then
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
			return false
		end
	elseif def.min_player_distance then
		local objs = get_objects_inside_radius(pos, def.min_player_distance)
		for i = 1, #objs do
			if minetest.is_player(objs[i]) then
				return false
			end
		end
	elseif def.max_player_distance then
		local objs = get_objects_inside_radius(pos, def.max_player_distance)
		local found_any = false
		for i = 1, #objs do
			if minetest.is_player(objs[i]) then
				found_any = true
				break
			end
		end
		if not found_any then
			return false
		end
	end

	return true
end

function spawnit.util.remove_spawn_position(def_index, pos)
	local hpos = hash_node_position(pos)
	local blockpos = get_blockpos(pos)
	local block_hpos = hash_node_position(blockpos)
	local spawn_poss = spawnit.spawn_poss_by_block_hpos[block_hpos]
	if spawn_poss and spawn_poss:remove_hpos(def_index, hpos) then
		spawnit.block_hposs_by_def[def_index]:remove(block_hpos)
	end
end

function spawnit.util.cull_protected_positions(hpos_set_by_def)
	local is_protected = minetest.is_protected
	for def_index, hpos_set in pairs(hpos_set_by_def) do
		local def = spawnit.registered_spawns[def_index]
		local entity = def.entity_name
		local any_left = false
		if not def.spawn_in_protected then
			for hpos in hpos_set:iterate() do
				if is_protected(get_position_from_hash(hpos), entity) then
					hpos_set:remove(hpos)
				else
					any_left = true
				end
			end
		end
		if not any_left then
			hpos_set_by_def[def_index] = nil
		end
	end
end

-- used to track a player's movement speed in case they're in a minecart or something
local previous_pos_and_time_by_player_name = {}

if INIT == "game" then
	minetest.register_on_joinplayer(function(player)
		local player_name = player:get_player_name()
		previous_pos_and_time_by_player_name[player_name] = { player:get_pos(), get_us_time() }
	end)

	minetest.register_on_leaveplayer(function(player)
		local player_name = player:get_player_name()
		previous_pos_and_time_by_player_name[player_name] = nil
	end)
end

function spawnit.util.is_moving_too_fast(player)
	local max_speed = s.player_move_too_fast_ratio * movement_walk_speed
	if player:get_velocity():length() >= max_speed then
		return true
	end
	local player_name = player:get_player_name()
	local previous_pos_and_time = previous_pos_and_time_by_player_name[player_name]
	local pos = player:get_pos()
	local now = get_us_time()
	if not previous_pos_and_time then
		previous_pos_and_time_by_player_name[player_name] = { pos, now }
		return false
	end
	local previous_pos, previous_time = unpack(previous_pos_and_time)
	local too_fast = pos:distance(previous_pos) / (now - previous_time) >= max_speed
	previous_pos_and_time_by_player_name[player_name] = { pos, now }
	return too_fast
end

-- used to check whether a player's active blocks need to be updated
local previous_pos_and_look_by_player_name = {}

if INIT == "game" then
	minetest.register_on_joinplayer(function(player)
		local player_name = player:get_player_name()
		previous_pos_and_look_by_player_name[player_name] = { player:get_pos(), player:get_look_dir() }
	end)

	minetest.register_on_leaveplayer(function(player)
		local player_name = player:get_player_name()
		previous_pos_and_look_by_player_name[player_name] = nil
	end)
end

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
