local SpawnPositions = futil.class1()

function SpawnPositions:_init(blockpos, poss_by_def)
	self._blockpos = blockpos
	self._poss_by_def = poss_by_def -- indexed by numbers, but not contiguous
end

function SpawnPositions:get_poss(n)
	return self._poss_by_def[n]
end

spawnit.SpawnPositions = SpawnPositions
