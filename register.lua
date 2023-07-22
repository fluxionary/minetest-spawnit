local f = string.format

local s = spawnit.settings

local spawns_near_something = spawnit.util.spawns_near_something
local spawns_on_something = spawnit.util.spawns_on_something

local MINP, MAXP = futil.vector.get_world_bounds()
local MIN_Y = MINP.y
local MAX_Y = MAXP.y

-- extent of halo around a mapblock that we need to check to see whether mobs fit
spawnit.mob_extents = { 0, 0, 0, 0, 0, 0 }

-- warning: do NOT modify the following after `on_mods_loaded`!!!
spawnit.registered_spawns = {}
spawnit.relevant_mobs = futil.Set()

local function update_mob_extents(def)
	local collisionbox = def.collisionbox
	if spawns_near_something(def) then
		for i = 1, 3 do
			spawnit.mob_extents[i] = math.max(spawnit.mob_extents[i], math.ceil(collisionbox[i] + 0.5) - 1)
		end

		for i = 4, 6 do
			spawnit.mob_extents[i] = math.max(spawnit.mob_extents[i], math.ceil(collisionbox[i] - 0.5) + 1)
		end
	else
		spawnit.mob_extents[1] = math.min(spawnit.mob_extents[1], math.floor(collisionbox[1] + 0.5))
		if spawns_on_something(def) then
			-- make sure we can check the node under the mob
			spawnit.mob_extents[2] = math.min(spawnit.mob_extents[2], math.floor(collisionbox[2] + 0.5) - 1)
		else
			spawnit.mob_extents[2] = math.min(spawnit.mob_extents[2], math.floor(collisionbox[2] + 0.5))
		end
		spawnit.mob_extents[3] = math.min(spawnit.mob_extents[3], math.floor(collisionbox[3] + 0.5))

		for i = 4, 6 do
			spawnit.mob_extents[i] = math.max(spawnit.mob_extents[i], math.ceil(collisionbox[i] - 0.5))
		end
	end
end

local default_values = {
	cluster = 1,
	chance = s.default_chance,
	per_player = true,
	on = { "node" },
	within = { "breathable" },
	near = { "any" },
	spawn_in_protected = s.default_spawn_in_protected,
	min_y = MIN_Y,
	max_y = MAX_Y,
	max_active = -1,
	max_in_area = -1,
	max_any_in_area = -1,
	max_in_area_radius = s.default_max_in_area_radius,
	min_node_light = 0,
	max_node_light = 15,
	min_time_of_day = 0,
	max_time_of_day = 1,
	min_natural_light = 0,
	max_natural_light = 15,
}

local function set_default_values(t)
	for key, default in pairs(default_values) do
		t[key] = futil.coalesce(t[key], default)
	end
end

local valid_keys = futil.Set({
	"entity_name",
	"groups",
	"cluster",
	"chance",
	"per_player",
	"on",
	"within",
	"near",
	"spawn_in_protected",
	"min_y",
	"max_y",
	"max_active",
	"max_in_area",
	"max_any_in_area",
	"max_in_area_radius",
	"min_node_light",
	"max_node_light",
	"min_time_of_day",
	"max_time_of_day",
	"min_natural_light",
	"max_natural_light",
	"min_player_distance",
	"max_player_distance",
	"collisionbox",

	"should_spawn",
	"check_pos",
	"after_spawn",
})

local function validate_keys(def)
	for key in pairs(def) do
		if not valid_keys:contains(key) then
			error(f("unexpected spawn definition key %q", key))
		end
	end
end

local special_nodes = futil.Set({
	"any",
	"walkable",
	"node",
	"not walkable",
	"breathable",
	"breathable airlike",
})

local function validate_node(node)
	if special_nodes:contains(node) then
		return
	elseif node:match("^group:") then
		-- the group doesn't necessarily have to match anything
		return
	elseif minetest.registered_nodes[node] then
		return
	else
		error(f("unknown node %s", node))
	end
end

local function validate_nodes(nodes)
	for _, node in ipairs(nodes) do
		validate_node(node)
	end
end

local function validate_def(def, do_validate_nodes)
	validate_keys(def)
	local entity_name = def.entity_name
	if not entity_name then
		error("attempt to register spawning w/out specifying entity")
	end
	if type(entity_name) == "string" then
		local entity_def = minetest.registered_entities[entity_name]
		if not entity_def then
			error(f("attempt to register spawning for unknown entity %s", entity_name))
		end
	elseif type(entity_name) == "table" then
		for kind in pairs(entity_name) do
			local kind_def = minetest.registered_entities[kind]
			if not kind_def then
				error(f("attempt to register spawning for unknown entity %s", kind))
			end
		end
	else
		error(f("invalid entity specification %s", dump(entity_name)))
	end

	assert(def.cluster >= 1)
	assert(def.chance > 0)
	if do_validate_nodes then
		validate_nodes(def.on)
		validate_nodes(def.within)
		validate_nodes(def.near)
	end
	assert(def.min_y <= def.max_y, f("max_y (%i) < min_y (%i); mob cannot spawn", def.max_y, def.min_y))
	assert(
		def.min_node_light <= def.max_node_light,
		f("min_node_light (%i) < max_node_light (%i); mob cannot spawn", def.min_node_light, def.max_node_light)
	)
	assert(
		def.min_natural_light <= def.max_natural_light,
		f(
			"min_natural_light (%i) < max_natural_light (%i); mob cannot spawn",
			def.min_natural_light,
			def.max_natural_light
		)
	)
	assert(def.min_time_of_day ~= def.max_time_of_day)
	assert(
		not def.min_player_distance or not def.max_player_distance or def.min_player_distance <= def.max_player_distance
	)
	assert(def.max_active ~= 0)
end

function spawnit.register(def, do_validate_nodes)
	def = table.copy(def)
	set_default_values(def)
	validate_def(def, do_validate_nodes)
	local entity_name = def.entity_name
	local entity_def
	if type(entity_name) == "string" then
		spawnit.relevant_mobs:add(entity_name)
		entity_def = minetest.registered_entities[entity_name]
	elseif type(entity_name) == "table" then
		-- it's a map of names to chances
		for kind in pairs(entity_name) do
			entity_def = entity_def or minetest.registered_entities[kind]
			spawnit.relevant_mobs:add(kind)
		end

		def.chooser = futil.random.WeightedChooser(entity_name)
	end

	def.collisionbox = (
		def.collisionbox
		or (entity_def.initial_properties or {}).collisionbox
		or entity_def.collisionbox
		or { -0.5, -0.5, -0.5, 0.5, 0.5, 0.5 }
	)
	update_mob_extents(def)
	table.insert(spawnit.registered_spawns, def)
	if def.max_active > 0 then
		spawnit.count_active_mobs(entity_name)
	end
end

function spawnit.clear_spawns(entity_name)
	for i = #spawnit.registered_spawns, 1, -1 do
		if spawnit.registered_spawns[i].entity_name == entity_name then
			table.remove(spawnit.registered_spawns, i)
		end
	end
end

minetest.register_on_mods_loaded(function()
	local contents = minetest.serialize(spawnit.registered_spawns)
	local filename = futil.path_concat(minetest.get_worldpath(), "spawnit_rules.serialized")
	futil.write_file(filename, contents)

	spawnit.register = function()
		error("cannot register new spawns after mods are loaded.")
	end
	spawnit.clear_spawns = function()
		error("cannot clear spawns after mods are loaded.")
	end
end)

spawnit.registered_pos_checks = {}

function spawnit.register_pos_check(callback)
	table.insert(spawnit.registered_pos_checks, callback)
end
