require("particle")

local load_particles = usagi.read_json("particles.json")

local to_return = {}

-- this is the runtime table of active particles
Particles = {}

for _, particle in pairs(load_particles) do
    to_return["NEW_" .. particle.id] = function (x, y) 
        local new_particle = {x = x, y = y, born = usagi.elapsed}
        setmetatable(new_particle, {__index = Particle})
        Particle.__index = Particle
        new_particle["id"] = particle.id
        for k,v in pairs(particle) do
            new_particle[k] = v
        end
        return new_particle
    end
end

function Draw_Particles()
  local offset = {
    x = math.floor(Camera.x) - CAMERA_HALF_X,
    y = math.floor(Camera.y) - CAMERA_HALF_Y
  }
  local camera_offset = {
    x = Camera.x % 1,
    y = Camera.y % 1
  }
  for i = #Particles, 1, -1 do
    local particle = Particles[i]
    setmetatable(particle, {__index = Particle})
    if usagi.elapsed - particle.born > particle.duration then
      table.remove(Particles, i)      
    else
      local x_from_camera = particle.x - offset.x
      local y_from_camera = particle.y - offset.y
      if (x_from_camera >= 1 and x_from_camera <= CAMERA_SIZE_X+1 and y_from_camera >= 1 and y_from_camera <= CAMERA_SIZE_Y) then
        local x = (x_from_camera - 2 - camera_offset.x) * TILE_SIZE;
        local y = (y_from_camera - 2 - camera_offset.y) * TILE_SIZE;
        particle:draw(x, y)
      end
    end
  end
end

return to_return
