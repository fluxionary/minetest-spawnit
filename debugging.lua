local S = spawnit.S
local s = spawnit.settings

local math_ceil = math.ceil
local math_floor = math.floor
local math_max = math.max
local math_min = math.min

local get_content_id = minetest.get_content_id

local DefaultTable = futil.DefaultTable
local Set = futil.Set

local is_full_nodebox = spawnit.util.is_full_nodebox

local walkable_cids = Set()
local node_cids = Set() -- walkable full nodes
local not_walkable_cids = Set()
local breathable_cids = Set()
local breathable_airlike_cids = Set()
local cids_by_group = DefaultTable(function()
	return Set()
end)

minetest.register_on_mods_loaded(function()
	-- build cid sets
	for name, def in pairs(minetest.registered_nodes) do
		local cid = get_content_id(name)
		if def.walkable ~= false then
			walkable_cids:add(cid)
			if def.drawtype == "nodebox" and def.node_box and is_full_nodebox(def.node_box) then
				node_cids:add(cid)
			elseif (not def.collision_box) or is_full_nodebox(def.collision_box) then
				node_cids:add(cid)
			end
		else
			not_walkable_cids:add(cid)
			if (def.drowning or 0) == 0 and (def.damage_per_second or 0) == 0 then
				breathable_cids:add(cid)
				if (def.drawtype or "normal") == "airlike" then
					breathable_airlike_cids:add(cid)
				end
			end
		end
		for group in pairs(def.groups or {}) do
			cids_by_group[group]:add(cid)
		end
	end
end)

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

local function get_collision_box(entity_def)
	return (entity_def.initial_properties or {}).collisionbox or entity_def.collisionbox
end

function spawnit.in_entity_poss(cb, pos)
	local x0, y0, z0 = pos.x, pos.y, pos.z
	local poss = {}
	for y = y0 + math_min(0, math_floor(cb[2] + 0.5)), y0 + math_max(0, math_ceil(cb[5] - 0.5)) do
		for x = x0 + math_min(0, math_floor(cb[1] + 0.5)), x0 + math_max(0, math_ceil(cb[4] - 0.5)) do
			for z = z0 + math_min(0, math_floor(cb[3] + 0.5)), z0 + math_max(0, math_ceil(cb[6] - 0.5)) do
				poss[#poss + 1] = vector.new(x, y, z)
			end
		end
	end
	return poss
end

local can_be_in_by_entity_name = {}

local function get_spawn_def(entity_name)
	for _, def in pairs(spawnit.registered_spawns) do
		if def.entity_name == entity_name then
			return def
		end
	end
end

local function get_spawn_def_index(entity_name)
	for def_index, def in pairs(spawnit.registered_spawns) do
		if def.entity_name == entity_name then
			return def_index
		end
	end
end

local function get_can_be_in(entity_name)
	local can_be_in = can_be_in_by_entity_name[entity_name]
	if not can_be_in then
		local def = get_spawn_def(entity_name)
		if def then
			can_be_in = build_can_be(def.within)
		else
			can_be_in = function()
				return false
			end
		end
		can_be_in_by_entity_name[entity_name] = can_be_in
	end
	return can_be_in
end

local function check_can_be_in_single(entity_name, pos)
	local can_be_in = get_can_be_in(entity_name)
	local cid = minetest.get_content_id(minetest.get_node(pos).name)
	return can_be_in(cid)
end

local function check_can_be_in(entity_name, pos)
	local can_be_in = get_can_be_in(entity_name)
	local cb = get_collision_box(minetest.registered_entities[entity_name])
	local in_entity_poss = spawnit.in_entity_poss(cb, pos)
	for j = 1, #in_entity_poss do
		local pos2 = in_entity_poss[j]
		local cid = minetest.get_content_id(minetest.get_node(pos2).name)
		if not can_be_in(cid) then
			return false
		end
	end
	return true
end

minetest.register_chatcommand("show_in_entity_poss", {
	description = S("see the extent of an entity if it spawns at the marked position"),
	params = S("<entity_name>"),
	privs = { [s.debug_priv] = true },
	func = function(name, entity_name)
		local player = minetest.get_player_by_name(name)
		if not player then
			return false, "you are not logged in"
		end
		local pos = (minetest.get_modpath("worldedit") and worldedit.pos1[name])
			or (minetest.get_modpath("areas") and areas.pos1[name])
		if not pos then
			return false, "mark a point w/ worldedit or areas"
		end
		local entity_def = minetest.registered_entities[entity_name]
		if not entity_def then
			return false, "no such entity"
		end
		local cb = get_collision_box(entity_def)
		if not cb then
			return false, "no collision box"
		end

		local poss = spawnit.in_entity_poss(cb, pos)

		for i = 1, #poss do
			local pos2 = poss[i]
			futil.create_ephemeral_hud(player, 10, {
				hud_elem_type = "image_waypoint",
				text = "bubble.png",
				world_pos = pos2,
				scale = { x = 1, y = 1 },
			})
		end
		return true, "marked"
	end,
})

minetest.register_chatcommand("check_can_be_in", {
	description = S("check whether the entity can spawn at the marked point"),
	params = S("<entity_name>"),
	privs = { [s.debug_priv] = true },
	func = function(name, entity_name)
		local player = minetest.get_player_by_name(name)
		if not player then
			return false, "you are not logged in"
		end
		local pos = (minetest.get_modpath("worldedit") and worldedit.pos1[name])
			or (minetest.get_modpath("areas") and areas.pos1[name])
		if not pos then
			return false, "mark a point w/ worldedit or areas"
		end
		local entity_def = minetest.registered_entities[entity_name]
		if not entity_def then
			return false, "no such entity"
		end
		local cb = get_collision_box(entity_def)
		if not cb then
			return false, "no collision box"
		end

		local poss = spawnit.in_entity_poss(cb, pos)

		for i = 1, #poss do
			local pos2 = poss[i]
			if check_can_be_in_single(entity_name, pos2) then
				futil.create_ephemeral_hud(player, 10, {
					hud_elem_type = "image_waypoint",
					text = "bubble.png",
					world_pos = pos2,
					scale = { x = 1, y = 1 },
				})
			else
				futil.create_ephemeral_hud(player, 10, {
					hud_elem_type = "image_waypoint",
					text = "bubble.png^[colorize:red:alpha",
					world_pos = pos2,
					scale = { x = 1, y = 1 },
				})
			end
		end
		return true, "marked"
	end,
})

minetest.register_chatcommand("show_all_in_block", {
	description = S("show all spawn positions in a mapblock"),
	params = S("<entity_name>"),
	privs = { [s.debug_priv] = true },
	func = function(name, entity_name)
		local player = minetest.get_player_by_name(name)
		if not player then
			return false, "you are not logged in"
		end
		local pos = (minetest.get_modpath("worldedit") and worldedit.pos1[name])
			or (minetest.get_modpath("areas") and areas.pos1[name])
		if not pos then
			return false, "mark a point w/ worldedit or areas"
		end
		local entity_def = minetest.registered_entities[entity_name]
		if not entity_def then
			return false, "no such entity"
		end
		local def_index = get_spawn_def_index(entity_name)
		if not def_index then
			return false, "no spawn defintion for entity"
		end
		local block_pos = futil.vector.get_blockpos(pos)
		local block_hpos = minetest.hash_node_position(block_pos)
		local spawn_poss = spawnit.spawn_poss_by_block_hpos[block_hpos]
		if not spawn_poss then
			return false, "nothing currently spawning at that location"
		end
		if type(spawn_poss) == "string" then
			return false, spawn_poss -- might be calculating
		end
		local hpos_set = spawn_poss:get_hpos_set(def_index)
		if not hpos_set then
			return false, "the mob cannot spawn in that location"
		end

		for hpos in hpos_set:iterate() do
			local pos2 = minetest.get_position_from_hash(hpos)
			if check_can_be_in(entity_name, pos2) then
				futil.create_ephemeral_hud(player, 10, {
					hud_elem_type = "image_waypoint",
					text = "bubble.png",
					world_pos = pos2,
					scale = { x = 1, y = 1 },
				})
			else
				futil.create_ephemeral_hud(player, 10, {
					hud_elem_type = "image_waypoint",
					text = "bubble.png^[colorize:red:alpha",
					world_pos = pos2,
					scale = { x = 1, y = 1 },
				})
			end
		end

		return true, "marked"
	end,
})
