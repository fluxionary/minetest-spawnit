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
		for _, area in pairs(areas:getAreasAtPos(pos)) do
			if area.spawnit_enabled == true then
				return true
			end
		end
		return false, true
	end)
end
