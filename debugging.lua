local math_ceil = math.ceil
local math_floor = math.floor
local math_max = math.max
local math_min = math.min

local v_new = vector.new
local v_zero = vector.zero

local add_particlespawner = minetest.add_particlespawner
local compare_block_status = minetest.compare_block_status
local get_content_id = minetest.get_content_id
local get_node = minetest.get_node
local get_position_from_hash = minetest.get_position_from_hash
local get_us_time = minetest.get_us_time
local hash_node_position = minetest.hash_node_position
local pos_to_string = minetest.pos_to_string

local DefaultTable = futil.DefaultTable
local Set = futil.Set
local get_block_center = futil.vector.get_block_center
local get_blockpos = futil.vector.get_blockpos

local has = spawnit.has
local log = spawnit.log
local S = spawnit.S
local s = spawnit.settings

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
		if name ~= "ignore" then
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

function spawnit._in_entity_poss(cb, pos)
	local x0, y0, z0 = pos.x, pos.y, pos.z
	local poss = {}
	for y = y0 + math_min(0, math_floor(cb[2] + 0.5)), y0 + math_max(0, math_ceil(cb[5] - 0.5)) do
		for x = x0 + math_min(0, math_floor(cb[1] + 0.5)), x0 + math_max(0, math_ceil(cb[4] - 0.5)) do
			for z = z0 + math_min(0, math_floor(cb[3] + 0.5)), z0 + math_max(0, math_ceil(cb[6] - 0.5)) do
				poss[#poss + 1] = v_new(x, y, z)
			end
		end
	end
	return poss
end

local can_be_in_by_entity_name = {}

local function get_spawn_defs(entity_name)
	local defs = {}
	for _, def in pairs(spawnit.registered_spawns) do
		if type(def.entity_name) == "string" then
			if def.entity_name == entity_name then
				defs[#defs + 1] = def
			end
		else
			for name in pairs(def.entity_name) do
				if name == entity_name then
					defs[#defs + 1] = def
					break
				end
			end
		end
	end
	return defs
end

local function get_spawn_def_indices(entity_name)
	local def_indices = {}
	for def_index, def in pairs(spawnit.registered_spawns) do
		if type(def.entity_name) == "string" then
			if def.entity_name == entity_name then
				def_indices[#def_indices + 1] = def_index
			end
		else
			for name in pairs(def.entity_name) do
				if name == entity_name then
					def_indices[#def_indices + 1] = def_index
					break
				end
			end
		end
	end
	return def_indices
end

local function get_can_be_in(entity_name)
	local can_be_in = can_be_in_by_entity_name[entity_name]
	if not can_be_in then
		local defs = get_spawn_defs(entity_name)
		if #defs > 0 then
			local can_be_ins = {}
			for i = 1, #defs do
				can_be_ins[i] = build_can_be(defs[i].within)
			end
			can_be_in = function(cid)
				for i = 1, #can_be_ins do
					if can_be_ins[i](cid) then
						return true
					end
				end
				return false
			end
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
	local cid = get_content_id(get_node(pos).name)
	return can_be_in(cid)
end

local function check_can_be_in(entity_name, pos)
	local can_be_in = get_can_be_in(entity_name)
	local cb = get_collision_box(minetest.registered_entities[entity_name])
	local in_entity_poss = spawnit._in_entity_poss(cb, pos)
	for j = 1, #in_entity_poss do
		local pos2 = in_entity_poss[j]
		local cid = get_content_id(get_node(pos2).name)
		if not can_be_in(cid) then
			return false
		end
	end
	return true
end

minetest.register_chatcommand("spawnit_show_in_entity_poss", {
	description = S("see the extent of an entity if it spawns at the marked position"),
	params = S("<entity_name>"),
	privs = { [s.debug_priv] = true },
	func = function(name, entity_name)
		local player = minetest.get_player_by_name(name)
		if not player then
			return false, "you are not logged in"
		end
		local pos = (has.worldedit and worldedit.pos1[name]) or (has.areas and areas.pos1[name])
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

		local poss = spawnit._in_entity_poss(cb, pos)

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

minetest.register_chatcommand("spawnit_check_can_be_in", {
	description = S("check whether the entity can spawn at the marked point"),
	params = S("<entity_name>"),
	privs = { [s.debug_priv] = true },
	func = function(name, entity_name)
		local player = minetest.get_player_by_name(name)
		if not player then
			return false, "you are not logged in"
		end
		local pos = (has.worldedit and worldedit.pos1[name]) or (has.areas and areas.pos1[name])
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

		local poss = spawnit._in_entity_poss(cb, pos)

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

minetest.register_chatcommand("spawnit_show_all_in_block", {
	description = S("show all spawn positions in a mapblock"),
	params = S("<entity_name>"),
	privs = { [s.debug_priv] = true },
	func = function(name, entity_name)
		local player = minetest.get_player_by_name(name)
		if not player then
			return false, "you are not logged in"
		end
		local pos = (has.worldedit and worldedit.pos1[name]) or (has.areas and areas.pos1[name])
		if not pos then
			return false, "mark a point w/ worldedit or areas"
		end
		local entity_def = minetest.registered_entities[entity_name]
		if not entity_def then
			return false, "no such entity"
		end
		local def_indices = get_spawn_def_indices(entity_name)
		if #def_indices == 0 then
			return false, "no spawn defintion for entity"
		end
		local block_pos = get_blockpos(pos)
		local block_hpos = hash_node_position(block_pos)
		local spawn_poss = spawnit._spawn_poss_by_block_hpos[block_hpos]
		if not spawn_poss then
			return false, "nothing currently spawning at that location"
		end
		if type(spawn_poss) == "string" then
			return false, spawn_poss -- might be calculating
		end
		local hpos_set = Set()
		for i = 1, #def_indices do
			local hposs = spawn_poss:get_hpos_set(def_indices[i])
			if hposs then
				for hpos in hposs:iterate() do
					hpos_set:add(hpos)
				end
			end
		end
		if hpos_set:is_empty() then
			return false, "the mob cannot spawn in that location"
		end

		for hpos in hpos_set:iterate() do
			local pos2 = get_position_from_hash(hpos)
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

local mobs_registered_for_lifetimer = Set()

function spawnit._register_mob_lifetimer(entity_name)
	if mobs_registered_for_lifetimer:contains(entity_name) then
		return
	end
	mobs_registered_for_lifetimer:add(entity_name)
	local def = minetest.registered_entities[entity_name]
	local old_on_activate = def.on_activate
	function def.on_activate(self, staticdata, dtime_s)
		self._spawnit_lifetimer = get_us_time()
		local pos = self.object:get_pos()
		if pos then
			pos = pos:round()
			log(
				"action",
				"%s @ %s activates in %s mapblock",
				self.name or self.object:get_entity_name(),
				pos_to_string(pos),
				compare_block_status(pos, "active") and "active" or "inactive"
			)
		else
			log("action", "%s activates with no position?!")
		end
		if old_on_activate then
			return old_on_activate(self, staticdata, dtime_s)
		end
	end

	local old_on_deactivate = def.on_deactivate
	function def.on_deactivate(self, removal)
		local elapsed = get_us_time() - self._spawnit_lifetimer
		local pos = self.object:get_pos():round()
		local spos = pos_to_string(pos)
		if removal then
			log("action", "%s @ %s was removed after %.3fs", entity_name, spos, elapsed / 1e6)
		else
			log(
				"action",
				"%s @ %s was deactivated after %.3fs (%s)",
				entity_name,
				spos,
				elapsed / 1e6,
				spawnit.is_active_object_block(pos) and "in active object region" or "not in active object region"
			)
		end
		if old_on_deactivate then
			return old_on_deactivate(self, removal)
		end
	end
end

function spawnit._get_look_angle_offset(player, pos)
	local player_pos = player:get_pos()
	local look_dir = player:get_look_dir()
	local properties = player:get_properties()
	local eye_height = properties.eye_height
	local eye_pos = player_pos:offset(0, eye_height, 0)
	local to_pos = eye_pos - pos
	local theta = math.acos(look_dir:dot(to_pos) / (look_dir:length() * to_pos:length()))
	return futil.math.rad2deg(theta)
end

local MAP_BLOCKSIZE = minetest.MAP_BLOCKSIZE
local BLOCK_MAX_RADIUS = math.sqrt(3) / 2 * MAP_BLOCKSIZE
function spawnit._get_look_angle_offset_block(player, pos)
	local blockpos = get_blockpos(pos)
	local center = get_block_center(blockpos)
	local player_pos = player:get_pos()
	local look_dir = player:get_look_dir()
	local properties = player:get_properties()
	local eye_height = properties.eye_height
	local eye_pos = player_pos:offset(0, eye_height, 0)
	local adjdist = BLOCK_MAX_RADIUS / math.cos((math.pi - futil.math.deg2rad(72)) / 2)
	local blockpos_adj = center - (eye_pos - look_dir * adjdist)
	local theta = math.acos(vector.dot(look_dir, blockpos_adj) / (look_dir:length() * blockpos_adj:length()))
	return futil.math.rad2deg(theta)
end

local block_particles_by_player_name = {}

minetest.register_on_leaveplayer(function(player)
	local player_name = player:get_player_name()
	local block_particles = block_particles_by_player_name[player_name]
	if block_particles then
		for i = 1, #block_particles do
			minetest.delete_particlespawner(block_particles[i])
		end
		block_particles_by_player_name[player_name] = nil
	end
end)

minetest.register_chatcommand("spawnit_ao_block_visualizer", {
	description = S("visualize assumed active object blocks for a player (or yourself)."),
	params = S("[<player_name>]"),
	privs = { [s.debug_priv] = true },
	func = function(name, player_name)
		player_name = player_name:trim()
		if player_name ~= "" then
			player_name = canonical_name.get(player_name)
			if not minetest.player_exists(name) then
				return false, S("unknown player")
			elseif not minetest.get_player_by_name(player_name) then
				return false, S("the player must be logged in")
			end
		else
			if not minetest.get_player_by_name(name) then
				return false, S("you must be logged in")
			end
			player_name = name
		end

		local block_particles = block_particles_by_player_name[player_name]
		if block_particles then
			for i = 1, #block_particles do
				minetest.delete_particlespawner(block_particles[i])
			end
			block_particles_by_player_name[player_name] = nil
			return true, S("visualization removed")
		else
			block_particles = {}
		end

		local nearby_block_hpos_set = spawnit._nearby_block_hpos_set_by_player_name[player_name]
		for block_hpos in nearby_block_hpos_set:iterate() do
			if rawget(spawnit._visibility_by_block_hpos, block_hpos) then
				local block_pos = get_position_from_hash(block_hpos)
				local block_center = get_block_center(block_pos)

				local id = add_particlespawner({
					amount = 1, -- 1 per second
					time = 0, -- forever
					collisiondetection = false,
					collision_removal = false,
					object_collision = false,
					vertical = false,
					texture = "[combine:1x1^[noalpha^[colorize:#FFF8:255",

					minpos = block_center,
					maxpos = block_center,
					minvel = v_zero(),
					maxvel = v_zero(),
					minacc = v_zero(),
					maxacc = v_zero(),
					minexptime = 2,
					maxexptime = 2,
					minsize = 20,
					maxsize = 20,
				})
				if id >= 0 then
					block_particles[#block_particles + 1] = id
				end
			end
		end

		block_particles_by_player_name[player_name] = block_particles
		return true, S("visualization added")
	end,
})

local show_waypoints_by_player_name = {}

minetest.register_on_leaveplayer(function(player)
	show_waypoints_by_player_name[player:get_player_name()] = nil
end)

minetest.register_chatcommand("spawnit_toggle_spawn_waypoints", {
	-- every time an entity spawns, generate a waypoint that lasts for 10 seconds or something
	description = S(""),
	privs = { [s.debug_priv] = true },
	func = function(name)
		if not minetest.get_player_by_name(name) then
			return false, S("you must be logged in")
		end
		if show_waypoints_by_player_name[name] then
			show_waypoints_by_player_name = nil
			return true, S("spawn waypoints disabled (may take a few seconds for all to disappear)")
		end
		show_waypoints_by_player_name[name] = true
		return true, S("spawn waypoints enabled")
	end,
})

function spawnit._add_spawn_waypoint(pos, entity_name)
	for player_name in pairs(show_waypoints_by_player_name) do
		local player = minetest.get_player_by_name(player_name)
		if player then
			futil.create_ephemeral_hud(player, s.spawn_waypoint_timeout, {
				hud_elem_type = "waypoint",
				name = entity_name,
				text = S("m"),
				number = 0xffffff,
				precision = 1,
				world_pos = pos,
			})
		end
	end
end

minetest.register_chatcommand("spawnit_toggle", {
	description = S("toggle all spawnit behavior"),
	privs = { [s.debug_priv] = true },
	func = function()
		spawnit.enabled = not spawnit.enabled
		if spawnit.enabled then
			return true, S("spawnit now enabled")
		else
			return true, S("spawnit now disabled")
		end
	end,
})
