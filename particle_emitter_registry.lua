require("particle")
require("particle_emitter")

local load_emitters = usagi.read_json("particle_emitters.json")

PARTICLE_EMITTERS = {}

-- this is the runtime table of active particles
local emitters = {}

for _, emitter in pairs(load_emitters) do
    PARTICLE_EMITTERS["NEW_" .. emitter.id] = function(x, y, vars)
        local new_emitter = { x = x, y = y, born = usagi.elapsed }
        setmetatable(new_emitter, { __index = Particle_Emitter })
        Particle_Emitter.__index = Particle_Emitter
        new_emitter["id"] = emitter.id
        for k, v in pairs(emitter) do
            new_emitter[k] = v
        end
        if vars then
            for k, v in pairs(vars) do
                new_emitter[k] = v
            end    
        end
        new_emitter.random_1 = math.random()
        new_emitter.random_2 = math.random()
        new_emitter.random_3 = math.random()
        new_emitter.random_4 = math.random()
        table.insert(emitters, new_emitter)
    end
end

function Run_Emitters()
    for i = #emitters, 1, -1 do
        local emitter = emitters[i]
        setmetatable(emitter, { __index = Particle_Emitter })
        local age = usagi.elapsed - emitter.born 
        if age > emitter.duration then
            table.remove(emitters, i)
        else
            local emit_count = math.floor(age / emitter.frequency)
            if emitter.last_emit ~= emit_count then
                emitter:emit()
                emitter.last_emit = emit_count
            end
        end
    end
end
