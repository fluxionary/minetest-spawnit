```lua
-- https://gitea.your-land.de/your-land/bugtracker/issues/4592

spawnit.register({
	entity = "mymod:my_walking_mob",
    type = "monster",  -- or "npc" or "animal", or something custom
    cluster = 1, -- maximum amount to spawn at once (cluster is within a single mapblock)
    chance = 100, -- there will be a 1 in 100 chance of spawning a mob every second
    per_player = false, -- if true, there will be a 1 in 100 chance of spawning a mob every second per connected player

	biome = {"snow"}, -- patterns. by default, no biome preferences
	on = {"node"}, -- any solid full node. or, list of nodes, groups, "walkable" for any solid node (incl. mesh/nodebox)
	within = {"not walkable"},
	min_y = 0,
	max_y = 100,
	min_light = 0,
	max_light = 15,
	min_time_of_day = .75,  -- 0/1 is midnight, 0.25 is dawn-ish, 0.5 is noon, .75 is dusk-ish
	max_time_of_day = .25,
	spawn_in_protected = true,
	min_player_distance = 12,
	max_player_distance = nil,

    max_active = 100,
    max_in_area = 10,
    max_in_area_radius = 16,

    collisionbox = nil, -- if not defined, this is inferred from the entity's definition

	...,  -- TODO other things?

	check_pos = function(pos) end,  -- return true to allow spawning at that position, false to disallow
	after_spawn = function(pos, obj) end,  -- called after a mob has spawned
})
```

```lua
spawnit.register({
	entity = "mymod:my_flying_mob",

	on = {"any"},
	within = {"air"},
})
```

```lua
spawnit.register({
	entity = "mymod:my_swimming_mob",

	on = {"any"},
	within = {"group:water"},
})
```
