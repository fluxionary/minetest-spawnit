mob farms are necessary - some players absolutely expect the functionality. however, mob farms pose a major challenge
to a server operator, in terms of balancing.

is there a way to create a mod spawning API that will make both kinds happy?

imo allowing passive mob farms is the default position - it's what happens if you don't add features to prevent it.

ABMs: trivial passive mob farm - set up a death trap, vacuum tubes, and AFK nearby
LBMs: trivial active mob farm - just keep running
globalsteps: trivial passive mob farm, for more-or-less the same reason as ABMs.

how to mitigate these:

ABMs: disable spawning near an AFK player. abm still has to run `get_objects_inside_radius` or such, whether or not
      the spawning succeeds.
LBMs: create a time limit per-player, per-mob, and dis-allow new spawns of that mob near that player. the LBM will
      still be run on many blocks whenever players are moving around. the LBM will also need to run
      `get_objects_inside_radius` cuz there's no data about which player or players triggered a block to load.
globalsteps:
      assume what i'm trying to do here - pre-compute spawn locations and update them gradually, which allows for a
      very quick way of picking a place to spawn mobs. but is there a reasonable way to prevent mob farms somehow with
      this setup?

      idea: prevent mobs from spawning at the same location twice. eventually, the player would have to move to another
            location, wait for the region to be expired, and go back. this probably would allow you to set up 2 mob
            farms and toggle AFK-ing between them.
