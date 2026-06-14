Entity = {
    -- Global Properties
    -- These are properties that are universal to every Entity. Do not include in entities.json
    -- Not refreshed on live reload
    x = 0,             -- world x
    y = 0,             -- world y
    is_moving = false, -- whether or not the entity is moving of its own accord
    facing = 0,        -- direction the entity is facing, use DIRECTIONS
    last_damage = 0,

    -- Local Properties
    -- Properties of entities referenced in Entity.properties
    -- Refreshed on live reload
    id = nil,                    -- id of the entity. the only required property
    sprite = nil,                -- simple sprite to use
    bones = nil,                 -- a list of bones for a complex sprite
    animations = nil,            -- a list of modifiers for bones over time
    animation_controllers = nil, -- a list of state machines to control which animations are playing
    max_health = nil,
    movement_speed = nil,
    rotates = nil, -- whether or not this entity has different sprites for the direction it's facing

    -- Persistent Properties
    -- Properties of entities referenced in Entity.persistent
    -- These are NOT refreshed on live reload, only when save data is deleted
    current_health = nil,
}

-- used to determine which set of sprites to use for entities that rotate
DIRECTIONS = {
    DOWN = 0,
    UP = 1,
    RIGHT = 2,
    LEFT = 3
}

function Entity:damage(amount)
    if self.current_health and self.max_health then
        local old = self.current_health
        self.current_health = util.clamp(self.current_health - amount, 0, self.max_health)
        PARTICLES.NEW_DAMAGE_NUMBER(self.x, self.y, {amount = old - self.current_health})
        if old - self.current_health > 0 then
            self.last_damage = usagi.elapsed
        end
    end
end

function Entity:heal(amount)
    if self.current_health and self.max_health then
        local old = self.current_health
        self.current_health = util.clamp(self.current_health + amount, 0, self.max_health)
        PARTICLES.NEW_HEAL_NUMBER(self.x, self.y, {amount = self.current_health - old})
    end
end

function Entity:draw()
    local pos = Pos_To_Screen({ x = self.x, y = self.y })
    if (pos.x_from_camera < 1 or pos.x_from_camera > CAMERA_SIZE_X + 1 or pos.y_from_camera < 1 and pos.y_from_camera > CAMERA_SIZE_Y) then return end

    local x, y = pos.x, pos.y

    -- any entity with a simple sprite
    if self.sprite then
        gfx.spr(self.sprite, x, y + 8)
        return
    end

    -- any entity with a model (has animations, multiple bones, etc)
    local bones, animations, controllers = self.bones, self.animations, self.animation_controllers
    if not bones or not animations or not controllers then return end

    local bone_modifiers = {}

    if controllers then
        for _, controller in pairs(controllers) do
            local state = controller.state;
            local transitions = controller[state].transitions

            -- go through each transition in controller and check if they apply
            if transitions then
                -- if that animation exists and the condition is fulfilled
                -- set the current state of the controller to that transition's name
                for name, condition in pairs(transitions) do
                    if controller[name] then
                        local random = math.random()
                        local c, err = load("return function (self, random, elapsed) return " .. condition .. " end",
                            "condition", "t")
                        if c then
                            local ok, check = pcall(c)
                            if ok and check(self, random, usagi.elapsed - controller.last_transition) then
                                controller.state = name
                                controller.last_transition = usagi.elapsed
                            end
                        end
                    end
                end
            end

            -- get the list of animations the current controller is applying
            for _, name in ipairs(controller[controller.state].animations) do
                local animation = animations[name]
                if not animation then return end

                local looping, frametime, frames = animation.looping, animation.frametime, animation.frames
                if not frametime or not frames then return end

                local frame_count = #frames
                local frames_elapsed = math.floor((usagi.elapsed - controller.last_transition) / frametime) + 1

                if looping then
                    frames_elapsed = frames_elapsed % frame_count + 1
                else
                    if (frames_elapsed > frame_count) then
                        frames_elapsed = frame_count
                    end
                end

                -- is this a terrible solution? i have no clue.. ..probably..
                -- this might not be specific to each entity? we'll see i guess
                local frame_changed = false
                local last = animation.last_frame or 0
                if frames_elapsed ~= last then
                    frame_changed = true
                    animation.last_frame = frames_elapsed
                end

                -- get the current frame
                local frame = frames[frames_elapsed]
                for bone, modifier in pairs(frame) do
                    if bones[tonumber(bone)] then
                        bone_modifiers[bone] = modifier
                        if modifier.particles and frame_changed then
                            for _, particle in pairs(modifier.particles) do
                                local offset_x = (modifier.offset_x or 0) / TILE_SIZE
                                local offset_y = (modifier.offset_y or 0) / TILE_SIZE
                                PARTICLES["NEW_" .. particle](Player.x + offset_x, Player.y + offset_y)
                            end
                        end
                    end
                end
            end
        end
    end

    -- draw a sprite for each bone of the entity
    for i, bone in pairs(bones) do
        -- find the top left corner for the start of the current sprite

        local modifier = bone_modifiers[tostring(i)]

        local sprite_index = bone.sprite_index
        local offset_x = bone.offset_x
        local offset_y = bone.offset_y
        if modifier then
            sprite_index = modifier.index or sprite_index
            if modifier.offset_x then
                offset_x += modifier.offset_x
            end
            if modifier.offset_y then
                offset_y += modifier.offset_y
            end
        end

        local sprite_x = bone.x + (sprite_index - 1) * bone.width
        local sprite_y = bone.y
        local flip = false
        if self.rotates then
            local facing = self.facing
            if facing == 3 then
                flip = true
                facing = 2
            end
            sprite_y += bone.height * facing
        end

        local tint = gfx.COLOR_TRUE_WHITE

        if usagi.elapsed - self.last_damage < 0.25 then
            tint = gfx.COLOR_PEACH
        end

        gfx.sspr_ex(sprite_x, sprite_y, bone.width, bone.height, x + offset_x, y + offset_y, bone.width, bone.height,
            flip, false, 0, tint, 1)
    end
end
