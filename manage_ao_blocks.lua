local v_new = vector.new

local math_cos = math.cos
local math_max = math.max
local math_pi = math.pi
local math_sqrt = math.sqrt

local compare_block_status = minetest.compare_block_status
local get_position_from_hash = minetest.get_position_from_hash
local get_us_time = minetest.get_us_time
local hash_node_position = minetest.hash_node_position

local Set = futil.Set
local deg2rad = futil.math.deg2rad
local get_block_center = futil.vector.get_block_center
local get_block_min = futil.vector.get_block_min
local get_blockpos = futil.vector.get_blockpos
local is_blockpos_inside_world_bounds = futil.vector.is_blockpos_inside_world_bounds

local ACTIVE_BLOCK_RANGE = tonumber(minetest.settings:get("active_block_range")) or 4
local ACTIVE_OBJECT_SEND_RANGE_BLOCKS = tonumber(minetest.settings:get("active_object_send_range_blocks")) or 8
local MAP_BLOCKSIZE = minetest.MAP_BLOCKSIZE
local MOVEMENT_WALK_SPEED = tonumber(minetest.settings:get("movement_speed_walk")) or 4.0

local BLOCK_MAX_RADIUS = math.sqrt(3) * MAP_BLOCKSIZE / 2
local MAX_OBJECT_DISTANCE = MAP_BLOCKSIZE * (math_max(ACTIVE_BLOCK_RANGE, ACTIVE_OBJECT_SEND_RANGE_BLOCKS) + 1)

local s = spawnit.settings

-- we have no way of telling what the client's desired FOV is. if the server isn't overriding it, assume 72 degrees.
local function get_fov(player)
	local fov, is_multiplier = player:get_fov()
	if is_multiplier then
		fov = 72 * fov
	elseif fov == 0 then
		fov = 72
	end
	return deg2rad(fov)
end

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
local function has_changed_pos_or_look(player)
	local player_name = player:get_player_name()
	local pos = player:get_pos()
	local look = player:get_look_dir()
	local previous_pos, previous_look = unpack(previous_pos_and_look_by_player_name[player_name])
	previous_pos_and_look_by_player_name[player_name] = { pos, look }
	if ACTIVE_OBJECT_SEND_RANGE_BLOCKS <= ACTIVE_BLOCK_RANGE then
		return not pos:equals(previous_pos)
	else
		return not (pos:equals(previous_pos) and look:equals(previous_look))
	end
end

-- is a block at a blockpos considered to be "within the sight of a player" given where they're looking?
-- https://github.com/minetest/minetest/blob/4a14a187991c25e8942a7c032b74c468872a51c7/src/util/numeric.cpp#L117-L171
local function is_block_in_sight(blockpos, camera_pos, camera_dir, camera_fov, r_blocks)
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

function spawnit.is_active_object_block(pos)
	local blockpos = get_blockpos(pos)
	local block_hpos = hash_node_position(blockpos)
	return rawget(spawnit._visibility_by_block_hpos, block_hpos) ~= nil
end

local function discard_all_visible_blocks(player)
	local player_name = player:get_player_name()
	local nearby_block_hpos_set = spawnit._nearby_block_hpos_set_by_player_name[player_name]
	for hpos in nearby_block_hpos_set:iterate() do
		local visibility = rawget(spawnit._visibility_by_block_hpos, hpos) -- rawget cuz otherwise creates an empty set
		if visibility then
			visibility:discard(player_name)
			if visibility:is_empty() then
				spawnit._visibility_by_block_hpos[hpos] = nil
			end
		end
	end
end

local function discard_all_player_poss(player)
	discard_all_visible_blocks(player)
	local player_name = player:get_player_name()
	local nearby_block_hpos_set = spawnit._nearby_block_hpos_set_by_player_name[player_name]
	for hpos in nearby_block_hpos_set:iterate() do
		local nearby = spawnit._nearby_players_by_block_hpos[hpos]
		nearby:discard(player_name)
		if nearby:is_empty() then
			spawnit._nearby_players_by_block_hpos[hpos] = nil
			spawnit._clear_spawn_poss(hpos)
		end
	end
end

minetest.register_on_joinplayer(function(player)
	local player_name = player:get_player_name()
	spawnit._nearby_block_hpos_set_by_player_name[player_name] = Set()
end)

minetest.register_on_leaveplayer(function(player)
	local player_name = player:get_player_name()
	discard_all_player_poss(player)
	spawnit._nearby_block_hpos_set_by_player_name[player_name] = nil
end)

local function is_moving_too_fast(obj)
	local max_speed = s.player_moved_too_fast_ratio * MOVEMENT_WALK_SPEED
	local attached = obj:get_attach()
	while attached do
		obj = attached
		attached = obj:get_attach()
	end

	if obj:get_velocity():length() >= max_speed then
		return true
	end
end

-- if a block is too far from a player, we will remove it from the cached data.
local function is_too_far(player_pos, block_hpos)
	local blockpos = get_position_from_hash(block_hpos)
	local center = get_block_center(blockpos)
	local dx = (player_pos.x - center.x) ^ 2
	local dy = (player_pos.y - center.y) ^ 2
	local dz = (player_pos.z - center.z) ^ 2
	local too_far_horizontal_ratio = s.too_far_horizontal_ratio ^ 2
	local too_far_vertical_ratio = s.too_far_vertical_ratio ^ 2
	local weighted_distance = math_sqrt((dx + dz) / too_far_horizontal_ratio + dy / too_far_vertical_ratio)
	return weighted_distance > MAX_OBJECT_DISTANCE
end

-- see `doc/active object regions.md`
-- see also `ActiveBlockList::update` in "serverenvironment.cpp" in the minetest source code
local function get_ao_block_hpos_set(player)
	local block_hpos_set = Set()

	if is_moving_too_fast(player) then
		-- if the player is moving too quickly, don't bother computing which blocks are active, as they will likely
		-- change soon anyway
		return block_hpos_set
	end

	local player_pos = player:get_pos()
	local player_blockpos = get_blockpos(player_pos)
	local x0, y0, z0 = player_blockpos.x, player_blockpos.y, player_blockpos.z
	-- get active blocks
	local r = ACTIVE_BLOCK_RANGE
	for x = x0 - r, x0 + r do
		for y = y0 - r, y0 + r do
			for z = z0 - r, z0 + r do
				local blockpos = v_new(x, y, z)
				if is_blockpos_inside_world_bounds(blockpos) then
					block_hpos_set:add(hash_node_position(blockpos))
				end
			end
		end
	end

	if ACTIVE_OBJECT_SEND_RANGE_BLOCKS <= ACTIVE_BLOCK_RANGE then
		return block_hpos_set
	end

	-- get visible blocks
	local look_dir = player:get_look_dir()
	local properties = player:get_properties()
	local eye_height = properties.eye_height
	local eye_pos = player_pos:offset(0, eye_height, 0)
	local eye_blockpos = get_blockpos(eye_pos)
	x0, y0, z0 = eye_blockpos.x, eye_blockpos.y, eye_blockpos.z
	local fov = get_fov(player)
	-- TODO: this naively looks at every mapblock inside a cube and checks whether it's inside the solid angle,
	--       possibly we could calculate the maximum extents of the solid angle, and only check within those?
	r = ACTIVE_OBJECT_SEND_RANGE_BLOCKS - 1 -- TODO: for some reason w/out -1, this spawns things too far?
	for x = x0 - r, x0 + r do
		for y = y0 - r, y0 + r do
			for z = z0 - r, z0 + r do
				local blockpos = v_new(x, y, z)
				local block_hpos = hash_node_position(blockpos)
				if
					not block_hpos_set[block_hpos]
					and is_blockpos_inside_world_bounds(blockpos)
					and is_block_in_sight(blockpos, eye_pos, look_dir, fov, r)
				then
					block_hpos_set:add(block_hpos)
				end
			end
		end
	end

	return block_hpos_set
end

local player_i = 1

local function pick_a_player(players)
	-- first, we pick a player to update
	player_i = (player_i % #players) + 1
	local player = players[player_i]
	local j = 0
	local trials = math.min(s.update_player_ao_trials, #players)

	if has_changed_pos_or_look(player) then
		return player
	end

	while j < trials do
		j = j + 1
		player_i = (player_i % #players) + 1
		player = players[player_i]

		if has_changed_pos_or_look(player) then
			return player
		end
	end

	-- we didn't find a suitable player to update
	return
end

local function update_visibility(player)
	local player_name = player:get_player_name()
	local player_pos = player:get_pos()
	local nearby_block_hpos_set = spawnit._nearby_block_hpos_set_by_player_name[player_name]
	local new_ao_block_hpos_set = get_ao_block_hpos_set(player)
	local block_hposs_without_spawn_poss = {} -- which mapblocks need to have spawn positions calculated?

	-- first, update the existing set of blocks
	for block_hpos in nearby_block_hpos_set:iterate() do
		local visibility = spawnit._visibility_by_block_hpos[block_hpos]
		local nearby = spawnit._nearby_players_by_block_hpos[block_hpos]

		if new_ao_block_hpos_set:contains(block_hpos) then
			new_ao_block_hpos_set:remove(block_hpos) -- already accounted for, not actually new
			if not spawnit._spawn_poss_by_block_hpos[block_hpos] then
				block_hposs_without_spawn_poss[#block_hposs_without_spawn_poss + 1] = block_hpos
			end
			visibility:add(player_name)
			nearby:add(player_name)
		else
			-- the block isn't active
			visibility:discard(player_name)
			if visibility:is_empty() then
				spawnit._visibility_by_block_hpos[block_hpos] = nil
			end
			if is_too_far(player_pos, block_hpos) then
				nearby_block_hpos_set:remove(block_hpos)
				nearby:discard(player_name)
				if nearby:is_empty() then
					spawnit._nearby_players_by_block_hpos[block_hpos] = nil
					spawnit._clear_spawn_poss(block_hpos)
				end
			end
		end
	end

	-- next, process new blocks
	for block_hpos in new_ao_block_hpos_set:iterate() do
		if not spawnit._spawn_poss_by_block_hpos[block_hpos] then
			block_hposs_without_spawn_poss[#block_hposs_without_spawn_poss + 1] = block_hpos
		end
		nearby_block_hpos_set:add(block_hpos)
		local visibility = spawnit._visibility_by_block_hpos[block_hpos]
		visibility:add(player_name)
		local nearby = spawnit._nearby_players_by_block_hpos[block_hpos]
		nearby:add(player_name)
	end

	return block_hposs_without_spawn_poss
end

local function update_spawn_positions(player, players, block_hposs_without_spawn_poss)
	local player_pos = player:get_pos()

	-- finally, queue up processing of spawn positions as necessary
	-- first, sort the blocks by distance from the player
	table.sort(block_hposs_without_spawn_poss, function(block_hpos1, block_hpos2)
		local block_center1 = get_block_center(get_position_from_hash(block_hpos1))
		local block_center2 = get_block_center(get_position_from_hash(block_hpos2))
		return player_pos:distance(block_center1) < player_pos:distance(block_center2)
	end)
	local max_add_to_queue_per_ao_period = math.ceil(s.max_queue_size / math.max(1, #players - 1))
	for i = 1, math.min(#block_hposs_without_spawn_poss, max_add_to_queue_per_ao_period) do
		local block_hpos = block_hposs_without_spawn_poss[i]
		local blockpos = get_position_from_hash(block_hpos)
		local pos = get_block_min(blockpos)
		if compare_block_status(pos, "loaded") then
			spawnit._find_spawn_poss(block_hpos)
		end
	end
end

futil.register_globalstep({
	name = "spawnit:update_player_ao",
	period = s.update_ao_period,
	func = function()
		if not spawnit.enabled then
			return
		end
		local start = get_us_time()

		if s.disable_spawns_near_afk then
			local afk_players = afk_api.get_afk_players(s.min_afk_time)
			for i = 1, #afk_players do
				-- perhaps there are no visible blocks, but this isn't expensive
				discard_all_visible_blocks(afk_players[i])
			end
		end

		local players = afk_api.get_non_afk_players(s.min_afk_time)
		if #players == 0 then
			spawnit._stats.ao_calc_duration = spawnit._stats.ao_calc_duration + (get_us_time() - start)
			return
		end

		local player = pick_a_player(players)
		if not player then
			spawnit._stats.ao_calc_duration = spawnit._stats.ao_calc_duration + (get_us_time() - start)
			return
		end

		local block_hposs_without_spawn_poss = update_visibility(player)
		update_spawn_positions(player, players, block_hposs_without_spawn_poss)

		spawnit._stats.ao_calc_duration = spawnit._stats.ao_calc_duration + (get_us_time() - start)
	end,
})
