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

* ~~cursing~~ currently the performance in guessing which parts of the map are active for entities are terrible.
  actual finding spawn positions and spawning mobs is fast.




[^1]: usage of certain features, notably restrictions on the number of mobs in an area, are not constant-time.
