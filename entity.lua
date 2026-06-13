
Entity = {
    -- Global Properties
    -- These are properties that are universal to every Entity. Do not include in entities.json
    -- Not refreshed on live reload
    is_walking = false, 
    x = 0,
    y = 0,
    current_animation = "default",
    animation_start = usagi.elapsed,

    -- Local Properties
    -- Properties of entities referenced in Entity.properties
    -- Refreshed on live reload
    id = nil,
    sprite = nil,
    max_health = nil,
    movement_speed = nil,
    animations = nil,

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

local function get_words(to_read)
    local t = {}
    for word in string.gmatch(to_read, "([^%s]+)") do
        table.insert(t, word)
    end
    return t
end

function Entity:draw()
    
    if self.animations then
        local animation = self.animations[self.current_animation]
        if not animation then
            return 0
        end

        local transition = animation.transition
        if transition then
            for k,v in pairs(transition) do
            if self.animations[k] then
                local c, err = load("return function (self) return "..v.." end", "condition", "t", self)
                if c then
                    local ok, check = pcall(c)
                    if ok then
                        if check(self) then
                            self.current_animation = k
                            animation = self.animations[k]
                            self.animation_start = usagi.elapsed
                        end
                    end
                end
            end
        end
        end

        local looping, frametime, frames = animation.looping, animation.frametime, animation.frames
        if not frametime or not frames then
            return 0
        end

        local frame_count = #frames

        local frames_elapsed = math.floor((usagi.elapsed - self.animation_start) / frametime) + 1
        if looping then
            frames_elapsed = frames_elapsed % frame_count + 1
        else
            if (frames_elapsed > frame_count) then
                frames_elapsed = frame_count
            end
        end

        return frames[frames_elapsed]
    end
    
    if self.sprite then
        return self.sprite
    end
end

function Entity:play_animation(animation)
    local check = self.animations[animation]
    if not check then
        return
    end

    self.current_animation = animation
end



return Entity