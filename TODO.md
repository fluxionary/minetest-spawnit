* all the TOOOs in the files
* prefix all "internal" but published function names with `_`
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
* hamsters are spawning in the ocean
* show counts of things calculated in HUD, not just calculating
* need to be able to somehow say "spawn on leaves, but only if they're solid"
  * and/or/not/parentheses
* show exponential moving averages of some HUD stat values
* if your priv gets revoked, you can't disable the HUD...
* break up "too far" calculations into separate xz and y factors
* add way to toggle/filter spawns during runtime?
