local ENTITIES = usagi.read_json("entities.json")

local to_return = {}

for _, entity in pairs(ENTITIES) do
    to_return["NEW_" .. entity.id] = function (x, y) 
        local new_entity = {
            ["x"] = x,
            ["y"] = y
        }
        new_entity["id"] = entity.id
        for k,v in pairs(entity.properties) do
            new_entity[k] = v
        end
        for k,v in pairs(entity.persistent) do
            new_entity[k] = v
        end
        return new_entity
    end

    to_return["PROP_" .. entity.id] = function ()
        local props = {}
        for k,v in pairs(entity.properties) do
            props[k] = v
        end
        return props
    end

end

to_return.damage = function (entity, amount) 
    if entity.current_health and entity.max_health then
        entity.current_health = util.clamp(entity.current_health - amount, 0, entity.max_health)
    end
end

to_return.heal = function (entity, amount) 
    if entity.current_health and entity.max_health then
        entity.current_health = util.clamp(entity.current_health + amount, 0, entity.max_health)
    end
end

return to_return
