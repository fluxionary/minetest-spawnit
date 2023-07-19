technically we could pre-compute specific positions to spawn a mob before we pick a time to spawn them.

i don't think it'd buy us much. the current algorithm is already more-or-less O(1) for selection.

EDIT: it's currently O(#spawn_rules). if there's only a few dozen spawn rules, this isn't a big issue, but we should
      compensate for the # of rules and only trigger so many at once. we can compensate by increasing the chance of
      spawning if we aren't checking all the rules every cycle.
