spawnit = fmod.create()

local walkable_by_cid
local node_by_cid -- walkable full nodes

local function init_cids()
	walkable_by_cid = {}
	node_by_cid = {}
	for name, def in pairs(minetest.registered_nodes) do
		local cid = minetest.get_content_id(name)
		if def.walkable then
			walkable_by_cid[cid] = true
			if def.drawtype == "nodebox" and spawnit.util.is_full_nodebox(def.node_box) then
				node_by_cid[cid] = true
			elseif (not def.collision_box) or spawnit.util.is_full_nodebox(def.collision_box) then
				node_by_cid[cid] = true
			end
		end
	end
end

function spawnit.is_valid_position(def, data, light, va, i)
	if not (walkable_by_cid and node_by_cid) then
		init_cids()
	end
	local in_entity_indices = spawnit.util.get_in_entity_indices(def, va, i)
	for j = 1, #in_entity_indices do
		if not spawnit.util.can_be_in(def, data, light, in_entity_indices[j]) then
			return false
		end
	end
	if spawnit.util.spawns_on_ground(def) then
		local under_entity_indices = spawnit.util.get_under_entity_indices(def, va, i)
		for j = 1, #under_entity_indices do
			if not spawnit.util.can_be_on(def, data, under_entity_indices[j]) then
				return false
			end
		end
	end
	return true
end
