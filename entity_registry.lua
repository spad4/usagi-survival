require("entity")

local load_entities = usagi.read_json("entities.json")

local ENTITIES = {}

for _, entity in pairs(load_entities) do
    ENTITIES["NEW_" .. entity.id] = function (x, y) 
        local new_entity = {
            ["x"] = x,
            ["y"] = y,
            ["animation_start"] = usagi.elapsed
        }
        setmetatable(new_entity, {__index = Entity})
        Entity.__index = Entity
        new_entity["id"] = entity.id
        for k,v in pairs(entity.properties) do
            new_entity[k] = v
        end
        for k,v in pairs(entity.persistent) do
            new_entity[k] = v
        end
        return new_entity
    end

    ENTITIES["PROP_" .. entity.id] = function ()
        local props = {}
        for k,v in pairs(entity.properties) do
            props[k] = v
        end
        return props
    end
end

return ENTITIES
