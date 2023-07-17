fmod.check_version({ year = 2023, month = 7, day = 14 }) -- async_dofile
futil.check_version({ year = 2023, month = 7, day = 14 })
action_queues.check_version({ year = 2023, month = 7, day = 17 }) -- namespace change

spawnit = fmod.create()

spawnit.dofile("util")
spawnit.dofile("stats")

spawnit.dofile("block_class")
spawnit.dofile("spawn_positions_class")

spawnit.dofile("manage_ao_blocks")
spawnit.dofile("manage_forceload")
spawnit.dofile("manage_spawn_positions")
spawnit.dofile("mob_counter")
spawnit.dofile("register")
spawnit.dofile("spawn_mobs")

spawnit.dofile("hud")

spawnit.async_dofile("async_env")
