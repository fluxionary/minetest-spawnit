local Block = futil.class1()

function Block:_init(blockpos, active)
	self._blockpos = blockpos
	self._objects_are_active = active
end

function Block:is_active_objects()
	return self._objects_are_active
end

function Block:set_active_objects(value)
	self._objects_are_active = value
end

function Block:__eq(other)
	return self._blockpos:equals(other._blockpos)
end

function Block:__tostring()
	return "Block" .. minetest.pos_to_string(self._blockpos)
end

function Block:offset(dx, dy, dz)
	return Block(self._blockpos:offset(dx, dy, dz))
end

function Block:get_pos()
	return self._blockpos
end

function Block:hash()
	return minetest.hash_node_position(self._blockpos)
end

function Block:get_min()
	return futil.vector.get_block_min(self._blockpos)
end

function Block:get_max()
	return futil.vector.get_block_max(self._blockpos)
end

function Block:get_center()
	return vector.add(self:get_min(), 8) -- 8 = 16 / 2
end

function Block:get_bounds()
	return futil.vector.get_block_bounds(self._blockpos)
end

function Block:is_active()
	minetest.compare_block_status(self:get_min(), "active")
end

function Block:iter_poss()
	local minp, maxp = self:get_bounds()
	return futil.vector.iterate_area(minp, maxp)
end

spawnit.Block = Block
