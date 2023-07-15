local CALCULATING = "calculating"

spawnit.spawn_poss_by_hpos = {}
spawnit.hposs_by_def = futil.DefaultTable(function()
	return futil.Set()
end)

function spawnit.clear_spawns(hpos)
	local spawn_poss = spawnit.spawn_poss_by_hpos[hpos]
	if spawn_poss then
		spawnit.spawn_poss_by_hpos[hpos] = nil
		if type(spawn_poss) ~= "string" then -- it might be "calculating"
			for def_index in pairs(spawn_poss._poss_by_def) do -- TODO don't reference internal data, create some method
				local hposs = spawnit.hposs_by_def[def_index]
				hposs:discard(hpos)
				if hposs:is_empty() then
					spawnit.hposs_by_def[def_index] = nil
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

-- executed in the async environment
local function async_call(vm, block_min, block_max, registered_spawnings)
	local va = VoxelArea(vm:get_emerged_area())
	local data = vm:get_data()

	local poss_by_def = {}
	for def_index, def in ipairs(registered_spawnings) do
		local positions = {}
		for i in va:iterp(block_min, block_max) do
			if spawnit.is_valid_position(def_index, def, data, va, i) then
				positions[#positions + 1] = va:position(i)
			end
		end
		if #positions > 0 then
			poss_by_def[def_index] = positions
		end
	end

	return poss_by_def
end

local function remove_protected_positions(poss_by_def)
	for df_index, positions in pairs(poss_by_def) do
		local def = spawnit.registered_spawnings[df_index]
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
			poss_by_def[df_index] = positions
		end
		if #positions == 0 then
			poss_by_def[df_index] = nil
		end
	end
end

function spawnit.find_spawn_poss(block)
	local blockpos = block:get_pos()
	local hpos = block:hash()

	if spawnit.spawn_poss_by_hpos[hpos] then
		return
	end

	local block_min, block_max = block:get_bounds()
	local mob_extents = spawnit.mob_extents
	local pmin = vector.offset(block_min, mob_extents[1], mob_extents[2], mob_extents[3])
	local pmax = vector.offset(block_max, mob_extents[4], mob_extents[5], mob_extents[6])

	local function callback(poss_by_def)
		if spawnit.spawn_poss_by_hpos[hpos] ~= CALCULATING then
			-- if this already got computed somehow, or removed, leave it alone.
			return
		end

		remove_protected_positions(poss_by_def)
		local spawn_poss = spawnit.SpawnPositions(blockpos, poss_by_def)
		spawnit.spawn_poss_by_hpos[hpos] = spawn_poss
		for def_index in pairs(poss_by_def) do
			spawnit.hposs_by_def[def_index]:add(hpos)
		end
	end

	spawnit.spawn_poss_by_hpos[hpos] = CALCULATING

	minetest.handle_async(
		async_call,
		callback,
		VoxelManip(pmin, pmax),
		block_min,
		block_max,
		spawnit.registered_spawnings
	)
end
