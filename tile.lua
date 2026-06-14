Tile = {

    -- universal variables, not from data driven
    x = 0,      -- position in world
    y = nil,    -- position in world

    -- Data-driven variables from particles.json
    id = nil,
    sprite = nil,
    map_color = nil,
    duration = nil,
    speed_modifier = nil
}

-- function Tile:draw(x, y)
    
--     if self.autotile then
        
--     else
--         gfx.spr(self.sprite, x, y)
--     end
-- end