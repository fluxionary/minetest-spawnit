the "active object volume" - where active objects can exist - is the union of the the active blocks around a
player (27 of them) plus a [solid angle](https://en.wikipedia.org/wiki/Solid_angle) around the player's
"look direction", bound by the player's FOV and `active_object_send_range_blocks`. w/ the latter set to 5
(what we've got), this works out to approximately 150 mapblocks, though clearly it'll include a lot of
partial mapblocks and not just whole ones.
