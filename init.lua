fmod.check_version({ year = 2023, month = 7, day = 14 }) -- async_dofile
futil.check_version({ year = 2023, month = 12, day = 9 }) -- Set:intersects
action_queues.check_version({ year = 2023, month = 7, day = 17 }) -- namespace change
afk_api.check_version({ year = 2023, month = 8, day = 7 }) -- get_afk_players

spawnit = fmod.create()

spawnit.enabled = spawnit.settings.enabled_on_boot

spawnit.dofile("util")
spawnit.dofile("stats")

spawnit.dofile("spawn_positions_class")

spawnit.dofile("data")
spawnit.dofile("manage_ao_blocks")
spawnit.dofile("manage_forceload")
spawnit.dofile("manage_spawn_positions")
spawnit.dofile("relevant_players")
spawnit.dofile("mob_counter")
spawnit.dofile("register")
spawnit.dofile("spawn_mobs")

spawnit.dofile("compat", "init")

spawnit.async_dofile("async_env")

spawnit.dofile("debugging")
spawnit.dofile("hud")
