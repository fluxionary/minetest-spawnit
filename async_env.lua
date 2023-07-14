spawnit = fmod.create()

spawnit.dofile("util")

local get_content_id = minetest.get_content_id

local DefaultTable = futil.DefaultTable
local Set = futil.Set

local is_full_nodebox = spawnit.util.is_full_nodebox
local get_in_entity_indices = spawnit.util.get_in_entity_indices
local get_under_entity_indices = spawnit.util.get_under_entity_indices
local spawns_on_ground = spawnit.util.spawns_on_ground

local walkable_cids
local not_walkable_cids
local node_cids -- walkable full nodes
local cids_by_group = DefaultTable(function()
	return Set()
end)

local function init_cids()
	walkable_cids = Set()
	not_walkable_cids = Set()
	node_cids = Set()
	for name, def in pairs(minetest.registered_nodes) do
		local cid = get_content_id(name)
		if def.walkable then
			walkable_cids:add(cid)
			if def.drawtype == "nodebox" and is_full_nodebox(def.node_box) then
				node_cids:add(cid)
			elseif (not def.collision_box) or is_full_nodebox(def.collision_box) then
				node_cids:add(cid)
			end
		else
			not_walkable_cids:add(cid)
		end
		for group in pairs(def.groups or {}) do
			cids_by_group[group]:add(cid)
		end
	end
end

local function build_can_be(nodes)
	local can_be = Set()
	for _, name in ipairs(nodes) do
		if name == "any" then
			return function()
				return true
			end
		elseif name == "walkable" then
			can_be:update(walkable_cids)
		elseif name == "not walkable" then
			can_be:update(not_walkable_cids)
		elseif name == "node" then
			can_be:update(node_cids)
		else
			local group = name:match("^group:(.+)$")
			if group then
				can_be:update(cids_by_group[group])
			elseif minetest.registered_nodes[name] then
				can_be:add(get_content_id(name))
			end
		end
	end

	return function(cid)
		return can_be:contains(cid)
	end
end

local can_be_in_by_def = {}
local can_be_on_by_def = {}

function spawnit.is_valid_position(def_index, def, data, va, i)
	if not (walkable_cids and node_cids) then
		init_cids()
	end

	local can_be_in = can_be_in_by_def[def_index]
	if not can_be_in then
		can_be_in = build_can_be(def.within)
		can_be_in_by_def[def_index] = can_be_in
	end

	local in_entity_indices = get_in_entity_indices(def, va, i)
	for j = 1, #in_entity_indices do
		local index = in_entity_indices[j]
		if not can_be_in(data[index]) then
			return false
		end
	end

	if spawns_on_ground(def) then
		local can_be_on = can_be_on_by_def[def_index]
		if not can_be_on then
			can_be_on = build_can_be(def.on)
			can_be_on_by_def[def_index] = can_be_on
		end

		local under_entity_indices = get_under_entity_indices(def, va, i)
		for j = 1, #under_entity_indices do
			local index = under_entity_indices[j]
			if not can_be_on(data[index]) then
				return false
			end
		end
	end

	return true
end
