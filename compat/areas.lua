local S = spawnit.S

minetest.register_chatcommand("area_spawnit", {
	description = S("toggle mob spawning in an area (allowed mobs only)"),
	params = S("<area ID>"),
	func = function(name, param)
		local id = tonumber(param)
		if not id then
			return false, S("invalid argument. please give an area id.")
		end
		if not areas:isAreaOwner(id, name) then
			return false, S("area @1 does not exist or is not owned by you.", id)
		end
		local spawnit_disabled = not areas.areas[id].spawnit_disabled
		-- Save false as nil to avoid inflating the DB.
		areas.areas[id].spawnit_disabled = spawnit_disabled or nil
		areas:save()
		return true,
			spawnit_disabled and S("all spawns are disabled in the area") or S(
				"spawns are now enabled for allowed mobs"
			)
	end,
})

spawnit.register_pos_check(function(pos)
	for _, area in pairs(areas:getAreasAtPos(pos)) do
		if area.spawnit_disabled then
			return false, true
		end
	end
	return true
end)
