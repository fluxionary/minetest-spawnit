WARNING: many internal functions are exposed, but you should not rely on anything that isn't documented here.

```lua
-- https://gitea.your-land.de/your-land/bugtracker/issues/4592

spawnit.register({
	entity_name = "mymod:my_walking_mob",
	groups = { monster = 1 },  -- or "npc" or "animal", or something custom
	cluster = 2, -- maximum amount to spawn at once (cluster is within a single mapblock)
	chance = 100, -- there will be a 1 in 100 chance of trying to spawn the mob (or cluster) per second, ish
	per_player = false, -- if true, there will be a 1 in 100 chance of spawning a mob every second per connected player

	-- TODO: allow and/or/not/parentheses for these things
	-- WARNING: that might break something!
	on = { "node" }, -- any solid full node. or, list of nodes, groups, "walkable" for any solid node (incl. mesh/nodebox)
	within = { "not walkable" },  -- all of the mob must be within these nodes
	near = { "any" },  -- mob must be "touching" these.
	spawn_in_protected = true,
	min_y = 0,
	max_y = 100,
	max_active = 100,
	max_in_area = 10,
	max_in_area_radius = 16,
	min_node_light = 0,
	max_node_light = 15,
    -- this mob will only spawn between dusk and dawn
	min_time_of_day = .75,  -- 0/1 is midnight, 0.25 is dawn-ish, 0.5 is noon, .75 is dusk-ish
	max_time_of_day = .25,  -- set min to 0, and max to 1, to indicate any time (default)
	min_player_distance = 12,
	max_player_distance = -1,  -- no limit


	collisionbox = nil, -- if not defined, this is inferred from the entity's definition

	should_spawn = function()  end,
	check_pos = function(pos) end,  -- return true to allow spawning at that position, false to disallow
	after_spawn = function(pos, obj) end,  -- called after a mob has spawned
})
```

```lua
spawnit.register({
	entity_name = "mymod:my_flying_mob",

	on = {"any"},
	within = {"air"},
})
```

```lua
spawnit.register({
	entity_name = "mymod:my_swimming_mob",

	on = {"any"},
	within = {"group:water"},
})
```

if you want to spawn different mob variants w/ various probabilities:
```lua
spawnit.register({
	entity_name = {
		["mobs_animal:sheep_white"] = 24,  -- 3/4 of the time
		["mobs_animal:sheep_black"] = 4,  -- 1/8 of the time
		["mobs_animal:sheep_brown"] = 2,  -- 1/16 of the time
		["mobs_animal:sheep_grey"] = 1,  -- 1/32 of the time
		["mobs_animal:sheep_dark_grey"] = 1,
	},
})
```

remove all spawn rules for some mob. note that any changes to the spawn rules *MUST* be done *BEFORE* `on_mods_loaded`!
```lua
spawnit.clear_spawns("mymod:my_walking_mob")
```
