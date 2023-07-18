local f = string.format

local spawns_near_something = spawnit.util.spawns_near_something
local spawns_on_something = spawnit.util.spawns_on_something

local MINP, MAXP = futil.vector.get_world_bounds()
local MIN_Y = MINP.y
local MAX_Y = MAXP.y

-- extent of halo around a mapblock that we need to check to see whether mobs fit
spawnit.mob_extents = { 0, 0, 0, 0, 0, 0 }

spawnit.registered_spawns = {}

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

local valid_keys = futil.Set({
	"entity",
	"type",
	"cluster",
	"chance",
	"per_player",
	"on",
	"within",
	"near",
	"min_y",
	"max_y",
	"min_light",
	"max_light",
	"min_time_of_day",
	"max_time_of_day",
	"spawn_in_protected",
	"min_player_distance",
	"max_player_distance",
	"max_active",
	"max_in_area",
	"max_in_area_radius",
	"collisionbox",

	"should_spawn",
	"check_pos",
	"after_spawn",
})

local function validate_keys(def)
	for key in pairs(def) do
		if not valid_keys:contains(key) then
			error(f("unexpected spawn definition key %s", key))
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

function spawnit.register(def)
	local entity = def.entity
	if not entity then
		error("attempt to register spawning w/out specifying entity")
	end
	local entity_def = minetest.registered_entities[entity]
	if not entity_def then
		error(f("attempt to register spawning for unknown entity %s", entity))
	end
	validate_keys(def)

	def = table.copy(def)
	-- default values
	def.type = def.type or "animal"
	def.cluster = def.cluster or 1
	assert(def.cluster >= 1)
	def.chance = def.chance or 300
	assert(def.chance > 0)
	def.per_player = futil.coalesce(def.per_player, true)
	def.on = def.on or { "node" }
	validate_nodes(def.on)
	def.within = def.within or { "breathable" }
	validate_nodes(def.within)
	def.near = def.near or { "any" }
	validate_nodes(def.near)
	def.min_y = def.min_y or MIN_Y
	def.max_y = def.max_y or MAX_Y
	assert(def.min_y <= def.max_y, f("max_y (%i) < min_y (%i); mob cannot spawn", def.max_y, def.min_y))
	def.min_light = def.min_light or 0
	def.max_light = def.max_light or 15
	assert(
		def.min_light <= def.max_light,
		f("min_light (%i) < max_light (%i); mob cannot spawn", def.min_light, def.max_light)
	)
	def.min_time_of_day = def.min_time_of_day or 0
	def.max_time_of_day = def.max_time_of_day or 1
	assert(def.min_time_of_day ~= def.max_time_of_day)
	def.spawn_in_protected = futil.coalesce(def.spawn_in_protected, true)
	assert(
		not def.min_player_distance or not def.max_player_distance or def.min_player_distance <= def.max_player_distance
	)
	def.max_active = def.max_active or -1
	assert(def.max_active ~= 0)
	def.max_in_area = def.max_in_area or -1
	def.max_in_area_radius = 16

	def.collisionbox = (
		def.collisionbox
		or (entity_def.initial_properties or {}).collisionbox
		or entity_def.collisionbox
		or { -0.5, -0.5, -0.5, 0.5, 0.5, 0.5 }
	)
	table.insert(spawnit.registered_spawns, def)
	if def.max_active > 0 then
		spawnit.count_active_mobs(entity)
	end

	update_mob_extents(def)
end

minetest.register_on_mods_loaded(function()
	local contents = minetest.serialize(spawnit.registered_spawns)
	local filename = futil.path_concat(minetest.get_worldpath(), "spawnit_rules.serialized")
	futil.write_file(filename, contents)

	spawnit.register = nil
end)
