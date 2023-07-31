spawnit._active_counts = {}

function spawnit._count_active_mobs(entity_name)
	if spawnit._active_counts[entity_name] then
		return
	end

	spawnit._active_counts[entity_name] = 0

	local entity_def = minetest.registered_entities[entity_name]
	local old_on_activate = entity_def.on_activate
	local old_on_deactivate = entity_def.on_deactivate

	function entity_def.on_activate(self, staticdata, dtime_s)
		spawnit._active_counts[entity_name] = spawnit._active_counts[entity_name] + 1
		if old_on_activate then
			return old_on_activate(self, staticdata, dtime_s)
		end
	end

	function entity_def.on_deactivate(self, removal)
		spawnit._active_counts[entity_name] = spawnit._active_counts[entity_name] - 1
		if old_on_deactivate then
			return old_on_deactivate(self, removal)
		end
	end
end

function spawnit._get_active_count(entity_name)
	local active_count = spawnit._active_counts[entity_name]
	if active_count then
		return active_count
	end
	-- the old fashioned, slow way
	active_count = 0
	for _, ent in pairs(minetest.luaentities) do
		if ent.name == entity_name then
			active_count = active_count + 1
		end
	end
	return active_count
end
