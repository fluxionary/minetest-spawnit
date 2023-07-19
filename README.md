# spawnit

a mob spawning API separate from any specific mob implementation.

this is currently functional but very WIP - the performance characteristics are not where i want them to be.

## usage

this is an API. other mods are free to use it, but the main goal is to provide server operators with a single mechanism
for controlling mob spawns. see [API.md] for details on how to register mob spawn definitions.

## features

* better performance than other mob spawning mechanisms

  ABMs are wasteful. globalsteps can be expensive, if you have to re-analyze the world every time. spawnit instead
  offloads the location of potential spawn locations to the async environment, and uses a constant-time[^1] algorithm
  to spawn

## how to disable spawning in other mods

### petz

set `spawn_interval = math.huge` in "petz.conf"

### mobs_redo

set `mobs_spawn = false` in "minetest.conf"

### mob_core

set `mob_core.spawn_enabled = false` ... somewhere? or am i just looking at yl's mangled mob_core?

### water_life

```lua
table.insert_all(water_life.no_spawn_table, {
	"water_life:alligator",
	"water_life:beaver",
	"water_life:clams",
	"water_life:clownfish",
	"water_life:coralfish",
	"water_life:croc",
	"water_life:gecko",
	"water_life:gull",
	"water_life:jellyfish",
	"water_life:piranha",
	"water_life:fish",
	"water_life:urchin",
	"water_life:shark",
	"water_life:snake",
	"water_life:whale",
})
```


[^1]: usage of certain features, notably restrictions on the number of mobs in an area, are not constant-time.
