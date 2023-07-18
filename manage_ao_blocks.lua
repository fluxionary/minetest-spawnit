local FORCELOAD = "<FORCELOAD>"

local v_new = vector.new

local get_blockpos = futil.vector.get_blockpos
local is_blockpos_inside_world_bounds = futil.vector.is_blockpos_inside_world_bounds
local Set = futil.Set

local s = spawnit.settings
local Block = spawnit.Block

local get_fov = spawnit.util.get_fov
local is_block_in_sight = spawnit.util.is_block_in_sight
local is_too_far = spawnit.util.is_too_far

local active_block_range = tonumber(minetest.settings:get("active_block_range")) or 4
local active_object_send_range_blocks = tonumber(minetest.settings:get("active_object_send_range_blocks")) or 8
local movement_walk_speed = tonumber(minetest.settings:get("movement_speed_walk")) or 4.0

spawnit.visibility_by_hpos = futil.DefaultTable(function()
	return Set()
end)
spawnit.nearby_players_by_hpos = futil.DefaultTable(function()
	return Set()
end)
spawnit.nearby_blocks_by_player_name = {}
local previous_pos_and_time_by_player_name = {}
local previous_pos_and_look_by_player_name = {}

minetest.register_on_joinplayer(function(player)
	local player_name = player:get_player_name()
	spawnit.nearby_blocks_by_player_name[player_name] = {}
	previous_pos_and_time_by_player_name[player_name] = { player:get_pos(), minetest.get_us_time() }
	previous_pos_and_look_by_player_name[player_name] = { player:get_pos(), player:get_look_dir() }
end)

minetest.register_on_leaveplayer(function(player)
	local player_name = player:get_player_name()
	local nearby_blocks = spawnit.nearby_blocks_by_player_name[player_name]
	for hpos in pairs(nearby_blocks) do
		local visibility = spawnit.visibility_by_hpos[hpos]
		visibility:remove(player_name)
		if visibility:is_empty() then
			spawnit.visibility_by_hpos[hpos] = nil
		end
		local nearby = spawnit.nearby_players_by_hpos[hpos]
		nearby:remove(player_name)
		if nearby:is_empty() then
			spawnit.nearby_players_by_hpos[hpos] = nil
			spawnit.clear_spawns(hpos)
		end
	end
	spawnit.nearby_blocks_by_player_name[player_name] = nil
	previous_pos_and_time_by_player_name[player_name] = nil
	previous_pos_and_look_by_player_name[player_name] = nil
end)

local function is_moving_too_fast(player)
	-- TODO: move this to util
	local max_speed = s.player_move_too_fast_ratio * movement_walk_speed
	if player:get_velocity():length() >= max_speed then
		return true
	end
	local player_name = player:get_player_name()
	local previous_pos_and_time = previous_pos_and_time_by_player_name[player_name]
	local pos = player:get_pos()
	local now = minetest.get_us_time()
	if not previous_pos_and_time then
		previous_pos_and_time_by_player_name[player_name] = { pos, now }
		return false
	end
	local previous_pos, previous_time = unpack(previous_pos_and_time)
	local too_fast = pos:distance(previous_pos) / (now - previous_time) >= max_speed
	previous_pos_and_time_by_player_name[player_name] = { pos, now }
	return too_fast
end

-- see `doc/active object regions.md`
local function get_ao_blocks(player)
	if is_moving_too_fast(player) then
		return {}
	end

	local start = minetest.get_us_time()
	local player_pos = player:get_pos()
	local player_blockpos = get_blockpos(player_pos)
	local x0, y0, z0 = player_blockpos.x, player_blockpos.y, player_blockpos.z
	local blocks_by_hpos = {}
	-- get active blocks
	local r = active_block_range
	for x = x0 - r, x0 + r do
		for y = y0 - r, y0 + r do
			for z = z0 - r, z0 + r do
				local blockpos = v_new(x, y, z)
				if is_blockpos_inside_world_bounds(blockpos) then
					local block = Block(blockpos, true)
					blocks_by_hpos[block:hash()] = block
				end
			end
		end
	end

	if active_object_send_range_blocks <= active_block_range then
		return blocks_by_hpos
	end

	-- get visible blocks
	local look_dir = player:get_look_dir()
	local properties = player:get_properties()
	local eye_height = properties.eye_height
	local eye_pos = player_pos:offset(0, eye_height, 0)
	local eye_blockpos = get_blockpos(eye_pos)
	x0, y0, z0 = eye_blockpos.x, eye_blockpos.y, eye_blockpos.z
	local fov = get_fov(player)
	r = active_object_send_range_blocks
	for x = x0 - r, x0 + r do
		for y = y0 - r, y0 + r do
			for z = z0 - r, z0 + r do
				local blockpos = v_new(x, y, z)
				if is_blockpos_inside_world_bounds(blockpos) then
					local block = Block(blockpos, true)
					if is_block_in_sight(block, eye_pos, look_dir, fov, r) then
						blocks_by_hpos[block:hash()] = block
					end
				end
			end
		end
	end

	spawnit.stats.get_ao_blocks_duration = spawnit.stats.get_ao_blocks_duration + (minetest.get_us_time() - start)

	return blocks_by_hpos
end

local function hasnt_moved(player)
	local player_name = player:get_player_name()
	local pos = player:get_pos()
	local look = player:get_look_dir()
	local previous_pos, previous_look = unpack(previous_pos_and_look_by_player_name[player_name])
	previous_pos_and_look_by_player_name[player_name] = { pos, look }
	if active_object_send_range_blocks <= active_block_range then
		return pos:equals(previous_pos)
	else
		return pos:equals(previous_pos) and look:equals(previous_look)
	end
end

local player_i = 1
futil.register_globalstep({
	name = "spawnit:update_player_ao",
	period = s.update_ao_period,
	func = function()
		local players = minetest.get_connected_players()
		if #players == 0 then
			return
		end

		local start = minetest.get_us_time()
		player_i = (player_i % #players) + 1
		local player = players[player_i]
		local j = 1
		local trials = math.min(5, #players)
		while hasnt_moved(player) and j <= trials do
			player_i = (player_i % #players) + 1
			player = players[player_i]
			j = j + 1
		end

		if j > trials then
			spawnit.stats.ao_calc_duration = spawnit.stats.ao_calc_duration + (minetest.get_us_time() - start)
			return
		end

		local player_name = player:get_player_name()
		local player_pos = player:get_pos()
		local nearby_blocks = spawnit.nearby_blocks_by_player_name[player_name]
		local new_ao_blocks = get_ao_blocks(player)
		local need_to_find_spawn_poss = {}

		for hpos, block in pairs(nearby_blocks) do
			local visibility = spawnit.visibility_by_hpos[hpos]
			local nearby = spawnit.nearby_players_by_hpos[hpos]

			if new_ao_blocks[hpos] then
				block:set_active_objects(true)
				new_ao_blocks[hpos] = nil -- already accounted for
				if not spawnit.spawn_poss_by_block_hpos[hpos] then
					need_to_find_spawn_poss[#need_to_find_spawn_poss + 1] = hpos
				end
				visibility:add(player_name)
				nearby:add(player_name)
			else
				block:set_active_objects(false)
				visibility:discard(player_name)
				if visibility:is_empty() then
					spawnit.visibility_by_hpos[hpos] = nil
				end
				if is_too_far(player_pos, hpos) then
					nearby_blocks[hpos] = nil
					nearby:remove(player_name)
					if nearby:is_empty() then
						spawnit.nearby_players_by_hpos[hpos] = nil
						spawnit.clear_spawns(hpos)
					end
				end
			end
		end

		for hpos, block in pairs(new_ao_blocks) do
			if not spawnit.spawn_poss_by_block_hpos[hpos] then
				need_to_find_spawn_poss[#need_to_find_spawn_poss + 1] = hpos
			end
			nearby_blocks[hpos] = block
			local visibility = spawnit.visibility_by_hpos[hpos]
			visibility:add(player_name)
			local nearby = spawnit.nearby_players_by_hpos[hpos]
			nearby:add(player_name)
		end
		for i = 1, #need_to_find_spawn_poss do
			local block = nearby_blocks[need_to_find_spawn_poss[i]]
			local pos = block:get_min()
			if minetest.compare_block_status(pos, "active") or minetest.compare_block_status(pos, "loaded") then
				spawnit.find_spawn_poss(block)
			end
		end

		spawnit.stats.ao_calc_duration = spawnit.stats.ao_calc_duration + (minetest.get_us_time() - start)
	end,
})

local previous_forceloaded = Set()
futil.register_globalstep({
	name = "spawnit:update_forceloaded_ao",
	period = s.update_ao_period,
	func = function()
		local start = minetest.get_us_time()
		local forceloaded = spawnit.get_forceloaded()
		local need_to_find_spawn_poss = {}
		for hpos in (previous_forceloaded - forceloaded):iterate() do
			local visibility = spawnit.visibility_by_hpos[hpos]
			visibility:remove(FORCELOAD)
			if visibility:is_empty() then
				spawnit.visibility_by_hpos[hpos] = nil
			end
			local nearby = spawnit.nearby_players_by_hpos[hpos]
			nearby:remove(FORCELOAD)
			if nearby:is_empty() then
				spawnit.clear_spawns(hpos)
			end
		end
		for hpos in (forceloaded - previous_forceloaded):iterate() do
			if not spawnit.spawn_poss_by_block_hpos[hpos] then
				need_to_find_spawn_poss[#need_to_find_spawn_poss + 1] = hpos
			end
			local visibility = spawnit.visibility_by_hpos[hpos]
			visibility:add(FORCELOAD)
			local nearby = spawnit.nearby_players_by_hpos[hpos]
			nearby:add(FORCELOAD)
		end
		for i = 1, #need_to_find_spawn_poss do
			local blockpos = minetest.get_position_from_hash(need_to_find_spawn_poss[i])
			local block = Block(blockpos, true)
			local pos = block:get_min()
			if minetest.compare_block_status(pos, "active") or minetest.compare_block_status(pos, "loaded") then
				spawnit.find_spawn_poss(block)
			end
		end
		previous_forceloaded = forceloaded

		spawnit.stats.ao_calc_duration = spawnit.stats.ao_calc_duration + (minetest.get_us_time() - start)
	end,
})
