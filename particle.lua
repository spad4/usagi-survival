

Particle = {
    
    -- universal variables, not from data driven
    x = 0, -- position in world
    y = nil, -- position in world
    born = nil, -- timestamp this particle was created 

    -- Data-driven variables from particles.json
    id = nil,
    duration = nil,
    components = nil,
}

local function compute(expression, age)
    
    local c, err = load("return function (age) return " .. expression .. " end", "expression", "t")
    if not c then return 0 end
    
    local ok, func = pcall(c)
    if not ok then return 0 end

    return func(age)
end

function Particle:draw(x, y)

    local age = usagi.elapsed - self.born

    for _, component in pairs(self.components) do
        
        local dx = compute(component.dx, age)
        local dy = compute(component.dy, age)

        if component.type == "text" then
            local text = compute(component.text, age)
            local alpha = 1
            if component.fade then
                alpha = 1 - age / self.duration
            end
            if component.shadow then 
                gfx.text_ex(tostring(text), x + dx + 1, y + dy + 1, 1, 0, gfx.COLOR_DARK_GRAY, alpha)
            end
            gfx.text_ex(tostring(text), x + dx, y + dy, 1, 0, gfx["COLOR_" .. component.color], alpha)
        end

    end

end

return Particle
