TILES = usagi.read_json("tiles.json")

for i,tile in ipairs(TILES) do
    TILES[tile.id] = i
end

return TILES