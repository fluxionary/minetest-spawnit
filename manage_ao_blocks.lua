local active_block_range = tonumber(minetest.settings:get("active_block_range")) or 4
local active_object_send_range_blocks = tonumber(minetest.settings:get("active_object_send_range_blocks")) or 8

local is_empty = futil.table.is_empty
local setdefault = futil.table.setdefault
local get_blockpos = futil.vector.get_blockpos
local is_blockpos_inside_world_bounds = futil.vector.is_blockpos_inside_world_bounds

local s = spawnit.settings
local Block = spawnit.Block

local get_fov = spawnit.util.get_fov
local is_block_in_sight = spawnit.util.is_block_in_sight

spawnit.visibility_by_hpos = {}
spawnit.nearby_blocks_by_player_name = {}

minetest.register_on_joinplayer(function(player)
	spawnit.nearby_blocks_by_player_name[player:get_player_name()] = {}
end)

minetest.register_on_leaveplayer(function(player)
	local player_name = player:get_player_name()
	local nearby_blocks = spawnit.nearby_blocks_by_player_name[player_name]
	for hpos in pairs(nearby_blocks) do
		local visibility = spawnit.visibility_by_hpos[hpos]
		if visibility then
			visibility[player_name] = nil
			if is_empty(visibility) then
				spawnit.visibility_by_hpos[hpos] = nil
				-- TODO: need to also purge cached spawn positions
			end
		end
	end
	spawnit.nearby_blocks_by_player_name[player_name] = nil
end)

-- see `doc/active object regions.md`
local function get_ao_blocks(player)
	local player_pos = player:get_pos()
	local player_blockpos = get_blockpos(player_pos)
	local blocks_by_hpos = {}
	-- get active blocks
	local r = active_block_range
	for x = player_blockpos.x - r, player_blockpos.x + r do
		for y = player_blockpos.y - r, player_blockpos.y + r do
			for z = player_blockpos.z - r, player_blockpos.z + r do
				local blockpos = vector.new(x, y, z)
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
	--local eye_offset = player:get_eye_offset()  -- this isn't actually used in computation of active object stuff
	local eye_pos = player_pos:offset(0, eye_height, 0)
	local eye_blockpos = get_blockpos(eye_pos)
	local fov = get_fov(player)
	r = active_object_send_range_blocks
	for x = eye_blockpos.x - r, eye_blockpos.x + r do
		for y = eye_blockpos.y - r, eye_blockpos.y + r do
			for z = eye_blockpos.z - r, eye_blockpos.z + r do
				local blockpos = vector.new(x, y, z)
				if is_blockpos_inside_world_bounds(blockpos) then
					local block = Block(blockpos, true)
					if is_block_in_sight(block, eye_pos, look_dir, fov, r) then
						blocks_by_hpos[block:hash()] = block
					end
				end
			end
		end
	end
end

local function is_too_far(player_pos, block_hpos)
	error("TODO: implement")
end

local player_i = 1
futil.register_globalstep({
	name = "spawnit:update_ao_blocks",
	period = s.update_positions_period,
	func = function()
		local players = minetest.get_connected_players()
		player_i = (player_i % #players) + 1
		local player = players[player_i]
		local player_name = player:get_player_name()
		local player_pos = player:get_pos()
		local nearby_blocks = spawnit.nearby_blocks_by_player_name[player_name]
		local new_ao_blocks = get_ao_blocks(player)
		local need_to_find_spawn_poss = {}

		for hpos, block in pairs(nearby_blocks) do
			local visibility = setdefault(spawnit.visibility_by_hpos, hpos, {})

			if new_ao_blocks[hpos] then
				block:set_active(true)
				new_ao_blocks[hpos] = nil -- already accounted for
				if not spawnit.spawn_poss_by_hash[hpos] then
					need_to_find_spawn_poss[#need_to_find_spawn_poss + 1] = hpos
				end
				visibility[player_name] = true
			else
				block:set_active(false)
				visibility[player_name] = nil
				if is_empty(visibility) then
					spawnit.visibility_by_hpos[hpos] = nil
				end
				if is_too_far(player_pos, hpos) then
					nearby_blocks[hpos] = nil
					-- TODO: need to also purge cached spawn positions
				end
			end
		end

		for hpos, block in pairs(new_ao_blocks) do
			if not spawnit.spawn_poss_by_hash[hpos] then
				need_to_find_spawn_poss[#need_to_find_spawn_poss + 1] = hpos
			end
			nearby_blocks[hpos] = block
			local visibility = setdefault(spawnit.visibility_by_hpos, hpos, {})
			visibility[player_name] = true
		end
		if #need_to_find_spawn_poss > 0 then
			local block = need_to_find_spawn_poss[math.random(#need_to_find_spawn_poss)]
			spawnit.find_spawn_poss(block)
		end
	end,
})

function spawnit.is_ao(block_hpos)
	return spawnit.visibility_by_hpos[block_hpos] ~= nil
end
