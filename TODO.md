before release:
* code quality:
  * prefix all "internal" but published function names with `_`
  * add settingtypes descriptions

separate the active object calculator into a separate mod so that others can use it.

create an AFK detector API mod

* tuning
* currently, too many players moving around at once will likely starve updates for some of them because of the way
  the cue is limited. instead of a fixed limit on the number of items a single player can add to the queue, we need
  to scale that limit to the number of present players
  * the first way i did this doesn't account for players which are *AFK* and not generating anything new

* the TOOOs in the files


FUTURE:
* need to be able to somehow say "spawn on leaves, but only if they're solid"
  * and/or/not/parentheses
* add way to toggle/filter spawns during runtime, based on groups or ???
* add way to specify that mobs shouldn't spawn in an area
* show exponential moving averages of some HUD stat values
