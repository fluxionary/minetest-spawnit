spawn parameters are registered. there can be multiple spawn parameters for the same mob, these will be evaluated
independently, though they may interact by e.g. limits on the # of active mobs in some location (or the whole server).

cast a light: from a given set of spawn parameters, we want to quickly pick a position where the mob can spawn. in order
to do that, we need to pre-compute and cache spawn positions. given those positions, we can just pick one at random.

we will need a pipeline to build this dataset and update it as necessary. the building and updates will be done
*gradually*, so as not to cause large lag spikes even under adverse conditions. (probably, actual load-balancing
would be appropriate, but that's put off until a later revision).

== the primary pipeline ==

first, we track which areas are active w.r.t objects. this consists of a set of per-player mapblocks, and some
additional mapblocks which are force-loaded. for the purpose of this discussion, i'll just call these active
blocks (note: that means something different to minetest itself). we track a set of blocks around each player -
the same block might be associated w/ multiple players. we also track the "global" loaded status - is this block loaded
by *any* player? ultimately, this is what we care about whether we should spawn a mob in a specific mapblock.

from this data, we gradually build a collection of positions where mobs can spawn. as the active positions change, these
are deactivated, and eventually removed from the cache entirely (based on distance from players or time since active).

then, for each mob, after some interval, if certain conditions are met, we add one (or more) of the mobs to the world.

== the update pipeline ==

active blocks change a *lot*, as players move around and look in different directions, so we need to re-calculate our
data about which blocks are now active and which are not, remove cached blocks which are too far away from the player,
and then trigger any necessary updates to the stored spawn positions.

updates to a block as reported by the engine will also trigger the removal of cached blocks.

= TODO =

track timestamps for updated blocks? we can use a 5.7.0 callback (`register_on_mapblocks_changed`) to remove spawn
positions.
