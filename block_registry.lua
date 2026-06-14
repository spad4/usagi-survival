BLOCKS = usagi.read_json("blocks.json")

for i,tile in ipairs(BLOCKS) do
    BLOCKS[tile.id] = i
end