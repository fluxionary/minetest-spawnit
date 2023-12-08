local equals = futil.equals

spawnit.util = {}

function spawnit.util.spawns_near_something(def)
	local near = def.near
	for i = 1, #near do
		if near[i] == "any" then
			return false
		end
	end

	return true
end

function spawnit.util.spawns_on_something(def)
	local on = def.on
	for i = 1, #on do
		if on[i] == "any" then
			return false
		end
	end

	return true
end

function spawnit.util.is_full_nodebox(nodebox)
	return nodebox.type == "regular"
		or (nodebox.type == "fixed" and equals(nodebox.fixed, { -0.5, -0.5, -0.5, 0.5, 0.5, 0.5 }))
end
