futil.check_version({ year = 2023, month = 7, day = 12 })

spawnit = fmod.create()

minetest.register_async_dofile(spawnit.modpath .. DIR_DELIM .. "async_env.lua")
