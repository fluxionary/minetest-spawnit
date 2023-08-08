local FORCELOAD = "<FORCELOAD>" -- special "player name" to track forceloaded blocks

local compare_block_status = minetest.compare_block_status
local get_position_from_hash = minetest.get_position_from_hash
local get_us_time = minetest.get_us_time

local Set = futil.Set
local get_block_min = futil.vector.get_block_min
local shuffle = futil.table.shuffle

local s = spawnit.settings

local forceloaded = futil.Set()
local forceload_counts = futil.DefaultTable(function()
	return 0
end)
local tempload_counts = futil.DefaultTable(function()
	return 0
end)

local function read_forceloaded()
	local worldpath = minetest.get_worldpath()
	local filename = futil.path_concat(worldpath, "force_loaded.txt")
	local contents = futil.load_file(filename)
	return minetest.deserialize(contents or "") or {}
end

do
	for hpos, count in pairs(read_forceloaded()) do
		forceload_counts[hpos] = count
		forceloaded:add(hpos)
	end
end

local old_forceload_block = minetest.forceload_block

function minetest.forceload_block(pos, transient, limit)
	local rv = old_forceload_block(pos, transient, limit)
	if rv then
		local hpos = minetest.hash_node_position(futil.vector.get_blockpos(pos))
		if transient then
			tempload_counts[hpos] = tempload_counts[hpos] + 1
		else
			forceload_counts[hpos] = forceload_counts[hpos] + 1
		end
		forceloaded:add(hpos)
	end
	return rv
end

local old_forceload_free_block = minetest.forceload_free_block

function minetest.forceload_free_block(pos, transient)
	local hpos = minetest.hash_node_position(futil.vector.get_blockpos(pos))
	if transient then
		local v = tempload_counts[hpos]
		if v <= 1 then
			tempload_counts[hpos] = nil
			if not rawget(forceload_counts, hpos) then
				forceloaded:remove(hpos)
			end
		else
			tempload_counts[hpos] = v - 1
		end
	else
		local v = forceload_counts[hpos]
		if v <= 1 then
			forceload_counts[hpos] = nil
			if not rawget(tempload_counts, hpos) then
				forceloaded:remove(hpos)
			end
		else
			forceload_counts[hpos] = v - 1
		end
	end
	return old_forceload_free_block(pos, transient)
end

function spawnit._get_forceloaded()
	return futil.Set(forceloaded)
end

local previous_forceloaded = Set()
futil.register_globalstep({
	name = "spawnit:update_forceloaded_ao",
	period = s.update_ao_period,
	func = function()
		-- TODO: the way this is written, with spawn position expiry, force-loaded areas will eventually run out of
		-- TODO: valid positions and won't be re-calculated. possibly positions in force-loaded blocks shouldn't
		-- TODO: be expired
		local start = get_us_time()
		local is_forceloaded = spawnit._get_forceloaded()
		local need_to_find_spawn_poss = {}
		for hpos in (previous_forceloaded - is_forceloaded):iterate() do
			local visibility = spawnit._visibility_by_block_hpos[hpos]
			visibility:discard(FORCELOAD)
			if visibility:is_empty() then
				spawnit._visibility_by_block_hpos[hpos] = nil
			end
			local nearby = spawnit._nearby_players_by_block_hpos[hpos]
			nearby:discard(FORCELOAD)
			if nearby:is_empty() then
				spawnit._clear_spawn_poss(hpos)
			end
		end
		for hpos in (is_forceloaded - previous_forceloaded):iterate() do
			if not spawnit._spawn_poss_by_block_hpos[hpos] then
				need_to_find_spawn_poss[#need_to_find_spawn_poss + 1] = hpos
			end
			local visibility = spawnit._visibility_by_block_hpos[hpos]
			visibility:add(FORCELOAD)
			local nearby = spawnit._nearby_players_by_block_hpos[hpos]
			nearby:add(FORCELOAD)
		end

		shuffle(need_to_find_spawn_poss)
		local players = minetest.get_connected_players()
		local max_add_to_queue_per_ao_period = math.ceil(s.max_queue_size / math.max(1, #players - 1))
		for i = 1, math.min(#need_to_find_spawn_poss, max_add_to_queue_per_ao_period) do
			local block_hpos = need_to_find_spawn_poss[i]
			local blockpos = get_position_from_hash(block_hpos)
			local pos = get_block_min(blockpos)
			if compare_block_status(pos, "loaded") then
				if spawnit._find_spawn_poss(block_hpos) then
					-- queue is full
					break
				end
			end
		end
		previous_forceloaded = is_forceloaded

		spawnit._stats.ao_calc_duration = spawnit._stats.ao_calc_duration + (get_us_time() - start)
	end,
})
