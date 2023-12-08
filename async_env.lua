-- the contents of this file are loaded in the async environment. the published APIs are not available from
-- the main thread.

spawnit = fmod.create()

spawnit.dofile("util")

-- load the spawn rules. these are written to the worldpath after mods are loaded, but before the async env starts
spawnit.registered_spawns =
	minetest.deserialize(futil.load_file(futil.path_concat(minetest.get_worldpath(), "spawnit_rules.serialized")))

local math_ceil = math.ceil
local math_floor = math.floor
local math_max = math.max
local math_min = math.min

local get_content_id = minetest.get_content_id

local DefaultTable = futil.DefaultTable
local Set = futil.Set
local in_bounds = futil.math.in_bounds

local is_full_nodebox = spawnit.util.is_full_nodebox
local spawns_near_something = spawnit.util.spawns_near_something
local spawns_on_something = spawnit.util.spawns_on_something

local walkable_cids = Set()
local node_cids = Set() -- walkable full nodes
local not_walkable_cids = Set()
local breathable_cids = Set()
local breathable_airlike_cids = Set()
local cids_by_group = DefaultTable(function()
	return Set()
end)

-- build cid sets
for name, def in pairs(minetest.registered_nodes) do
	if name ~= "ignore" then
		local cid = get_content_id(name)
		if def.walkable ~= false then -- TODO https://github.com/minetest/minetest/issues/13644
			walkable_cids:add(cid)
			if def.drawtype == "nodebox" and def.node_box and is_full_nodebox(def.node_box) then
				node_cids:add(cid)
			elseif (not def.collision_box) or is_full_nodebox(def.collision_box) then
				node_cids:add(cid)
			end
		else
			not_walkable_cids:add(cid)
			if (def.drowning or 0) == 0 and (def.damage_per_second or 0) == 0 then -- TODO: also #13644
				breathable_cids:add(cid)
				if (def.drawtype or "normal") == "airlike" then -- TODO: also #13644
					breathable_airlike_cids:add(cid)
				end
			end
		end
		for group in pairs(def.groups or {}) do
			cids_by_group[group]:add(cid)
		end
	end
end

local function min_x_offset(cb)
	return math_min(0, math_floor(cb[1] + 0.5))
end

local function min_y_offset(cb)
	return math_min(0, math_floor(cb[2] + 0.5))
end

local function min_z_offset(cb)
	return math_min(0, math_floor(cb[3] + 0.5))
end

local function max_x_offset(cb)
	return math_max(0, math_ceil(cb[4] - 0.5))
end

local function max_y_offset(cb)
	return math_max(0, math_ceil(cb[5] - 0.5))
end

local function max_z_offset(cb)
	return math_max(0, math_ceil(cb[6] - 0.5))
end

-- TODO this should be a generator in case we don't need to iterate them all
local function get_in_entity_indices(def, va, i)
	local cb = def.collisionbox
	local pos0 = va:position(i)
	local x0, y0, z0 = pos0.x, pos0.y, pos0.z
	local indices = {}
	for y = y0 + min_y_offset(cb), y0 + max_y_offset(cb) do
		for x = x0 + min_x_offset(cb), x0 + max_x_offset(cb) do
			for z = z0 + min_z_offset(cb), z0 + max_z_offset(cb) do
				indices[#indices + 1] = va:index(x, y, z)
			end
		end
	end
	return indices
end

-- TODO this should be a generator in case we don't need to iterate them all
local function get_under_entity_indices(def, va, i)
	local cb = def.collisionbox
	local pos0 = va:position(i)
	local x0, y0, z0 = pos0.x, pos0.y, pos0.z
	local indices = {}
	local y = y0 + min_y_offset(cb) - 1
	for x = x0 + min_x_offset(cb), x0 + max_x_offset(cb) do
		for z = z0 + min_z_offset(cb), z0 + max_z_offset(cb) do
			indices[#indices + 1] = va:index(x, y, z)
		end
	end
	return indices
end

-- TODO this should be a generator in case we don't need to iterate them all
-- get positions inside or touching the entity on 6 faces. doesn't include edges and corners of the bounding box
local function get_near_entity_indices(def, va, i)
	local cb = def.collisionbox
	local pos0 = va:position(i)
	local x0, y0, z0 = pos0.x, pos0.y, pos0.z
	local min_x, max_x = x0 + min_x_offset(cb), x0 + max_x_offset(cb)
	local min_y, max_y = y0 + min_y_offset(cb), y0 + max_y_offset(cb)
	local min_z, max_z = z0 + min_z_offset(cb), z0 + max_z_offset(cb)
	local indices = get_in_entity_indices(def, va, i) -- consider things inside to be near too!
	do -- left x face
		local x = min_x - 1
		for y = min_y, max_y do
			for z = min_z, max_z do
				indices[#indices + 1] = va:index(x, y, z)
			end
		end
	end
	do -- right x face
		local x = max_x + 1
		for y = min_y, max_y do
			for z = min_z, max_z do
				indices[#indices + 1] = va:index(x, y, z)
			end
		end
	end
	do -- bottom y face
		local y = min_y - 1
		for x = min_x, max_x do
			for z = min_z, max_z do
				indices[#indices + 1] = va:index(x, y, z)
			end
		end
	end
	do -- top y face
		local y = max_y + 1
		for x = min_x, max_x do
			for z = min_z, max_z do
				indices[#indices + 1] = va:index(x, y, z)
			end
		end
	end
	do -- low z face
		local z = min_z - 1
		for x = min_x, max_x do
			for y = min_y, max_y do
				indices[#indices + 1] = va:index(x, y, z)
			end
		end
	end
	do -- high z face
		local z = max_z + 1
		for x = min_x, max_x do
			for y = min_y, max_y do
				indices[#indices + 1] = va:index(x, y, z)
			end
		end
	end
	return indices
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
		elseif name == "node" then
			can_be:update(node_cids)
		elseif name == "not walkable" then
			can_be:update(not_walkable_cids)
		elseif name == "breathable" then
			can_be:update(breathable_cids)
		elseif name == "breathable airlike" then
			can_be:update(breathable_airlike_cids)
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
local can_be_near_by_def = {}

local function get_can_be_in(def_index, def)
	local can_be_in = can_be_in_by_def[def_index]
	if not can_be_in then
		can_be_in = build_can_be(def.within)
		can_be_in_by_def[def_index] = can_be_in
	end
	return can_be_in
end

local function check_can_be_in(def_index, def, data, va, i)
	local can_be_in = get_can_be_in(def_index, def)
	local in_entity_indices = get_in_entity_indices(def, va, i)
	for j = 1, #in_entity_indices do
		local index = in_entity_indices[j]
		local cid = data[index]
		if not can_be_in(cid) then
			return false
		end
	end
	return true
end

local function get_can_be_on(def_index, def)
	local can_be_on = can_be_on_by_def[def_index]
	if not can_be_on then
		can_be_on = build_can_be(def.on)
		can_be_on_by_def[def_index] = can_be_on
	end
	return can_be_on
end

local function check_can_be_on(def_index, def, data, va, i)
	local can_be_on = get_can_be_on(def_index, def)

	local under_entity_indices = get_under_entity_indices(def, va, i)
	for j = 1, #under_entity_indices do
		local index = under_entity_indices[j]
		local cid = data[index]
		if not can_be_on(cid) then
			return false
		end
	end

	return true
end

local function get_can_be_near(def_index, def)
	local can_be_near = can_be_near_by_def[def_index]
	if not can_be_near then
		can_be_near = build_can_be(def.near)
		can_be_near_by_def[def_index] = can_be_near
	end

	return can_be_near
end

local function check_is_near(def_index, def, data, va, i)
	local can_be_near = get_can_be_near(def_index, def)

	local near_any = false
	local near_entity_indices = get_near_entity_indices(def, va, i)
	for j = 1, #near_entity_indices do
		local index = near_entity_indices[j]
		local cid = data[index]
		if can_be_near(cid) then
			near_any = true
			break
		end
	end

	return near_any
end

function spawnit._is_valid_position(def_index, def, data, va, i)
	local pos = va:position(i)
	if not in_bounds(def.min_y, pos.y, def.max_y) then
		return false
	end

	if not check_can_be_in(def_index, def, data, va, i) then
		return false
	end

	if spawns_on_something(def) then
		if not check_can_be_on(def_index, def, data, va, i) then
			return false
		end
	end

	if spawns_near_something(def) then
		if not check_is_near(def_index, def, data, va, i) then
			return false
		end
	end

	return true
end
