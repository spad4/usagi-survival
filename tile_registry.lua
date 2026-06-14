local read = usagi.read_json("tiles.json")

TILES = {}
local priority = {}

for i, tile in ipairs(read) do
    TILES[tile.id] = tile
    priority[tile.priority] = tile.id
    print(priority[3])
end

local display_to_sprite_index = { 6, 7, 10, 9, 2, 11, 4, 15, 5, 14, 1, 8, 3, 0, 13, 12 }

function Draw_Tiles()
    -- world tilemap offset based on camera position
    -- for row = 1, CAMERA_SIZE_Y do
    --     for col = 1, CAMERA_SIZE_X do
    --         local tile = State.world[row + Camera.origin_y][col + Camera.origin_x].tile
    --         setmetatable(tile, { __index = Tile })
    --         if tile ~= 0 then
    --             local x = (col - 2 - Camera.frac_x) * TILE_SIZE;
    --             local y = (row - 2 - Camera.frac_y) * TILE_SIZE;
    --             tile:draw(x, y)
    --         end
    --     end
    -- end

    for row = 1, CAMERA_SIZE_Y + 1 do
        for col = 1, CAMERA_SIZE_X + 1 do
            for k, v in pairs(priority) do
                local display_tile = TileDisplayGrids[v][row + Camera.origin_y][col + Camera.origin_x]
                local converted = display_to_sprite_index[display_tile + 1]
                if display_tile ~= 15 then
                    local x = (col - 2 - Camera.frac_x) * TILE_SIZE - 8;
                    local y = (row - 2 - Camera.frac_y) * TILE_SIZE - 8;
                    local sprite_x = TILES[v].sprite_x
                    local sprite_y = TILES[v].sprite_y
                    sprite_x += (converted % 4) * TILE_SIZE
                    sprite_y += math.floor(converted / 4) * TILE_SIZE
                    gfx.sspr(sprite_x, sprite_y, TILE_SIZE, TILE_SIZE, x, y)
                end
            end
        end
    end
end
