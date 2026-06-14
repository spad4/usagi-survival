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
require("tile")
require("particle_emitter")
require("entity_registry")
require("particle_emitter_registry")
require("particle_registry")
require("tile_registry")

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
      to_return[row][col] = {}
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

      to_return[row][col].tile = tile
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

local function generate_display_grids(world)
  -- world
  -- tile

  local display_grid = {}
  for k, tile in pairs(TILES) do
    display_grid[k] = {}
    for row = 2, WORLD_SIZE_Y do
      display_grid[k][row] = {}
      for col = 2, WORLD_SIZE_X do
        local bits = 0
        local top_left = world[row - 1][col - 1].tile
        local top_right = world[row - 1][col].tile
        local bot_left = world[row][col - 1].tile
        local bot_right = world[row][col].tile
        if top_left.id ~= tile.id then
          bits = bits | (1 << 3)
        end
        if top_right.id ~= tile.id then
          bits = bits | (1 << 2)
        end
        if bot_left.id ~= tile.id then
          bits = bits | (1 << 1)
        end
        if bot_right.id ~= tile.id then
          bits = bits | (1 << 0)
        end
        display_grid[k][row][col] = bits
      end
    end
  end

  return display_grid
end

local function place_tile(x, y, tile)
  State.world[y][x].tile = tile

  local id = tile.id
  for k, g in pairs(TileDisplayGrids) do
    if k == id then
      g[y - 0][x - 0] = g[y - 0][x - 0] & ~(1 << 0)
      g[y - 0][x + 1] = g[y - 0][x + 1] & ~(1 << 1)
      g[y + 1][x - 0] = g[y + 1][x - 0] & ~(1 << 2)
      g[y + 1][x + 1] = g[y + 1][x + 1] & ~(1 << 3)
    else
      g[y - 0][x - 0] = g[y - 0][x - 0] | (1 << 0)
      g[y - 0][x + 1] = g[y - 0][x + 1] | (1 << 1)
      g[y + 1][x - 0] = g[y + 1][x - 0] | (1 << 2)
      g[y + 1][x + 1] = g[y + 1][x + 1] | (1 << 3)
    end
  end
end

function _init()
  State = load_state()
  -- State = fresh_state()
  RenderUI = true
  DebugOverlay = false
  Player = State.entities[1]
  BuildingWith = TILES.GRASS
  SelectedTile = {
    x = 0,
    y = 0
  }
  Camera = {
    x = Player.x,
    y = Player.y,
    origin_x = math.floor(Player.x) - CAMERA_HALF_X,
    origin_y = math.floor(Player.y) - CAMERA_HALF_Y,
    frac_x = Player.x % 1,
    frac_y = Player.y % 1
  }
  perlin:load()
  TileDisplayGrids = generate_display_grids(State.world)
end

update_entity_props(State)

DIRECTION_TO_VECTOR = {
  [0] = {
    x = 0,
    y = 1
  },
  [1] = {
    x = 0,
    y = -1
  },
  [2] = {
    x = 1,
    y = 0
  },
  [3] = {
    x = -1,
    y = 0
  }
}

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

  if input.key_pressed(input.KEY_F3) then
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

  if input.key_pressed(input.KEY_1) then
    BuildingWith = TILES.GRASS
  end
  if input.key_pressed(input.KEY_2) then
    BuildingWith = TILES.WATER
  end
  if input.key_pressed(input.KEY_3) then
    BuildingWith = TILES.SAND
  end
  if input.key_pressed(input.KEY_H) then
    TileDisplayGrids = generate_display_grids(State.world)
  end

  if input.key_held(input.KEY_SPACE) then
    -- State.world[SelectedTile.y][SelectedTile.x].tile = BuildingWith
    place_tile(SelectedTile.x, SelectedTile.y, BuildingWith)
  end

  movement_vector = util.vec_normalize(movement_vector)
  State.current_tile = State.world[math.floor(Player.y + 0.5)][math.floor(Player.x + 0.5)].tile
  local tile_speed_modifier = State.current_tile.speed_modifier
  -- local tile_speed_modifier = 1
  if movement_vector.x ~= 0 or movement_vector.y ~= 0 then
    Player.is_moving = true
    Player.x += movement_vector.x * Player.movement_speed * tile_speed_modifier * dt
    Player.y += movement_vector.y * Player.movement_speed * tile_speed_modifier * dt
  else
    Player.is_moving = false
  end

  Camera.x = util.clamp(Player.x - 0.25, CAMERA_HALF_X, WORLD_SIZE_X - CAMERA_HALF_X)
  Camera.y = util.clamp(Player.y - 0.5, CAMERA_HALF_Y, WORLD_SIZE_Y - CAMERA_HALF_Y)
  Camera.origin_x = math.floor(Camera.x) - CAMERA_HALF_X
  Camera.origin_y = math.floor(Camera.y) - CAMERA_HALF_Y
  Camera.frac_x = Camera.x % 1
  Camera.frac_y = Camera.y % 1

  local offset_vec = DIRECTION_TO_VECTOR[Player.facing]
  SelectedTile.x = math.floor(Player.x + 0.5) + offset_vec.x
  SelectedTile.y = math.floor(Player.y + 0.5) + offset_vec.y
end

function Pos_To_Screen(vec)
  local to_return = {}
  to_return.x_from_camera = vec.x - Camera.origin_x
  to_return.y_from_camera = vec.y - Camera.origin_y
  to_return.x = (to_return.x_from_camera - 2 - Camera.frac_x) * TILE_SIZE;
  to_return.y = (to_return.y_from_camera - 2 - Camera.frac_y) * TILE_SIZE;

  return to_return
end

function On_Screen(pos)
  return pos.x_from_camera < 1 or pos.x_from_camera > CAMERA_SIZE_X + 1 or
      pos.y_from_camera < 1 and pos.y_from_camera > CAMERA_SIZE_Y
end

local function draw_entities()
  for _, entity in pairs(State.entities) do
    setmetatable(entity, { __index = Entity })
    entity:draw()
  end
end

local function draw_ui()
  text_with_shadow("HP: " .. Player.current_health, 4, usagi.GAME_H - 16, gfx.COLOR_RED)

  if MapEnabled then
    for row = 1, WORLD_SIZE_Y do
      for col = 1, WORLD_SIZE_X do
        local color = gfx["COLOR_" .. State.world[row][col].tile.map_color]
        gfx.px(col - 1, row - 1, color)
      end
    end
    gfx.px(Player.x - 1, Player.y - 1, gfx.COLOR_RED)
  end

  if DebugOverlay then
    text_with_shadow(math.floor(Camera.x) .. " " .. math.floor(Camera.y), 0, 8, gfx.COLOR_LIGHT_GRAY)
    text_with_shadow("standing on:" .. State.current_tile.id, 0, 16, gfx.COLOR_LIGHT_GRAY)
    text_with_shadow("holding:" .. BuildingWith.id, 0, 24, gfx.COLOR_LIGHT_GRAY)
  end
end

function _draw(_dt)
  gfx.clear(gfx.COLOR_BLACK)

  Draw_Tiles() --
  if RenderUI then
    local pos = Pos_To_Screen(SelectedTile)
    gfx.spr_ex(34, pos.x, pos.y, false, false, 0, gfx.COLOR_TRUE_WHITE, 0.25)
  end
  draw_entities()
  Run_Emitters()
  Draw_Particles()
  if RenderUI then
    draw_ui()
  end
end
