require("particle")

local load_particles = usagi.read_json("particles.json")

PARTICLES = {}

-- this is the runtime table of active particles
local particles = {}

for _, particle in pairs(load_particles) do
    PARTICLES["NEW_" .. particle.id] = function(x, y, vars)
        local new_particle = { x = x, y = y, born = usagi.elapsed }
        setmetatable(new_particle, { __index = Particle })
        Particle.__index = Particle
        new_particle["id"] = particle.id
        for k, v in pairs(particle) do
            new_particle[k] = v
        end
        if vars then
            for k, v in pairs(vars) do
                new_particle[k] = v
            end    
        end
        new_particle.random_1 = math.random()
        new_particle.random_2 = math.random()
        new_particle.random_3 = math.random()
        new_particle.random_4 = math.random()
        table.insert(particles, new_particle)
    end
end

function Draw_Particles()
    for i = #particles, 1, -1 do
        local particle = particles[i]
        setmetatable(particle, { __index = Particle })
        if usagi.elapsed - particle.born > particle.duration then
            table.remove(particles, i)
        else
            particle:draw()
        end
    end
end
