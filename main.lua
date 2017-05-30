-- main.lua is the only hardcoded file name that will be loaded by the game.
-- Every other file must be referenced in some way by your code.

-- Both Lua and l2l Lisp files are wrapped inside a function, to keep a private
-- enviroment and to be able to pass them a "mod" table. This table is passed so
-- files inside a mod can share private data and functions.
return function (mod)

    -- Unlike standaline Lua, in-game mods and Lua files are loaded explicitly.
    -- Lua require() is not supported.
    -- The path for include_lua and include_lisp is always relative to the root
    -- of the mod.
    include_lua(mod, "puddles.lua")

    -- The game has a few entry points into your mod outside of the ECS engine. They
    -- follow the lifetime of the UI and games, and all of them are optional.
    -- on_prepare_rules is the right place to register your ECS systems and load
    -- graphical resources.

    -- on_prepare_rules is called after the user either starts a new game, or loads
    -- an existing game, but before any game data has been initialized or loaded.
    -- Its purpose is to set up the "game rules": code and data that don't depend
    -- on a particular game instance. For example: loading images, setting file
    -- aliases, registery systems in the ECS engine, etc. The rule is that none of
    -- that data must ever end up inside a save game file. The global game returns nil
    -- while this proc is called. rules is the future game.rules instance and
    -- it can be ignored unless you are modifying core C++ data (see
    -- core/system/resources.lua in the main game for an example).
    mod.on_prepare_rules = function (rules)
        mod.puddles_setup(rules)
    end

    -- on_new_game is called when the user starts a new game from scratch. At the
    -- point of its call the C++ and Lua core initialization of the game is done.
    -- Global game is valid at this point. The GUI is not.
    mod.on_new_game = function ()
    end

    -- on_gui_ready is called after either a new game or a loaded game is done
    -- loading, and the GUI is in a valid state
    mod.on_gui_ready = function ()
    end

    -- on_landed_planet is called just after landing on a planet
    mod.on_landed_planet = function (body)
    end

    -- on_takeoff_planet is called just before taking off from a planet
    mod.on_takeoff_planet = function (body)
    end
end
