local f = string.format

local spawns_on_ground = spawnit.util.spawns_on_ground

local MINP, MAXP = futil.vector.get_world_bounds()
local MIN_Y = MINP.y
local MAX_Y = MAXP.y

-- extent of halo around a mapblock that we need to check to see whether mobs fit
spawnit.mob_extents = { 0, 0, 0, 0, 0, 0 }

spawnit.registered_spawnings = {}

local function update_mob_extents(collisionbox, on_ground)
	spawnit.mob_extents[1] = math.min(spawnit.mob_extents[1], math.floor(collisionbox[1] + 0.5))
	if on_ground then
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

function spawnit.register(def)
	local entity = def.entity
	if not entity then
		error("attempt to register spawning w/out specifying entity")
	end
	local entity_def = minetest.registered_entities[entity]
	if not entity_def then
		error(f("attempt to register spawning for unknown entity %s", entity))
	end
	def = table.copy(def)
	-- default values
	def.type = def.type or "animal"
	def.cluster = def.cluster or 1
	assert(def.cluster > 1)
	def.chance = def.chance or 300
	assert(def.chance > 0)
	def.per_player = def.per_player or false
	def.biome = { ".*" }
	def.on = def.on or { "node" }
	def.within = def.within or { "not walkable" }
	-- TODO: verify that biome, on, and within are valid
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
	table.insert(spawnit.registered_spawnings, def)
	if def.max_active > 0 then
		spawnit.count_active_mobs(entity)
	end

	update_mob_extents(def.collisionbox, spawns_on_ground(def))
end
