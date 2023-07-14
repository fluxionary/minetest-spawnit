local MAP_BLOCKSIZE = minetest.MAP_BLOCKSIZE
local BLOCK_MAX_RADIUS = math.sqrt(3) / 2 * MAP_BLOCKSIZE

local active_block_range = tonumber(minetest.settings:get("active_block_range")) or 4
local active_object_send_range_blocks = tonumber(minetest.settings:get("active_object_send_range_blocks")) or 8

local too_far = math.sqrt(3) * MAP_BLOCKSIZE * (math.max(active_block_range, active_object_send_range_blocks) + 1)

local s = spawnit.settings

spawnit.util = {}

function spawnit.util.spawns_on_ground(def)
	for _, on in ipairs(def.on) do
		if on == "any" then
			return false
		end
	end

	return true
end

function spawnit.util.is_full_nodebox(nodebox)
	return nodebox.type == "regular"
		or (nodebox.type == "fixed" and futil.equals(nodebox.fixed, { -0.5, -0.5, -0.5, 0.5, 0.5, 0.5 }))
end

function spawnit.util.get_in_entity_indices(def, va, i)
	local cb = def.collisionbox
	local pos0 = va:position(i)
	local x0, y0, z0 = pos0.x, pos0.y, pos0.z
	local indices = {}
	for y = y0 + math.floor(cb[2] + 0.5), y0 + math.ceil(cb[5] - 0.5) do
		for x = x0 + math.floor(cb[1] + 0.5), x0 + math.ceil(cb[4] - 0.5) do
			for z = z0 + math.floor(cb[3] + 0.5), z0 + math.ceil(cb[6] - 0.5) do
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
	local y = y0 + math.floor(cb[2] + 0.5) - 1
	for x = x0 + math.floor(cb[1] + 0.5), x0 + math.ceil(cb[4] - 0.5) do
		for z = z0 + math.floor(cb[3] + 0.5), z0 + math.ceil(cb[6] - 0.5) do
			indices[#indices + 1] = va:index(x, y, z)
		end
	end
	return indices
end

-- probabilistic; should return true approximately once per `def.chance` seconds
function spawnit.util.should_spawn(def, period, num_players)
	local r = math.random()
	if def.per_player then
		if r >= (period * num_players) / def.chance then
			return false
		end
	else
		if r >= period / def.chance then
			return false
		end
	end

	if def.max_active and spawnit.get_active_count(def.entity) >= def.max_active then
		return false
	end

	local tod = minetest.get_timeofday()
	if def.min_time_of_day < def.max_time_of_day then
		if tod < def.min_time_of_day or def.max_time_of_day < tod then
			return false
		end
	else
		if tod > def.min_time_of_day or def.max_time_of_day > tod then
			return false
		end
	end

	return true
end

local function check_pos(def, pos)
	local light = minetest.get_node_light(pos)
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
	local hposs = spawnit.hposs_by_def[def_index]
	if not hposs then
		-- nowhere to spawn
		return {}
	end
	local hposs_t = {}
	for hpos in pairs(hposs) do
		hposs_t[#hposs + 1] = hpos
	end
	if #hposs_t == 0 then
		-- nowhere to spawn
		return {}
	end
	local poss = {}
	for _ = 1, 5 do
		local hpos = hposs_t[math.random(#hposs_t)]
		local spawn_poss = spawnit.spawn_poss_by_hpos[hpos]
		if spawn_poss then
			local possible_poss = spawn_poss:get_poss(def_index)
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
	if #poss <= def.cluster then
		return poss
	elseif def.cluster == 1 then
		return { futil.random.choice(poss) }
	else
		return futil.random.sample(poss, def.cluster)
	end
end

-- https://github.com/minetest/minetest/blob/4a14a187991c25e8942a7c032b74c468872a51c7/src/util/numeric.cpp#L117-L171
function spawnit.util.is_block_in_sight(block, camera_pos, camera_dir, camera_fov, r_blocks)
	local r_nodes = r_blocks * MAP_BLOCKSIZE
	local center = block:get_center()
	local relative = center - camera_pos
	local d = math.max(0, relative:length() - BLOCK_MAX_RADIUS)
	if d == 0 then
		return true
	elseif d > r_nodes then
		return false
	end

	local adjdist = BLOCK_MAX_RADIUS / math.cos((math.pi - camera_fov) / 2)
	local blockpos_adj = center - (camera_pos - camera_dir * adjdist)
	local dforward = blockpos_adj:dot(camera_dir)
	local cosangle = dforward / blockpos_adj:length()
	return cosangle >= math.cos(camera_fov * 0.55)
end

function spawnit.util.get_fov(player)
	local fov, is_multiplier = player:get_fov()
	if is_multiplier then
		fov = 72 * fov
	elseif fov == 0 then
		fov = 72
	end
	return futil.math.deg2rad(fov)
end

function spawnit.util.is_too_far(player_pos, block_hpos)
	local blockpos = minetest.get_position_from_hash(block_hpos)
	local block = spawnit.Block(blockpos)
	return player_pos:distance(block:get_center()) > s.too_far_ratio * too_far
end

function spawnit.util.final_check(def, pos)
	if def.max_in_area then
		local count = 0
		local objs = minetest.get_objects_in_area(vector.subtract(pos, def.radius), vector.add(pos, def.radius))
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

	return true
end
