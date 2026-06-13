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

local WORLD_SIZE_X = 200 -- in tiles
local WORLD_SIZE_Y = 200

-- default: 22x14
-- this extends outside of the game window so that player movement doesn't expose edges
local CAMERA_SIZE_X = 22 -- in tiles
local CAMERA_SIZE_Y = 14
local CAMERA_HALF_X = math.floor(CAMERA_SIZE_X/2)
local CAMERA_HALF_Y = math.floor(CAMERA_SIZE_Y/2)

local TILE_SIZE = 16 -- in pixels

local TILES = require("tiles")
local ENTITIES = require("entities")

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
  gfx.text(text, x+1, y+1, gfx.COLOR_DARK_GRAY)
  gfx.text(text, x, y, color)
end

local function fresh_state()
  State = {
    world = {},
    current_tile = 1,
    entities = {
      [1] = ENTITIES.NEW_PLAYER(100, 100)
    }
  }

  for row = 1, WORLD_SIZE_Y do
    State.world[row] = {}
    for col = 1, WORLD_SIZE_X do
      -- State.world[row][col] = 1
      State.world[row][col] = math.floor(math.random()*#TILES+1)
    end
  end

  State.world[100][100] = 2

  return State
end

local function update_entity_props(state)
  if not state then
    return
  end
  for i,entity in pairs(state.entities) do
      local id = entity.id
      local props = ENTITIES["PROP_"..id]()
      for k,v in pairs(props) do
        entity[k] = v
      end
    end
end

local function load_state()

  local to_return = usagi.load()
  
  -- something was saved; all entities need to have their properties updated
  if (to_return) then
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
end

update_entity_props(State)

function _update(dt)
  if input.key_held(input.KEY_LCTRL) then
    if input.key_pressed(input.KEY_S) then
      usagi.save(State)
      print("save")
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

  if input.key_pressed(input.KEY_F3) then
    DebugOverlay = not DebugOverlay
  end

  if input.key_held(input.KEY_W) then
    movement_vector.y -= 1
  end
  if input.key_held(input.KEY_A) then
    movement_vector.x -= 1
  end
  if input.key_held(input.KEY_S) then
    movement_vector.y += 1
  end
  if input.key_held(input.KEY_D) then
    movement_vector.x += 1
  end

  if input.key_pressed(input.KEY_X) then
    ENTITIES.damage(Player, 1)
  end

  if input.key_pressed(input.KEY_C) then
    ENTITIES.heal(Player, 1)
  end

  movement_vector = util.vec_normalize(movement_vector)
  State.current_tile = State.world[math.floor(Player.y + 0.5)][math.floor(Player.x + 0.5)]
  local tile_speed_modifier = TILES[State.current_tile].speed_modifier
  Player.x += movement_vector.x * Player.movement_speed * tile_speed_modifier
  Player.y += movement_vector.y * Player.movement_speed * tile_speed_modifier

  Camera.x, Camera.y = Player.x, Player.y

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
        -- gfx.rect_fill((col - 2 - camera_offset.x) * TILE_SIZE, (row - 2 - camera_offset.y) * TILE_SIZE, TILE_SIZE, TILE_SIZE, PALETTE[tostring(tile)])
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
  for _,entity in pairs(State.entities) do
    local x_from_camera = entity.x - offset.x
    local y_from_camera = entity.y - offset.y
    local x = (x_from_camera - 2 - camera_offset.x) * TILE_SIZE;
    local y = (y_from_camera - 2 - camera_offset.y) * TILE_SIZE;
    if (x_from_camera >= 1 and x_from_camera <= CAMERA_SIZE_X and y_from_camera >= 1 and y_from_camera <= CAMERA_SIZE_Y) then
      gfx.spr(entity.sprite, x, y)
    end
  end
end

local function draw_ui()
  text_with_shadow("HP: " .. Player.current_health, 4, 4, gfx.COLOR_RED)
  if DebugOverlay then
    text_with_shadow(math.floor(Camera.x) .. " " .. math.floor(Camera.y), 5, usagi.GAME_H - 15, gfx.COLOR_LIGHT_GRAY)
    text_with_shadow("standing on:" .. TILES[State.current_tile].id, 5, usagi.GAME_H - 24, gfx.COLOR_LIGHT_GRAY)
  end
end

function _draw(_dt)
  gfx.clear(gfx.COLOR_BLACK)

  draw_terrain()
  draw_entities()
  
  if RenderUI then
    draw_ui()
  end

end
