local CALCULATING = "calculating"

local get_position_from_hash = minetest.get_position_from_hash
local get_us_time = minetest.get_us_time
local handle_async = minetest.handle_async

local Set = futil.Set
local get_block_bounds = futil.vector.get_block_bounds

local s = spawnit.settings

local dedicated_server_step = tonumber(minetest.settings:get("dedicated_server_step")) or 0.09
local us_per_step = s.queue_us_per_s * dedicated_server_step

function spawnit._clear_spawn_poss(hpos)
	local spawn_poss = spawnit._spawn_poss_by_block_hpos[hpos]
	if spawn_poss then
		spawnit._spawn_poss_by_block_hpos[hpos] = nil
		if type(spawn_poss) ~= "string" then -- it might be "calculating"
			for def_index in spawn_poss:iterate_def_indices() do
				local hposs = spawnit._block_hposs_by_def[def_index]
				hposs:discard(hpos)
				if hposs:is_empty() then
					spawnit._block_hposs_by_def[def_index] = nil
				end
			end
		end
	end
end

minetest.register_on_mapblocks_changed(function(modified_blocks, modified_block_count)
	for hpos in pairs(modified_blocks) do
		-- TODO: create a timeout to keep this from being recomputed too quickly in case e.g. digging or building
		spawnit._clear_spawn_poss(hpos)
	end
end)

-- NOTICE: executed in the async environment, where the namespace is different! be careful w/ upvalues!!!
local function async_call(vm, block_min, block_max)
	local va = VoxelArea(vm:get_emerged_area())
	local data = vm:get_data()
	local min_y = block_min.y
	local max_y = block_max.y
	local do_intervals_overlap = futil.math.do_intervals_overlap
	local is_valid_position = spawnit._is_valid_position
	local hash_node_position = minetest.hash_node_position
	local sample = futil.random.sample

	local hpos_set_by_def = {}
	for def_index, def in ipairs(spawnit.registered_spawns) do
		if do_intervals_overlap(def.min_y, def.max_y, min_y, max_y) then
			local hpos_list = {}
			for i in va:iterp(block_min, block_max) do
				if is_valid_position(def_index, def, data, va, i) then
					hpos_list[#hpos_list + 1] = hash_node_position(va:position(i))
				end
			end
			if #hpos_list > 0 then
				local positions_per_mapblock = def.positions_per_mapblock
				if positions_per_mapblock > 0 and #hpos_list > positions_per_mapblock then
					hpos_list = sample(hpos_list, positions_per_mapblock)
				end
				local hpos_set = {} -- can't use futil.Set cuz async env loses metatables
				for i = 1, #hpos_list do
					hpos_set[hpos_list[i]] = true
				end
				hpos_set_by_def[def_index] = hpos_set
			end
		end
	end

	return hpos_set_by_def
end

local function make_callback(block_hpos)
	return function(hpos_set_by_def)
		spawnit._stats.async_results = spawnit._stats.async_results + 1
		if spawnit._spawn_poss_by_block_hpos[block_hpos] ~= CALCULATING then
			-- if this already got computed somehow, or removed, leave it alone.
			return
		end
		spawnit._callback_queue:push_back(function()
			if spawnit._spawn_poss_by_block_hpos[block_hpos] ~= CALCULATING then
				-- if this already got computed somehow, or removed, leave it alone.
				return
			end

			local start2 = get_us_time()
			for def_index, hpos_set in pairs(hpos_set_by_def) do
				hpos_set_by_def[def_index] = Set.convert(hpos_set)
			end

			local spawn_poss = spawnit._SpawnPositions(hpos_set_by_def)
			spawnit._spawn_poss_by_block_hpos[block_hpos] = spawn_poss
			for def_index in pairs(hpos_set_by_def) do
				spawnit._block_hposs_by_def[def_index]:add(block_hpos)
			end
			spawnit._stats.async_callback_duration = spawnit._stats.async_callback_duration + (get_us_time() - start2)
		end)
	end
end

spawnit._find_spawn_poss_queue = action_queues.create_serverstep_queue({
	us_per_step = us_per_step,
})

spawnit._callback_queue = action_queues.create_serverstep_queue({
	us_per_step = us_per_step,
})

function spawnit._find_spawn_poss(block_hpos)
	-- TODO: give this function a better name
	if spawnit._spawn_poss_by_block_hpos[block_hpos] then
		return
	end

	if spawnit._find_spawn_poss_queue:size() >= s.max_queue_size then
		return true -- indicate that the caller should stop adding things
	end

	spawnit._spawn_poss_by_block_hpos[block_hpos] = CALCULATING

	spawnit._find_spawn_poss_queue:push_back(function()
		if spawnit._spawn_poss_by_block_hpos[block_hpos] ~= CALCULATING then
			-- if this already got computed somehow, or removed, leave it alone.
			return
		end

		local start = get_us_time()

		local blockpos = get_position_from_hash(block_hpos)
		local block_min, block_max = get_block_bounds(blockpos)
		local mob_extents = spawnit._mob_extents
		local pmin = block_min:offset(mob_extents[1], mob_extents[2], mob_extents[3])
		local pmax = block_max:offset(mob_extents[4], mob_extents[5], mob_extents[6])
		local vm = VoxelManip(pmin, pmax)

		handle_async(async_call, make_callback(block_hpos), vm, block_min, block_max)

		spawnit._stats.async_queue_duration = spawnit._stats.async_queue_duration + (get_us_time() - start)
	end)
end
