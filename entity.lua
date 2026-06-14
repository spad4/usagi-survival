Entity = {
    -- Global Properties
    -- These are properties that are universal to every Entity. Do not include in entities.json
    -- Not refreshed on live reload
    is_walking = false,
    x = 0,
    y = 0,

    -- Local Properties
    -- Properties of entities referenced in Entity.properties
    -- Refreshed on live reload
    id = nil,
    sprite = nil,
    bones = nil,
    animations = nil,
    animation_controllers = nil,
    max_health = nil,
    movement_speed = nil,

    -- Persistent Properties
    -- Properties of entities referenced in Entity.persistent
    -- These are NOT refreshed on live reload, only when save data is deleted
    current_health = nil,
}

function Entity:damage(amount)
    if self.current_health and self.max_health then
        self.current_health = util.clamp(self.current_health - amount, 0, self.max_health)
    end
end

function Entity:heal(amount)
    if self.current_health and self.max_health then
        self.current_health = util.clamp(self.current_health + amount, 0, self.max_health)
    end
end

function Entity:draw(x, y)

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
                        local c, err = load("return function (self, random, elapsed) return " .. condition .. " end", "condition", "t")
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

                -- get the current frame
                local frame = frames[frames_elapsed]
                for bone, modifier in pairs(frame) do
                    if bones[tonumber(bone)] then
                    --    bones[tonumber(bone)].sprite_index = modifiers.index
                        bone_modifiers[bone] = modifier
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
        gfx.sspr_ex(sprite_x, bone.y, bone.width, bone.height, x + offset_x, y + offset_y, bone.width, bone.height, false, false, 0, gfx.COLOR_TRUE_WHITE, 1)
    end
end

function Entity:play_animation(animation)
    local check = self.animations[animation]
    if not check then
        return
    end

    self.current_animation = animation
    self.animation_start = usagi.elapsed
end

return Entity
