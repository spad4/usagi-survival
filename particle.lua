Particle = {

    -- universal variables, not from data driven
    x = 0,      -- position in world
    y = nil,    -- position in world
    born = nil, -- timestamp this particle was created

    -- Data-driven variables from particles.json
    id = nil,
    duration = nil,
    components = nil,
}

function Particle:compute(expression)
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

function Particle:draw()
    local pos = Pos_To_Screen({ x = self.x, y = self.y })
    if (pos.x_from_camera < 1 or pos.x_from_camera > CAMERA_SIZE_X + 1 or pos.y_from_camera < 1 and pos.y_from_camera > CAMERA_SIZE_Y) then return end

    local x, y = pos.x, pos.y

    local dx = self:compute(self.dx)
    local dy = self:compute(self.dy)
    local color = gfx["COLOR_" .. self:compute(self.color)]

    if self.type == "text" then
        local text = self:compute(self.text)
        local alpha = 1
        if self.alpha then
            alpha = self:compute(self.alpha)
        end
        if self.shadow then
            gfx.text_ex(tostring(text), x + dx + 1, y + dy + 1, 1, 0, gfx.COLOR_DARK_GRAY, alpha)
        end
        gfx.text_ex(tostring(text), x + dx, y + dy, 1, 0, color, alpha)
    elseif self.type == "circle" then
        local radius = self:compute(self.radius)
        
        if self.outline then
            local outline = self:compute(self.outline)
            gfx.circ_ex(x + dx, y + dy, radius, outline, color)
        else
            gfx.circ_fill(x + dx, y + dy, radius, color)
        end
    elseif self.type == "triangle" then

        local size = self:compute(self.size)
        local offset = 0
        if self.dr then
            offset = self:compute(self.dr)
        end

        x += dx
        y += dy

        local x1, y1 = x + math.sin(math.pi * (offset + 1/3)) * size, y + math.cos(math.pi * (offset + 1/3)) * size 
        local x2, y2 = x + math.sin(math.pi * (offset + 1)) * size, y + math.cos(math.pi * (offset + 1)) * size
        local x3, y3 = x + math.sin(math.pi * (offset + 5/3)) * size, y + math.cos(math.pi * (offset + 5/3)) * size

        if self.hollow then
            gfx.tri(x1, y1, x2, y2, x3, y3, color)
        else
            gfx.tri_fill(x1, y1, x2, y2, x3, y3, color)
        end
    end
end
