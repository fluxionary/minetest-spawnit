local forceloaded = futil.Set()
local forceload_counts = futil.DefaultTable(function()
	return 0
end)
local tempload_counts = futil.DefaultTable(function()
	return 0
end)

local function read_forceloaded()
	local worldpath = minetest.get_worldpath()
	local filename = futil.path_concat(worldpath, "force_loaded.txt")
	local contents = futil.load_file(filename)
	return minetest.deserialize(contents or "") or {}
end

do
	for hpos, count in pairs(read_forceloaded()) do
		forceload_counts[hpos] = count
		forceloaded:add(hpos)
	end
end

local old_forceload_block = minetest.forceload_block

function minetest.forceload_block(pos, transient, limit)
	local rv = old_forceload_block(pos, transient, limit)
	if rv then
		local hpos = minetest.hash_node_position(futil.vector.get_blockpos(pos))
		if transient then
			tempload_counts[hpos] = tempload_counts[hpos] + 1
		else
			forceload_counts[hpos] = forceload_counts[hpos] + 1
		end
		forceloaded:add(hpos)
	end
	return rv
end

local old_forceload_free_block = minetest.forceload_free_block

function minetest.forceload_free_block(pos, transient)
	local hpos = minetest.hash_node_position(futil.vector.get_blockpos(pos))
	if transient then
		local v = tempload_counts[hpos]
		if v <= 1 then
			tempload_counts[hpos] = nil
			if not rawget(forceload_counts, hpos) then
				forceloaded:remove(hpos)
			end
		else
			tempload_counts[hpos] = v - 1
		end
	else
		local v = forceload_counts[hpos]
		if v <= 1 then
			forceload_counts[hpos] = nil
			if not rawget(tempload_counts, hpos) then
				forceloaded:remove(hpos)
			end
		else
			forceload_counts[hpos] = v - 1
		end
	end
	return old_forceload_free_block(pos, transient)
end

function spawnit.get_forceloaded()
	return futil.Set(forceloaded)
end
