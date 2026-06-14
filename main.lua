-- Save/load demo: data that persists across runs.
--
--   usagi.save(t)  -- writes a Lua table as JSON to a per-game file
--   usagi.load()   -- returns the table, or nil if there's no save yet
--
-- `game_id` (reverse-DNS) namespaces the save so it doesn't clobber
-- saves from other usagi games on the same machine. Required for
-- save / load. Convention matches Playdate bundle IDs and macOS /
-- iOS app bundle identifiers, so the same string is reusable when
-- packaging targets land in future versions.
--
-- Saves live at:
--   linux  : ~/.local/share/com.usagi.savedemo/save.json
--   macos  : ~/Library/Application Support/com.usagi.savedemo/save.json
--   windows: %APPDATA%\com.usagi.savedemo\save.json
--   web    : window.localStorage, key "usagi.save.com.usagi.savedemo"

require("noise")
require("entity")
require("particle")
ENTITIES = require("entity_registry")
PARTICLES = require("particle_registry")
TILES = require("tile_registry")

WORLD_SIZE_X = 320 -- in tiles
WORLD_SIZE_Y = 180

WORLD_CENTER = {
  x = WORLD_SIZE_X / 2,
  y = WORLD_SIZE_Y / 2
}

MAX_DISTANCE_FROM_CENTER = math.sqrt(2) / 2

-- default: 22x14
-- this extends outside of the game window so that player movement doesn't expose edges
CAMERA_SIZE_X = 22 -- in tiles
CAMERA_SIZE_Y = 14
CAMERA_HALF_X = math.floor(CAMERA_SIZE_X / 2)
CAMERA_HALF_Y = math.floor(CAMERA_SIZE_Y / 2)

TILE_SIZE = 16 -- in pixels

function _config()
  return { name = "Survive Test", game_id = "com.spad4.survive" }
end

---Draws text at (x, y) in the given color. Uses the bundled monogram
---font at its 16px design size (a 5×7 pixel font with 16px line height).
---@param text  string  string to render
---@param x     number  left edge in game-space pixels
---@param y     number  top edge in game-space pixels
---@param color integer  a gfx.COLOR_* constant
local function text_with_shadow(text, x, y, color)
  gfx.text(text, x + 1, y + 1, gfx.COLOR_DARK_GRAY)
  gfx.text(text, x, y, color)
end

local function new_world()
  local to_return = {}
  for row = 1, WORLD_SIZE_Y do
    to_return[row] = {}
    for col = 1, WORLD_SIZE_X do
      -- State.world[row][col] = 1
      to_return[row][col] = math.floor(math.random() * #TILES + 1)
    end
  end
  return to_return
end

local function new_noise_world()
  perlin:shuffle()
  local to_return = {}
  for row = 1, WORLD_SIZE_Y do
    to_return[row] = {}
    for col = 1, WORLD_SIZE_X do
      -- State.world[row][col] = 1
      local distance = util.vec_dist({ x = col / WORLD_SIZE_X, y = row / WORLD_SIZE_Y }, { x = 0.5, y = 0.5 }) /
      MAX_DISTANCE_FROM_CENTER
      local n = perlin:noise(col / 60, row / 60, 1)
      n -= 0.4 - distance

      local tile = TILES.WATER

      if n < 0 then
        tile = TILES.GRASS
      elseif n < 0.1 then
        tile = TILES.SAND
      end


      to_return[row][col] = tile
    end
  end
  return to_return
end

local function fresh_state()
  local to_return = {
    world = {},
    current_tile = 1,
    entities = {
      [1] = ENTITIES.NEW_PLAYER(100, 100)
    }
  }

  to_return.world = new_noise_world()

  return to_return
end

local function update_entity_props(state)
  if not state then
    return
  end
  for i, entity in pairs(state.entities) do
    local id = entity.id
    local props = ENTITIES["PROP_" .. id]()
    for k, v in pairs(props) do
      entity[k] = v
    end
  end
end

local function load_state()
  local to_return = usagi.load()

  -- something was saved; all entities need to have their properties updated
  if (to_return) then
    if #to_return.world ~= WORLD_SIZE_Y or #to_return.world[1] ~= WORLD_SIZE_X then
      return fresh_state()
    end
    update_entity_props(to_return)
    return to_return
  else
    return fresh_state()
  end
end

function _init()
  State = load_state()
  -- State = fresh_state()
  RenderUI = true
  DebugOverlay = false
  Player = State.entities[1]
  Camera = {
    x = Player.x,
    y = Player.y
  }
  perlin:load()
end

update_entity_props(State)

function _update(dt)

  local control = input.key_held(input.KEY_LCTRL)
  local shift = input.key_held(input.KEY_LSHIFT)

  if control then
    if input.key_pressed(input.KEY_S) then
      usagi.save(State)
      print("save")
    end
    if input.key_pressed(input.KEY_C) then
      State.world = new_noise_world()
    end
    
    return
  end

  local movement_vector = {
    x = 0,
    y = 0
  }

  if input.key_pressed(input.KEY_F1) then
    RenderUI = not RenderUI
  end

  if input.key_pressed(input.KEY_BACKTICK) then
    DebugOverlay = not DebugOverlay
  end

  if input.key_held(input.KEY_W) then
    movement_vector.y -= 1
    if not shift then Player.facing = DIRECTIONS.UP end
  end
  if input.key_held(input.KEY_A) then
    movement_vector.x -= 1
    if not shift then Player.facing = DIRECTIONS.LEFT end
  end
  if input.key_held(input.KEY_S) then
    movement_vector.y += 1
    if not shift then Player.facing = DIRECTIONS.DOWN end
  end
  if input.key_held(input.KEY_D) then
    movement_vector.x += 1
    if not shift then Player.facing = DIRECTIONS.RIGHT end
  end

  if input.key_pressed(input.KEY_X) then
    Player:damage(1)
  end

  if input.key_pressed(input.KEY_C) then
    Player:heal(1)
  end

  if input.key_pressed(input.KEY_M) then
    MapEnabled = not MapEnabled
  end

  movement_vector = util.vec_normalize(movement_vector)
  State.current_tile = State.world[math.floor(Player.y + 0.5)][math.floor(Player.x + 0.5)]
  local tile_speed_modifier = TILES[State.current_tile].speed_modifier
  if movement_vector.x ~= 0 or movement_vector.y ~= 0 then
    Player.is_moving = true
    Player.x += movement_vector.x * Player.movement_speed * tile_speed_modifier * dt
    Player.y += movement_vector.y * Player.movement_speed * tile_speed_modifier * dt
  else
    Player.is_moving = false
  end
 

  Camera.x = util.clamp(Player.x, CAMERA_HALF_X, WORLD_SIZE_X - CAMERA_HALF_X)
  Camera.y = util.clamp(Player.y, CAMERA_HALF_Y, WORLD_SIZE_Y - CAMERA_HALF_Y)
end

local function draw_terrain()
  -- world tilemap offset based on camera position
  local offset = {
    x = math.floor(Camera.x) - CAMERA_HALF_X,
    y = math.floor(Camera.y) - CAMERA_HALF_Y
  }

  local camera_offset = {
    x = Camera.x % 1,
    y = Camera.y % 1
  }

  for row = 1, CAMERA_SIZE_Y do
    for col = 1, CAMERA_SIZE_X do
      local tile = State.world[row + offset.y][col + offset.x]
      if tile ~= 0 then
        local x = (col - 2 - camera_offset.x) * TILE_SIZE;
        local y = (row - 2 - camera_offset.y) * TILE_SIZE;
        local sprite_index = TILES[tile].sprite
        gfx.spr(sprite_index, x, y)
      end
    end
  end
end

local function draw_entities()
  local offset = {
    x = math.floor(Camera.x) - CAMERA_HALF_X,
    y = math.floor(Camera.y) - CAMERA_HALF_Y
  }
  local camera_offset = {
    x = Camera.x % 1,
    y = Camera.y % 1
  }
  for _, entity in pairs(State.entities) do
    setmetatable(entity, {__index = Entity})
    local x_from_camera = entity.x - offset.x
    local y_from_camera = entity.y - offset.y
    if (x_from_camera >= 1 and x_from_camera <= CAMERA_SIZE_X+1 and y_from_camera >= 1 and y_from_camera <= CAMERA_SIZE_Y) then
      local x = (x_from_camera - 2 - camera_offset.x) * TILE_SIZE;
      local y = (y_from_camera - 2 - camera_offset.y) * TILE_SIZE;
      entity:draw(x, y)
    end
  end
end


local MAP_COLORS = {
  [1] = gfx.COLOR_GREEN,
  [2] = gfx.COLOR_BLUE,
  [3] = gfx.COLOR_YELLOW
}

local function draw_ui()
  text_with_shadow("HP: " .. Player.current_health, 4, usagi.GAME_H - 16, gfx.COLOR_RED)

  if MapEnabled then
    for row = 1, WORLD_SIZE_Y do
      for col = 1, WORLD_SIZE_X do
        gfx.px(col - 1, row - 1, MAP_COLORS[State.world[row][col]])
      end
    end
    gfx.px(Player.x - 1, Player.y - 1, gfx.COLOR_RED)
  end

  if DebugOverlay then
    text_with_shadow(math.floor(Camera.x) .. " " .. math.floor(Camera.y), 0, 8, gfx.COLOR_LIGHT_GRAY)
    text_with_shadow("standing on:" .. TILES[State.current_tile].id, 0, 16, gfx.COLOR_LIGHT_GRAY)
  end
end

function _draw(_dt)
  gfx.clear(gfx.COLOR_BLACK)

  draw_terrain()
  draw_entities()
  Draw_Particles()

  if RenderUI then
    draw_ui()
  end
end