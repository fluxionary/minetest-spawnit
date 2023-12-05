local Set = futil.Set

-- for a given mapblock, who is it "visible" to - that is, who is keeping it in range for active objects?
-- if a block is no longer visible to any players, it is removed from this map.
spawnit._visibility_by_block_hpos = futil.DefaultTable(function()
	return Set()
end)

-- for a given mapblock, who was it visible to "recently"? if a player moves too far away from a block,
-- they are no longer nearby. if it is not near any players, it is removed from this map.
spawnit._nearby_players_by_block_hpos = futil.DefaultTable(function()
	return Set()
end)

-- for a given player, which blocks are near them? these blocks may not be "visible".
spawnit._nearby_block_hpos_set_by_player_name = {}

-- maps a definition index to a set of hashed block positions which have valid spawn points for that definition.
spawnit._block_hposs_by_def = futil.DefaultTable(function()
	return Set()
end)

-- a spawn position object indexed by hashed block position.
-- a spawn position object is a wrapper for a set called hpos_set_by_def, which maps a spawn definition index to
-- a set of hashed node positions.
spawnit._spawn_poss_by_block_hpos = {}
