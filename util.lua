local math_ceil = math.ceil
local math_cos = math.cos
local math_floor = math.floor
local math_max = math.max
local math_pi = math.pi
local math_random = math.random

local choice = futil.random.choice
local deg2rad = futil.math.deg2rad
local equals = futil.equals
local sample = futil.random.sample

local get_node_light = minetest.get_node_light
local get_objects_inside_radius = minetest.get_objects_inside_radius
local get_position_from_hash = minetest.get_position_from_hash
local get_timeofday = minetest.get_timeofday

local MAP_BLOCKSIZE = minetest.MAP_BLOCKSIZE
local BLOCK_MAX_RADIUS = math.sqrt(3) / 2 * MAP_BLOCKSIZE

local active_block_range = tonumber(minetest.settings:get("active_block_range")) or 4
local active_object_send_range_blocks = tonumber(minetest.settings:get("active_object_send_range_blocks")) or 8

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
	for y = y0 + math_floor(cb[2] + 0.5), y0 + math_ceil(cb[5] - 0.5) do
		for x = x0 + math_floor(cb[1] + 0.5), x0 + math_ceil(cb[4] - 0.5) do
			for z = z0 + math_floor(cb[3] + 0.5), z0 + math_ceil(cb[6] - 0.5) do
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
	for x = x0 + math_floor(cb[1] + 0.5), x0 + math_ceil(cb[4] - 0.5) do
		for z = z0 + math_floor(cb[3] + 0.5), z0 + math_ceil(cb[6] - 0.5) do
			indices[#indices + 1] = va:index(x, y, z)
		end
	end
	return indices
end

function spawnit.util.get_near_entity_indices(def, va, i)
	local cb = def.collisionbox
	local pos0 = va:position(i)
	local x0, y0, z0 = pos0.x, pos0.y, pos0.z
	local indices = {}
	do
		local x = x0 + math_floor(cb[1] + 0.5) - 1
		for y = y0 + math_floor(cb[2] + 0.5), y0 + math_ceil(cb[5] - 0.5) do
			for z = z0 + math_floor(cb[3] + 0.5), z0 + math_ceil(cb[6] - 0.5) do
				indices[#indices + 1] = va:index(x, y, z)
			end
		end
	end
	do
		local x = x0 + math_floor(cb[4] - 0.5) + 1
		for y = y0 + math_floor(cb[2] + 0.5), y0 + math_ceil(cb[5] - 0.5) do
			for z = z0 + math_floor(cb[3] + 0.5), z0 + math_ceil(cb[6] - 0.5) do
				indices[#indices + 1] = va:index(x, y, z)
			end
		end
	end
	do
		local y = y0 + math_floor(cb[2] + 0.5) - 1
		for x = x0 + math_floor(cb[1] + 0.5), x0 + math_ceil(cb[4] - 0.5) do
			for z = z0 + math_floor(cb[3] + 0.5), z0 + math_ceil(cb[6] - 0.5) do
				indices[#indices + 1] = va:index(x, y, z)
			end
		end
	end
	do
		local y = y0 + math_floor(cb[5] - 0.5) + 1
		for x = x0 + math_floor(cb[1] + 0.5), x0 + math_ceil(cb[4] - 0.5) do
			for z = z0 + math_floor(cb[3] + 0.5), z0 + math_ceil(cb[6] - 0.5) do
				indices[#indices + 1] = va:index(x, y, z)
			end
		end
	end
	do
		local z = z0 + math_floor(cb[3] + 0.5) - 1
		for x = x0 + math_floor(cb[1] + 0.5), x0 + math_ceil(cb[4] - 0.5) do
			for y = y0 + math_floor(cb[2] + 0.5), y0 + math_ceil(cb[5] - 0.5) do
				indices[#indices + 1] = va:index(x, y, z)
			end
		end
	end
	do
		local z = z0 + math_floor(cb[6] - 0.5) + 1
		for x = x0 + math_floor(cb[1] + 0.5), x0 + math_ceil(cb[4] - 0.5) do
			for y = y0 + math_floor(cb[2] + 0.5), y0 + math_ceil(cb[5] - 0.5) do
				indices[#indices + 1] = va:index(x, y, z)
			end
		end
	end
	return indices
end

-- probabilistic; should return true approximately once per `def.chance` seconds
function spawnit.util.should_spawn(def, period, num_players)
	if def.should_spawn and not def.should_spawn() then
		return false
	end

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

	if def.max_active and def.max_active > 0 and spawnit.get_active_count(def.entity) >= def.max_active then
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

	return true
end

local function check_pos(def, pos)
	local light = get_node_light(pos)
	if not light then
		-- indicates location isn't loaded
		return false
	end

	if def.min_light > light or light > def.max_light then
		return false
	end

	-- protection could have changed, so check again
	if (not def.spawn_in_protected) and minetest.is_protected(pos, def.entity) then
		return false
	end

	if def.check_pos and not def.check_pos(pos) then
		return false
	end

	return true
end

function spawnit.util.pick_a_cluster(def_index, def)
	local hposs_set = spawnit.hposs_by_def[def_index]
	if not hposs_set or hposs_set:size() == 0 then
		-- nowhere to spawn
		return {}
	end
	local hposs_list = {}
	for hpos in hposs_set:iterate() do
		hposs_list[#hposs_list + 1] = hpos
	end
	local poss = {}
	for _ = 1, 5 do
		local hpos = hposs_list[math_random(#hposs_list)]
		local spawn_poss = spawnit.spawn_poss_by_hpos[hpos]
		if spawn_poss then
			local possible_poss = spawn_poss:get_poss(def_index)
			if possible_poss and #possible_poss > 0 then
				local filtered = {}
				for i = 1, #possible_poss do
					local pos = possible_poss[i]
					if check_pos(def, pos) then
						filtered[#filtered + 1] = pos
					end
				end
				if #filtered >= def.cluster then
					poss = filtered
					break
				elseif #filtered > #poss then
					poss = filtered
				end
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

-- https://github.com/minetest/minetest/blob/4a14a187991c25e8942a7c032b74c468872a51c7/src/util/numeric.cpp#L117-L171
function spawnit.util.is_block_in_sight(block, camera_pos, camera_dir, camera_fov, r_blocks)
	local r_nodes = r_blocks * MAP_BLOCKSIZE
	local center = block:get_center()
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

function spawnit.util.get_fov(player)
	local fov, is_multiplier = player:get_fov()
	if is_multiplier then
		fov = 72 * fov
	elseif fov == 0 then
		fov = 72
	end
	return deg2rad(fov)
end

-- used to remove cached data when it's no longer relevant
function spawnit.util.is_too_far(player_pos, block_hpos)
	local blockpos = get_position_from_hash(block_hpos)
	local block = spawnit.Block(blockpos)
	return player_pos:distance(block:get_center()) > s.too_far_ratio * max_object_distance
end

function spawnit.util.final_check(def, pos)
	-- TODO: rename this
	if def.max_in_area and def.max_in_area > 0 then
		local radius = def.max_in_area_radius
		local count = 0
		local objs = get_objects_inside_radius(pos, radius)
		for i = 1, #objs do
			local e = objs[i]:get_luaentity()
			if e and e.name == def.entity then
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
