local FORCELOAD = "<FORCELOAD>" -- special "player name" to track forceloaded blocks

local v_new = vector.new

local compare_block_status = minetest.compare_block_status
local get_position_from_hash = minetest.get_position_from_hash
local get_us_time = minetest.get_us_time
local hash_node_position = minetest.hash_node_position

local Set = futil.Set
local get_block_center = futil.vector.get_block_center
local get_block_min = futil.vector.get_block_min
local get_blockpos = futil.vector.get_blockpos
local is_blockpos_inside_world_bounds = futil.vector.is_blockpos_inside_world_bounds
local shuffle = futil.table.shuffle

local s = spawnit.settings

local get_fov = spawnit.util.get_fov
local has_changed_pos_or_look = spawnit.util.has_changed_pos_or_look
local is_block_in_sight = spawnit.util.is_block_in_sight
local is_moving_too_fast = spawnit.util.is_moving_too_fast
local is_too_far = spawnit.util.is_too_far

local active_block_range = tonumber(minetest.settings:get("active_block_range")) or 4
local active_object_send_range_blocks = tonumber(minetest.settings:get("active_object_send_range_blocks")) or 8

-- for a given mapblock, who is it "visible" to - that is, who is keeping it in range for active objects?
-- if a block is no longer visible to any players, it is removed from this map.
spawnit.visibility_by_block_hpos = futil.DefaultTable(function()
	return Set()
end)
-- for a given mapblock, who was it visible to "recently"? if a player moves too far away from a block,
-- they are no longer nearby. if it is not near any players, it is removed from this map.
spawnit.nearby_players_by_block_hpos = futil.DefaultTable(function()
	return Set()
end)
-- for a given player, which blocks are near them?
spawnit.nearby_block_hpos_set_by_player_name = {}

minetest.register_on_joinplayer(function(player)
	local player_name = player:get_player_name()
	spawnit.nearby_block_hpos_set_by_player_name[player_name] = Set()
end)

minetest.register_on_leaveplayer(function(player)
	local player_name = player:get_player_name()
	local nearby_block_hpos_set = spawnit.nearby_block_hpos_set_by_player_name[player_name]
	for hpos in nearby_block_hpos_set:iterate() do
		local visibility = spawnit.visibility_by_block_hpos[hpos]
		visibility:remove(player_name)
		if visibility:is_empty() then
			spawnit.visibility_by_block_hpos[hpos] = nil
		end
		local nearby = spawnit.nearby_players_by_block_hpos[hpos]
		nearby:remove(player_name)
		if nearby:is_empty() then
			spawnit.nearby_players_by_block_hpos[hpos] = nil
			spawnit.clear_spawn_poss(hpos)
		end
	end
	spawnit.nearby_block_hpos_set_by_player_name[player_name] = nil
end)

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
	local r = active_block_range
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

	if active_object_send_range_blocks <= active_block_range then
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
	r = active_object_send_range_blocks
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
futil.register_globalstep({
	name = "spawnit:update_player_ao",
	period = s.update_ao_period,
	func = function()
		local start = get_us_time()

		local players = minetest.get_connected_players()
		if #players == 0 then
			return
		end

		-- first, we pick a player to update
		player_i = (player_i % #players) + 1
		local player = players[player_i]
		local j = 0
		local trials = math.min(5, #players) -- TODO: constant -> setting
		while not has_changed_pos_or_look(player) and j < trials do
			j = j + 1
			player_i = (player_i % #players) + 1
			player = players[player_i]
		end

		-- we didn't find a suitable player to update
		if j >= trials then
			return
		end

		local player_name = player:get_player_name()
		local player_pos = player:get_pos()
		local nearby_block_hpos_set = spawnit.nearby_block_hpos_set_by_player_name[player_name]
		local new_ao_block_hpos_set = get_ao_block_hpos_set(player)
		local block_hposs_without_spawn_poss = {}

		-- first, update the existing set of blocks
		for block_hpos in nearby_block_hpos_set:iterate() do
			local visibility = spawnit.visibility_by_block_hpos[block_hpos]
			local nearby = spawnit.nearby_players_by_block_hpos[block_hpos]

			if new_ao_block_hpos_set:contains(block_hpos) then
				new_ao_block_hpos_set:remove(block_hpos) -- already accounted for
				if not spawnit.spawn_poss_by_block_hpos[block_hpos] then
					block_hposs_without_spawn_poss[#block_hposs_without_spawn_poss + 1] = block_hpos
				end
				visibility:add(player_name)
				nearby:add(player_name)
			else
				visibility:discard(player_name)
				if visibility:is_empty() then
					spawnit.visibility_by_block_hpos[block_hpos] = nil
				end
				if is_too_far(player_pos, block_hpos) then
					nearby_block_hpos_set:remove(block_hpos)
					nearby:remove(player_name)
					if nearby:is_empty() then
						spawnit.nearby_players_by_block_hpos[block_hpos] = nil
						spawnit.clear_spawn_poss(block_hpos)
					end
				end
			end
		end

		-- next, process new blocks
		for block_hpos in new_ao_block_hpos_set:iterate() do
			if not spawnit.spawn_poss_by_block_hpos[block_hpos] then
				block_hposs_without_spawn_poss[#block_hposs_without_spawn_poss + 1] = block_hpos
			end
			nearby_block_hpos_set:add(block_hpos)
			local visibility = spawnit.visibility_by_block_hpos[block_hpos]
			visibility:add(player_name)
			local nearby = spawnit.nearby_players_by_block_hpos[block_hpos]
			nearby:add(player_name)
		end

		-- finally, queue up processing of spawn positions
		table.sort(block_hposs_without_spawn_poss, function(block_hpos1, block_hpos2)
			local block_center1 = get_block_center(get_position_from_hash(block_hpos1))
			local block_center2 = get_block_center(get_position_from_hash(block_hpos2))
			return player_pos:distance(block_center1) < player_pos:distance(block_center2)
		end)
		for i = 1, math.min(#block_hposs_without_spawn_poss, s.max_add_to_queue_per_ao_period) do
			local block_hpos = block_hposs_without_spawn_poss[i]
			local blockpos = get_position_from_hash(block_hpos)
			local pos = get_block_min(blockpos)
			if compare_block_status(pos, "loaded") then
				spawnit.find_spawn_poss(block_hpos)
			end
		end

		spawnit.stats.ao_calc_duration = spawnit.stats.ao_calc_duration + (get_us_time() - start)
	end,
})

local previous_forceloaded = Set()
futil.register_globalstep({
	name = "spawnit:update_forceloaded_ao",
	period = s.update_ao_period,
	func = function()
		local start = get_us_time()
		local forceloaded = spawnit.get_forceloaded()
		local need_to_find_spawn_poss = {}
		for hpos in (previous_forceloaded - forceloaded):iterate() do
			local visibility = spawnit.visibility_by_block_hpos[hpos]
			visibility:remove(FORCELOAD)
			if visibility:is_empty() then
				spawnit.visibility_by_block_hpos[hpos] = nil
			end
			local nearby = spawnit.nearby_players_by_block_hpos[hpos]
			nearby:remove(FORCELOAD)
			if nearby:is_empty() then
				spawnit.clear_spawn_poss(hpos)
			end
		end
		for hpos in (forceloaded - previous_forceloaded):iterate() do
			if not spawnit.spawn_poss_by_block_hpos[hpos] then
				need_to_find_spawn_poss[#need_to_find_spawn_poss + 1] = hpos
			end
			local visibility = spawnit.visibility_by_block_hpos[hpos]
			visibility:add(FORCELOAD)
			local nearby = spawnit.nearby_players_by_block_hpos[hpos]
			nearby:add(FORCELOAD)
		end

		shuffle(need_to_find_spawn_poss)
		for i = 1, math.min(#need_to_find_spawn_poss, s.max_add_to_queue_per_ao_period) do
			local block_hpos = need_to_find_spawn_poss[i]
			local blockpos = get_position_from_hash(block_hpos)
			local pos = get_block_min(blockpos)
			if compare_block_status(pos, "loaded") then
				if spawnit.find_spawn_poss(block_hpos) then
					-- queue is full
					break
				end
			end
		end
		previous_forceloaded = forceloaded

		spawnit.stats.ao_calc_duration = spawnit.stats.ao_calc_duration + (get_us_time() - start)
	end,
})
