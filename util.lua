local MAPBLOCK_SIZE = 16 -- effectively hard-coded, not sure how to query it if it's not...
local BLOCK_MAX_RADIUS = math.sqrt(3) / 2 * MAPBLOCK_SIZE

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

	return true
end

function spawnit.util.pick_a_cluster(def)
	error("TODO: implement")
end

-- https://github.com/minetest/minetest/blob/4a14a187991c25e8942a7c032b74c468872a51c7/src/util/numeric.cpp#L117-L171
function spawnit.util.is_block_in_sight(block, camera_pos, camera_dir, camera_fov, r_blocks)
	local r_nodes = r_blocks * MAPBLOCK_SIZE
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
