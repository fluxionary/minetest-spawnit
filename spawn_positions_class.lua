-- TODO: this whole class is kinda useless, possibly remove

local SpawnPositions = futil.class1()

function SpawnPositions:_init(hpos_set_by_def)
	self._hpos_set_by_def = hpos_set_by_def -- indexed by numbers, but not contiguous
end

function SpawnPositions:get_hpos_set(def_index)
	return self._hpos_set_by_def[def_index]
end

function SpawnPositions:iterate_def_indices()
	local def_index
	return function()
		def_index = next(self._hpos_set_by_def, def_index)
		return def_index
	end
end

function SpawnPositions:remove_hpos(def_index, hpos)
	local hpos_set = self._hpos_set_by_def[def_index]
	if not hpos_set then
		-- TODO this should never happen... log?
		return false
	end
	hpos_set:discard(hpos) -- TODO `hpos_set:remove()` should never fail but it does... log?
	if self._hpos_set_by_def[def_index]:is_empty() then
		self._hpos_set_by_def[def_index] = nil
		return true
	end
	return false
end

spawnit.SpawnPositions = SpawnPositions
