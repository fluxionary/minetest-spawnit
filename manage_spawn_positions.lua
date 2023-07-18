local CALCULATING = "calculating"

local get_us_time = minetest.get_us_time
local handle_async = minetest.handle_async

local Set = futil.Set

local s = spawnit.settings

spawnit.spawn_poss_by_block_hpos = {}
spawnit.block_hposs_by_def = futil.DefaultTable(function()
	return futil.Set()
end)

function spawnit.clear_spawns(hpos)
	local spawn_poss = spawnit.spawn_poss_by_block_hpos[hpos]
	if spawn_poss then
		spawnit.spawn_poss_by_block_hpos[hpos] = nil
		if type(spawn_poss) ~= "string" then -- it might be "calculating"
			for def_index in spawn_poss:iterate_def_indices() do
				local hposs = spawnit.block_hposs_by_def[def_index]
				hposs:discard(hpos)
				if hposs:is_empty() then
					spawnit.block_hposs_by_def[def_index] = nil
				end
			end
		end
	end
end

minetest.register_on_mapblocks_changed(function(modified_blocks, modified_block_count)
	for hpos in pairs(modified_blocks) do
		spawnit.clear_spawns(hpos)
	end
end)

-- NOTICE: executed in the async environment, where the namespace is different!
local function async_call(vm, block_min, block_max)
	local va = VoxelArea(vm:get_emerged_area())
	local data = vm:get_data()

	local hpos_set_by_def = {}
	for def_index, def in ipairs(spawnit.registered_spawns) do
		local hpos_list = {}
		for i in va:iterp(block_min, block_max) do
			if spawnit.is_valid_position(def_index, def, data, va, i) then
				hpos_list[#hpos_list + 1] = minetest.hash_node_position(va:position(i))
			end
		end
		if #hpos_list > 0 then
			if #hpos_list > spawnit.settings.max_positions_per_mapblock_per_rule then
				hpos_list = futil.random.sample(hpos_list, spawnit.settings.max_positions_per_mapblock_per_rule)
			end
			local hpos_set = {} -- can't use Set cuz async env loses metatables
			for i = 1, #hpos_list do
				hpos_set[hpos_list[i]] = true
			end
			hpos_set_by_def[def_index] = hpos_set
		end
	end

	return hpos_set_by_def
end

local dedicated_server_step = tonumber(minetest.settings:get("dedicated_server_step")) or 0.09
local us_per_step = s.queue_us_per_s * dedicated_server_step

spawnit.find_spawn_poss_queue = action_queues.create_serverstep_queue({
	us_per_step = us_per_step,
})

spawnit.callback_queue = action_queues.create_serverstep_queue({
	us_per_step = us_per_step,
})

function spawnit.find_spawn_poss(block)
	-- TODO: give this function a better name
	local blockpos = block:get_pos()
	local hpos = block:hash()

	if spawnit.spawn_poss_by_block_hpos[hpos] then
		return
	end

	spawnit.spawn_poss_by_block_hpos[hpos] = CALCULATING

	spawnit.find_spawn_poss_queue:push_back(function()
		local start = get_us_time()

		local block_min, block_max = block:get_bounds()
		local mob_extents = spawnit.mob_extents
		local pmin = vector.offset(block_min, mob_extents[1], mob_extents[2], mob_extents[3])
		local pmax = vector.offset(block_max, mob_extents[4], mob_extents[5], mob_extents[6])

		local function callback(hpos_set_by_def)
			if spawnit.spawn_poss_by_block_hpos[hpos] ~= CALCULATING then
				-- if this already got computed somehow, or removed, leave it alone.
				return
			end
			spawnit.callback_queue:push_back(function()
				if spawnit.spawn_poss_by_block_hpos[hpos] ~= CALCULATING then
					-- if this already got computed somehow, or removed, leave it alone.
					return
				end

				local start2 = get_us_time()
				for def_index, hpos_set in pairs(hpos_set_by_def) do
					hpos_set_by_def[def_index] = Set.convert(hpos_set)
				end

				local spawn_poss = spawnit.SpawnPositions(blockpos, hpos_set_by_def)
				spawnit.spawn_poss_by_block_hpos[hpos] = spawn_poss
				for def_index in pairs(hpos_set_by_def) do
					spawnit.block_hposs_by_def[def_index]:add(hpos)
				end
				spawnit.stats.async_callback_duration = spawnit.stats.async_callback_duration + (get_us_time() - start2)
			end)
		end

		handle_async(async_call, callback, VoxelManip(pmin, pmax), block_min, block_max)
		spawnit.stats.async_queue_duration = spawnit.stats.async_queue_duration + (get_us_time() - start)
	end)
end
