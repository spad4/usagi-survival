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

local MOVE_SPEED = 0.1

local PALETTE = {
  ["0"] = nil,
  ["1"] = gfx.COLOR_GREEN,
  ["2"] = gfx.COLOR_BLUE,
}


function _config()
  return { name = "Survive Test", game_id = "com.spad4.survive" }
end

local function fresh_state()
  State = {
    world = {},
    camera = {
      x = 100, -- top left of world is 0, 0
      y = 100, -- bottom right is 200, 200
    }
  }

  for row = 1, WORLD_SIZE_Y do
    State.world[row] = {}
    for col = 1, WORLD_SIZE_X do
      State.world[row][col] = math.floor(math.random()*2+1)
    end
  end

  return State
end

function _init()
  State = usagi.load() or fresh_state()
  -- State = fresh_state()
  RenderUI = true
  DebugOverlay = false
end

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

  movement_vector = util.vec_normalize(movement_vector)
  State.camera.x += movement_vector.x * MOVE_SPEED
  State.camera.y += movement_vector.y * MOVE_SPEED

end

local function draw_terrain()
  local offset = {
    x = math.floor(State.camera.x) - CAMERA_HALF_X,
    y = math.floor(State.camera.y) - CAMERA_HALF_Y
  }

  local camera_offset = {
    x = State.camera.x % 1,
    y = State.camera.y % 1
  }

  for row = 1, CAMERA_SIZE_Y do
    for col = 1, CAMERA_SIZE_X do
      local tile = State.world[row + offset.y][col + offset.x]
      if tile ~= 0 then
        gfx.rect_fill((col - 2 - camera_offset.x) * TILE_SIZE, (row - 2 - camera_offset.y) * TILE_SIZE, TILE_SIZE, TILE_SIZE, PALETTE[tostring(tile)])
      end
    end
  end
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

local function draw_ui()
  if DebugOverlay then
    text_with_shadow(math.floor(State.camera.x) .. " " .. math.floor(State.camera.y), 5, usagi.GAME_H - 15, gfx.COLOR_LIGHT_GRAY)
  end
end

function _draw(_dt)
  gfx.clear(gfx.COLOR_BLACK)

  -- world tilemap offset based on camera position
  draw_terrain()
  
  if RenderUI then
    draw_ui()
  end

end
