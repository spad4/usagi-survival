require("particle")
require("particle_registry")

Particle_Emitter = {

    -- universal variables, not from data driven
    x = 0,      -- position in world
    y = nil,    -- position in world
    born = nil, -- timestamp this particle was created

    -- Data-driven variables from particles.json
    id = nil,
    duration = nil,
    frequency = nil,
    particles = nil
}

function Particle_Emitter:compute(expression)
    if type(expression) ~= "string" then
        return expression
    end
    local c, err = load("return function (self) return " .. expression .. " end", "expression", "t")
    if not c then return 0 end

    local ok, func = pcall(c)
    if not ok then return 0 end

    self.age = usagi.elapsed - self.born
    return func(self)
end

function Particle_Emitter:emit()

    local pos = Pos_To_Screen({ x = self.x, y = self.y })
    if (pos.x_from_camera < 1 or pos.x_from_camera > CAMERA_SIZE_X + 1 or pos.y_from_camera < 1 and pos.y_from_camera > CAMERA_SIZE_Y) then return end
    local x, y = pos.x, pos.y

    for _, particle in pairs(self.particles) do
        for i = 1, particle.count do
            local dx = 0
            local dy = 0
            if not particle.outline then
                dx = math.random() * particle.x_spread - particle.x_spread * 0.5
                dy = math.random() * particle.y_spread - particle.y_spread * 0.5
            else
                if math.random() > 0.5 then
                    dx = math.random(0, 1) * particle.x_spread - particle.x_spread * 0.5
                    dy = math.random() * particle.y_spread - particle.y_spread * 0.5
                else
                    dx = math.random() * particle.x_spread - particle.x_spread * 0.5
                    dy = math.random(0, 1) * particle.y_spread - particle.y_spread * 0.5
                end
            end
            PARTICLES["NEW_"..particle.id](self.x + dx, self.y + dy, particle.vars)
        end
    end
end
