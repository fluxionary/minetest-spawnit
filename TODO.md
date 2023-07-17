* all the TOOOs in the files
* prefix all "internal" but published function names with `_`
* stats HUD (monitor usage and performance)
* document how to disable builtin spawning in various mods
* some functions need better names
* i think some data we track in e.g. visible blocks is not used or redundant
* add settingtypes descriptions
* functionality testing
* performance testing
  * spawnit.find_spawn_poss(block) seems to be expensive - enqueue the creation of jobs?
  * async callback also apparently is expensive? so queue those too.
  * why is ao calculation so expensive? we're processing... like 5000 data points?
* bats are spawning in the daytime...
* show counts of things calculated in HUD, not just calculating
* need to be able to somehow say "spawn on leaves, but only if they're solid"
* show exponential moving averages of some HUD stat values
* don't recalculate player AO if they are moving too quickly (check get_velocity and also total moved distance)
  * maybe we need to split up adding new AO stuff and removing stale AO stuff, otherwise we end up trying to
    spawn mobs in unloaded areas
