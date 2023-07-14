an active object region is defined in relation to each player. it is composed of two parts:

1. the active blocks around the player, defined by the `active_block_range` setting
   (query via `minetest.compare_block_status`). this is (more-or-less) a cubic prism centered on the mapblock where
   the player is standing. it only updates every so often for the engine, but we will not bother asking the engine
   about it, because it can change quickly.
2. a cone extending from the player, w/ an axis in the direction the player is looking, intersecting with a sphere w/
   a radius defined by `active_object_send_range_blocks`. the "width" of the cone is determined by the player's FOV -
   so using e.g. binoculars will narrow it. as i understand the code, the cone is roughly rounded to mapblocks.

note that if `active_object_send_range_blocks <= active_block_range`, the 2nd part is redundant.

any active objects outside this volume (for all players) will be "deactivated" - they will become "static" objects,
only stored in the mapblock definition (note that active objects also have a version of themselves stored in some
mapblock, or they would always be lost in a hard crash).

```
         /.
--------/...
|....../.....
|...../......
|..../........
|...P=========
|....\........
|.....\......
|......\.....
--------\...
         \.

DIAGRAM 1.

P       : player
=       : direction player is looking
.       : nodes w/ active objects
| and - : borders of the active blocks
\ and / : edges of the player's FOV
```

note: if the player moves around, or looks in different directions, the active object region can change *rapidly*.

note 2: oh, we also have to deal w/ forceloaded areas...
