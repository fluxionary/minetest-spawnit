local get_connected_players = minetest.get_connected_players
local get_us_time = minetest.get_us_time

local s = spawnit.settings

spawnit._relevant_players_by_def_index = {}

minetest.register_on_mods_loaded(function()
	for i = 1, #spawnit.registered_spawns do
		spawnit._relevant_players_by_def_index[i] = {}
	end
end)

-- O(#players * #defs)
minetest.register_on_leaveplayer(function(player)
	for i = 1, #spawnit._relevant_players_by_def_index do
		local relevant_players = spawnit._relevant_players_by_def_index[i]
		for j = 1, #relevant_players do
			if relevant_players[j] == player then
				table.remove(relevant_players, j)
				break
			end
		end
	end
end)

local def_index_to_update = 1

futil.register_globalstep({
	name = "spawnit:update_relevant_players",
	period = s.update_relevant_players_period,
	func = function()
		if #spawnit.registered_spawns == 0 then
			return
		end
		local start = get_us_time()
		local players = get_connected_players()
		local block_hposs = spawnit._block_hposs_by_def[def_index_to_update]
		local relevant_players = {}
		for i = 1, #players do
			local player = players[i]
			local player_name = player:get_player_name()
			local nearby_block_hposs = spawnit._nearby_block_hpos_set_by_player_name[player_name]
			if block_hposs:intersects(nearby_block_hposs) then
				relevant_players[#relevant_players + 1] = player
			end
		end
		spawnit._relevant_players_by_def_index[def_index_to_update] = relevant_players

		def_index_to_update = (def_index_to_update % #spawnit.registered_spawns) + 1
		spawnit._stats.update_relevant_duration = spawnit._stats.update_relevant_duration + (get_us_time() - start)
	end,
})
