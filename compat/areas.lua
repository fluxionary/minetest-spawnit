local S = spawnit.S

if spawnit.settings.spawn_in_protected_area then
	minetest.register_chatcommand("area_spawnit", {
		description = S("toggle mob spawning in an area (i.e. disallow all spawns in area)"),
		params = S("<area ID>"),
		func = function(name, param)
			local id = tonumber(param)

			if not id then
				return false, S("invalid argument. please give an area id.")
			end
			if not areas:isAreaOwner(id, name) then
				return false, S("area @1 does not exist or is not owned by you.", tostring(id))
			end

			local previous_spawnit_enabled = areas.areas[id].spawnit_enabled
			if previous_spawnit_enabled == nil or previous_spawnit_enabled == true then
				areas.areas[id].spawnit_enabled = false
				areas:save()
				return true, S("all spawns are disabled in the area")
			else
				areas.areas[id].spawnit_enabled = nil
				areas:save()
				return true, S("spawns which ignore protection are now enabled")
			end
		end,
	})

	spawnit.register_pos_check(function(pos)
		for _, area in pairs(areas:getAreasAtPos(pos)) do
			if area.spawnit_enabled == false then
				return false, true
			end
		end
		return true
	end)
else
	local function get_master_area(id)
		local area = areas.areas[id]
		local parent_id = area.parent
		while parent_id do
			id = parent_id
			area = areas.areas[parent_id]
			parent_id = area.parent
		end
		return id
	end

	minetest.register_chatcommand("area_spawnit", {
		description = S("toggle mob spawning in an area (i.e. allow safe spawns in the area)"),
		params = S("<area ID>"),
		func = function(name, param)
			local id = tonumber(param)

			if not id then
				return false, S("invalid argument. please give an area id.")
			end
			if not areas:isAreaOwner(id, name) then
				return false, S("area @1 does not exist or is not owned by you.", tostring(id))
			end
			if not areas:isAreaOwner(get_master_area(id), name) then
				return false, S("you do not control the master area here.")
			end

			local previous_spawnit_enabled = areas.areas[id].spawnit_enabled
			if previous_spawnit_enabled == nil or previous_spawnit_enabled == false then
				areas.areas[id].spawnit_enabled = true
				areas:save()
				return true, S("spawns which ignore protection are now enabled")
			else
				areas.areas[id].spawnit_enabled = nil
				areas:save()
				return true, S("all spawns are disabled in the area")
			end
		end,
	})

	spawnit.register_pos_check(function(pos)
		local any = false
		for _, area in pairs(areas:getAreasAtPos(pos)) do
			any = true
			if area.spawnit_enabled == true then
				return true
			end
		end

		if any then
			return false, true
		else
			return true
		end
	end)
end
