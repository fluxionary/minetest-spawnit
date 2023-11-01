# spawnit

a mob spawning API separate from any specific mob implementation.

this is currently functional but very WIP - the performance characteristics are not where i want them to be.

## usage

this is an API. other mods are free to use it, but the main goal is to provide server operators with a single mechanism
for controlling mob spawns. see [API.md] for details on how to register mob spawn definitions.

## features

* better performance than other mob spawning mechanisms
  * CAVEAT: is that the mod makes use of the async environment to do the heaviest computation, so it might
    lower the overall performance of the server when contending w/ active map generation and postgres backends
* more even performance than other mob spawning mechanisms
  * most processes in the mod are constant-time, so lag spikes are unlikely
* scalability with large numbers of mobs and players
* much better control over exactly where and how often mobs spawn
  * asdf
  * CAVEAT: some of the performance features can affect how often mobs spawn in exceptional circumstances
  * CAVEAT:
* optional AFK awareness
  * disable AFK mob farms
  * limit the number of mobs that spawn in one place and wander into unloaded areas, causing lag bombs or other problems



sadf
  existing mob spawn mechanics are quite wasteful. the two main methods for spawning mobs that i'm aware of are
  ABMs and globalsteps. if you want to spawn on stone, your ABM is going to trigger a lot of "false positives",
  ABMs are wasteful. globalsteps can be expensive, if you have to re-analyze the world every time. spawnit instead
  offloads the location of potential spawn locations to the async environment, and uses a constant-time[^1] algorithm
  to spawn mobs. it is designed to scale well with large numbers of players, lots of mobs, and mobs that spawn often.

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
