spawnit.spawn_poss_by_hash = {}
spawnit.hposs_by_def = {}

minetest.register_on_mapblocks_changed(function(modified_blocks, modified_block_count)
	for hpos in pairs(modified_blocks) do
		local spawn_poss = spawnit.spawn_poss_by_hash[hpos]
		if spawn_poss then
			spawnit.spawn_poss_by_hash[hpos] = nil
			if type(spawn_poss) ~= "string" then -- it might be "calculating"
				for n in pairs(spawn_poss._poss_by_def) do -- TODO don't reference internal data, create some method
					spawnit.hposs_by_def[n][hpos] = nil
				end
			end
		end
	end
end)

-- executed in the async environment
local function async_call(vm, block_min, block_max, registered_spawnings)
	local va = VoxelArea(vm:get_emerged_area())
	local data = vm:get_data()
	local light = vm:get_light()

	local poss_by_def = {}
	for n, def in ipairs(registered_spawnings) do
		local positions = {}
		for i in va:iterp(block_min, block_max) do
			if spawnit.is_valid_position(def, data, light, va, i) then
				positions[#positions + 1] = va:position(i)
			end
		end
		if #positions > 0 then
			poss_by_def[n] = positions
		end
	end

	return poss_by_def
end

local function remove_protected_positions(poss_by_def)
	for n, positions in pairs(poss_by_def) do
		local def = spawnit.registered_spawnings[n]
		local entity = def.entity
		if not def.spawn_in_protected then
			local filtered = {}
			for i = 1, #positions do
				local pos = positions[i]
				if not minetest.is_protected(pos, entity) then
					filtered[#filtered + 1] = pos
				end
			end
			positions = filtered
			poss_by_def[n] = positions
		end
		if #positions == 0 then
			poss_by_def[n] = nil
		end
	end
end

function spawnit.find_spawn_poss(block)
	local blockpos = block:get_pos()
	local hpos = block:hash()
	local block_min, block_max = block:get_bounds()
	local mob_extents = spawnit.mob_extents
	local pmin = vector.offset(block_min, mob_extents[1], mob_extents[2], mob_extents[3])
	local pmax = vector.offset(block_max, mob_extents[4], mob_extents[5], mob_extents[6])

	local function callback(poss_by_def)
		-- if this already got computed somehow, or removed, leave it alone.
		if spawnit.spawn_poss_by_hash[hpos] ~= "calcuating" then
			return
		end

		remove_protected_positions(poss_by_def)
		local spawn_poss = spawnit.SpawnPositions(blockpos, poss_by_def)
		spawnit.spawn_poss_by_hash[hpos] = spawn_poss
		for n in pairs(poss_by_def) do
			local hposs = futil.table.setdefault(spawnit.hposs_by_def, n, {})
			hposs[hpos] = true
		end
	end

	spawnit.spawn_poss_by_hash[hpos] = "calculating"

	minetest.handle_async(
		async_call,
		callback,
		VoxelManip(pmin, pmax),
		block_min,
		block_max,
		spawnit.registered_spawnings
	)
end
