return function (mod)

-- Lisp files already have this and other data types imported, but Lua ones
-- do not. Use them when required to interact with other code that may be in
-- Lisp (like ecs.lisp)
local list = require("l2l.list")
local len = require("leftry.utils").len
-- local utils = require("leftry").utils
-- local vector = require("l2l.vector")

-- Called from on_prepare_rules in main.lua, this proc adds resources to the
-- rules instance to make them available to the game later on.
mod.puddles_setup = function (rules)
    
    -- Reads a TexturePacker sprite sheet and loads its sprite frames into the
    -- sprite frame cache. It's mandatory for anything drawn on the iso game
    -- world to use a sprite sheet and frame names to keep save games portable
    -- and avoid draw calls
    mod_add_sprite_frames_rel(mod, "images/puddles.plist", "images/puddles.png")
    
    -- Globally registers the names "puddles.plist/.png" as a local file inside
    -- this mod. This is required since those names will end up serialized into
    -- the save file, and this way they are decoupled from the actual on-disk
    -- paths.
    mod_set_file_alias("puddles.plist", mod_rel_path(mod, "images/puddles.plist"))
    mod_set_file_alias("puddles.png", mod_rel_path(mod, "images/puddles.png"))

end


-- Example ECS system: spawn water puddles around showers

-- Any function or value that is either overriding base game code or data, or
-- that needs to participate into game systems, must be defined as global.

-- This function, station_shower_puddles_system_post_process, is the entity
-- processor for the system station_shower_puddle. It will be called from time
-- to time (see "phase" further down) and passed both the system instance (s)
-- and the entity to process (e).

-- Unlike other names this one has a specific structure, and it must always
-- end as "post_process"
station_shower_puddles_system_post_process = function (s, e)

    -- Get the current center of the entity e. This code is assuming
    -- the passed entity has a position, and it can do so by having
    -- registered with a "must" aspect of PositionComponent_Kind futher down
    local center = ecs_pos_center(e)

    -- area around where we want to perform the query.
    local area = n2d_circle(center.x, center.y, 2.0)

    -- Query the SpatialIndexSytem in the current world using the very
    -- practial ecs_query function, for nearby puddles
    local res = ecs_query{
        world = s.world, -- our current world instance peeked from s
        -- we pass a list of the components that the returned entities must have
        must = list(puddle_component, PositionComponent_Kind),
        -- if you ommit this (or rect: or similar others) it would consider
        -- the entire world
        circle = area
    }

    -- If there's not many puddles around us, then spawn one more
    if len(res) < 3 then
        -- find a nearby walkable position
        local pos = ecs_random_walkable_in_circle{world = s.world, circle = area, radius = 0.1}
        -- if we found one, spawn the puddle on it
        if pos then
            mod.make_puddle(s.world, e, pos)
        end
    end
end

-- keep the name explicit since this is a global symbol.
make_station_shower_puddles_system = function (world)

    return ecs_make_system{
        -- Make it follow the same structure as the other names
        name = "station_shower_puddles_system",
        world = world,
        
        -- Here we pass an entity aspect. Entities that match this aspect will be
        -- registered into our system and will get passed one by one to our process
        -- proc
        -- shower_component is defined in the base game. This is an example of extending
        -- a base object without any base game modification.
        aspect = ecs_aspect{
            must = list(PositionComponent_Kind, shower_component, ReadyComponent_Kind)
        },
        
        -- The entity processing phase of the system, in 0.1 of a second. This is supremely
        -- important to pick well. It indicates how much time will pass between calls to the
        -- process proc for the same entity. It's absurd for most code to be called at 1:1
        -- frame cadence. You don't need to check for nearby water puddles at 60hz. It's in
        -- this realization that the sim is capable of emulating a lot complex systems for
        -- many entities and not burn the CPU down too early.
        -- In this case it will be a wait of 30s for each entity.
        -- This wait is per-instance. Each instance will only be processed once every 30s,
        -- but the system can and will be active at every frame to process due instances.
        -- The processing order is randomized.
        phase = 300,
        
        -- And finally we register the process method. Pass a list of one string that is
        -- the same you named your process proc.
        hooks = list("station_shower_puddles_system_post_process")
    }
end

-- A system maker needs to be globally registered in order to be called when creating
-- a new world, be a planet, station or ship bridge.
-- Here we use "station_systems" but "planet_systems" and "bridge_systems" are also
-- available. There's also "general_systems" for making it available everywhere.
-- Showers are only vailable in the station, so we use "station_systems".
station_systems["make_station_shower_puddles_system"] = make_station_shower_puddles_system


-- Example ECS system: water puddles

-- Registering new components is just declaring a global value with the hash of
-- the string name of the component. Components declared in pure Lua/Lisp have no
-- declared structure, they are integer values for all purposes.
puddle_component = bridge_hash("puddle_component")
sliding_component = bridge_hash("sliding_component")

local puddle_frames = {
    "puddles-puddle01.png",
    "puddles-puddle02.png",
    "puddles-puddle03.png",
}

-- An internal proc to spawn a water puddle
mod.make_puddle = function (world, parent, pos)

    -- create a new, empty entity
    local e = ecs_make_entity(world)

    -- add a new component: a position component with a circular shape
    local posc = ecs_make_position_circle(n2d_circle(pos.x, pos.y, 0.2))
    ecs_add_component(e, posc)

    -- warp our position component into the right position immediately
    posc:warpCenter(pos.x, pos.y)

    -- add a new component: a self destroy component
    ecs_make_add_component(e, SelfDestroyComponent_Kind,
        -- set up our suicide time in the SelfDestroyComponent. time units are
        -- always 0.1s, and time moments are relative to the start of the game,
        -- here read using world:getTicks
        "dieByTick", world:getTicks() + bridge_random_i(600, 1200))

    -- add a new component: use the helper make_SimplePoseComponent to
    -- create a SimplePoseComponent for a simple, 1-frame with no angles
    -- display
    local spc = make_SimplePoseComponent{
        -- only aliases are allowed here
        plist_alias = "puddles.plist",
        image_alias = "puddles.png",
        -- anchor point, in 0 to 1 coordinates
        ax = 0.5, ay = 0.5,
        frames = list(puddle_frames[bridge_random_i(1, 4)])
    }
    -- force a display Z value just above the floor one, so everything is painted
    -- on top of the puddle but not the floor. The default is a proper Z value
    -- depending on the X-Y position for proper iso overlapping.
    spc.layer.isForceZ = true
    spc.layer.forceZ = -192.0
    ecs_add_component(e, spc)

    -- use the component we declared earlier to mark this as a water puddle, so
    -- we can match its aspect later on
    ecs_make_add_component(e, puddle_component)

    -- this makes the puddle a piece of dirt, which means it will be automatically
    -- considered by entities with the cleaner job to be cleaned away. not bad for
    -- one line of code
    ecs_make_add_component(e, dirt_component)

    -- return the entity in case the caller has further plans for it
    return e
end

-- Here we encounter the busy system for the first time. How do you coordinate many
-- different systems, all wanting the entity to behave in certain ways that could
-- be mutually incompatible, without massively coupling everything with everything
-- else?

-- Attempt 1: "I'm the hunger system and I want to make this hungry entity go have a
-- piece of pie, but it is currently running away from a pirate on fire, so yeah
-- I'm not going to disturb it. But this other one is just contemplating a flower,
-- so I'm going forward and make it start walking to the canteen." 
-- This is utter madness. Now every system must know about every other one all the
-- time, and know which are more important and less important. Discarded.

-- Attempt 2: "I'm the hunger system and I want to make this hungry entity go have a
-- piece of pie, but it has a flag on it. It says BUSY. I won't touch it until the
-- flag is gone, then I will put the flag on it again myself, knowing it's mine now."
-- Much better! The coupling is gone! But what if it was busy doing something
-- trivial, and it really wanted that pie? We can do better.

-- Attempt 3: "I'm the hunger system and I want to make this hungry entity go have a
-- piece of pie, but it has a flag on it. It says BUSY 100. It means it's busy, and
-- its task has a priority value of 100 (just a number, no meaning). Me, the hunger
-- system, happens to have a priority value of 20, so I will leave it alone. But
-- this other one has a BUSY 10. So I will remove its flag and put mine on it,
-- which says BUSY 20. It's mine now"
-- And finally we get to a solution. That's more or less how the busy system works.
-- Note how there's a protocol on how to get control over an entity without any
-- knowledge beyond a number. The flip side is that systems must be prepared to
-- lose control of their entities at any time, and handle it well.

-- Set variables with our busy system name (this is a bit informal, that's why it's
-- called a hint) and the prio value as described earlier. Pick a prio value by
-- looking at the core code.
-- Idle walking is 2, low prio jobs are 9, normal jobs are 10, vital needs are
-- 20, attacking is 100, fleeing in panic is 200. We pick 300 because it
-- could be hilarious to see an entity fleeing in panic and slip on a water
-- puddle
slide_busy_owner_hint = bridge_hash("slide_system")
slide_busy_priority = 300

-- The entity processor for the puddle system
station_puddle_system_post_process = function (s, e)

    local center = ecs_pos_center(e)

    -- Get all the pontentially slide-able entities on top of us.
    -- We model this as anything with PhysicsComponent, which means
    -- it can move
    local res = ecs_query{
        world = s.world,
        must = list(PositionComponent_Kind, PhysicsComponent_Kind),
        -- don't match already sliding entities
        exclude = list(sliding_component),
        circle = n2d_circle(center.x, center.y, 0.2)
    }

    -- for each entity of the previous query
    for _,matched in ipairs(res) do
        -- check if it's doing something more important than walking on water
        local can_busy = is_ecs_can_become_busy(
            matched,
            slide_busy_priority,
            slide_busy_owner_hint)
        -- and make sure it's not stopped, since that would be strange
        local posc = ecs_get_component(matched, PhysicsComponent_Kind)
        local is_stopped = posc:isPracticallyStopped()
        if can_busy and not is_stopped then
            -- our predicates hold, so mark it busy with our priority and hint
            ecs_make_busy{
                e = matched,
                priority = slide_busy_priority,
                ownerHint = slide_busy_owner_hint,
                description = _L("sliding_desc", "Sliding, weeeee!")
            }
            -- remove any pathing it currently had
            ecs_remove_component(matched, PathComponent_Kind)
            -- and add the component for the system that will handle the actual sliding
            ecs_make_add_component(matched, sliding_component)
        end
    end
end

-- just as before, we register our system. We pick a smaller phase this time. Small enough to
-- miss most entities walking on top of us, not too small so it never happens
make_station_puddle_system = function (world)
    return ecs_make_system{
        name = "station_puddle_system",
        world = world,
        aspect = ecs_aspect{
            must = list(PositionComponent_Kind, puddle_component)
        },
        phase = 35,
        hooks = list("station_puddle_system_post_process")
    }
end
station_systems["make_station_puddle_system"] = make_station_puddle_system

-- Example ECS system: sliding from a water puddle

-- This is the processor for entities currently sliding from a water puddle.
station_sliding_system_post_process = function (s, e)

    local phy = ecs_get_component(e, PhysicsComponent_Kind)

    -- first of all, is the entity actually busy with us?
    -- remember the busy system allows other systems take over
    -- when required, so we must check this every time and
    -- clean up if needed
    if is_ecs_busy_with_owner(e, slide_busy_owner_hint) then

        -- it was busy with us. now, did it stop (aka slammed into something?)
        if phy:isPracticallyStopped() then
            
            -- it did stop, so clean up. remove our component and the busy component,
            -- fix the pose
            ecs_remove_component(e, sliding_component)
            ecs_remove_component(e, BusyComponent_Kind)
            ecs_pose{e = e, name = "action", state = false}
        else

            -- it's still moving, so keep it moving in the "right" way.
            -- keep it headed in its current direction, but set a nice
            -- speed to it
            phy:setSpeedWithCurrentHeading(4.0)
            -- if it's a posed entity, activate the "action" pose so
            -- it's flailing its arms at nothing :)
            ecs_pose{e = e, name = "action", state = true}
        end

    else
        -- not busy with us, so remove ourselves from it
        ecs_remove_component(e, sliding_component)
    end
end

-- This time the phase is very small. Never pick such a low phase unless you have good
-- reasons. In this case very few entities will be sliding around at any given moment,
-- so it's okay to put a 10 here. For reference most jobs and vitals are 20 to 40
make_station_sliding_system = function (world)
    return ecs_make_system{
        name = "station_sliding_system",
        world = world,
        aspect = ecs_aspect{
            must = list(PositionComponent_Kind, sliding_component)
        },
        phase = 10,
        hooks = list("station_sliding_system_post_process")
    }
end
station_systems["make_station_sliding_system"] = make_station_sliding_system

end
