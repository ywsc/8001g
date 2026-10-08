-- SCENE 2 - Alder Street, outside, a little after 2AM.
local G = require("src.g")
local A = require("src.core.assets")
local R = require("src.core.renderer")
local Script = require("src.core.script")
local U = require("src.core.util")
local Game = require("src.game.game")
local World = require("src.world.world")
local Player = require("src.world.player")
local E = require("src.world.entities")
local WS = require("src.scenes.worldscene")

local N = WS:extend()

local T = 16
N.SPAWN = { 440, 432 }
N.STORE_DOOR = { 1096, 420 }

function N:new()
  N.super.new(self)
end

local function say(lines, done) Game.say(lines, done) end

-- ---------------------------------------------------------------- build
-- withPlayer=false is used by the title screen backdrop
function N:build(withPlayer)
  local grid = World.loadGrid("maps/neighborhood.txt")
  local w = World(#grid[1] * T, #grid * T)
  self.world = w
  w.bg = A.sprite("outdoor/outdoor_bg")
  w.ambient = { 0.050, 0.056, 0.085 }
  w:solidsFromGrid(grid, T, function(c) return c == "#" end)
  w.surface = function(x, y)
    local row = grid[math.floor(y / T) + 1]
    local c = row and row:sub(math.floor(x / T) + 1, math.floor(x / T) + 1)
    if c == "g" or c == "d" then return "grass" end
    return "concrete"
  end

  local function P(def)
    def.sprite = "outdoor/" .. def.sprite
    return w:addProp(def)
  end
  local function lamp(x, y, flip, flicker, opts)
    opts = opts or {}
    P({ sprite = "streetlight", x = flip and x - 16 or x - 4, y = y - 69, flip = flip, collider = { flip and 13 or 2, 64, 5, 5 } })
    local l = w:addLight({ x = x + (flip and -11 or 11), y = y + 3, z = 62, r = opts.r or 175, color = opts.color or { 1.0, 0.78, 0.48 },
      intensity = opts.intensity or 1.5, flicker = flicker, halo = 0.2, on = opts.on })
    return l
  end

  -- ===== north: school behind the fence =====
  P({ sprite = "school", x = 424, y = -52 })
  P({ sprite = "swing", x = 300, y = 64 })
  P({ sprite = "ball", x = 556, y = 112 })
  P({ sprite = "tree_b", x = 140, y = 40 })
  P({ sprite = "tree_a", x = 960, y = 50 })
  for x = 0, 1264, 16 do
    if x < 576 or x >= 720 then P({ sprite = "fence_iron", x = x, y = 110 }) end
  end
  P({ sprite = "school_gate", x = 576, y = 92 })
  lamp(586, 152, false, "dying")
  lamp(712, 152, true, nil, { on = false })   -- dead lamp

  -- ===== my building and the west block =====
  P({ sprite = "bld_apt_a", x = 336, y = 144, collider = { 0, 112, 208, 160 } })
  P({ sprite = "bld_apt_b", x = 48, y = 112, collider = { 0, 128, 256, 176 } })
  w:addLight({ x = 440, y = 420, z = 26, r = 90, color = { 1.0, 0.82, 0.5 }, intensity = 0.9, flicker = "soft", halo = 0.08 })
  P({ sprite = "dumpster", x = 306, y = 386, collider = { 0, 8, 36, 20 } })
  P({ sprite = "trash_can", x = 290, y = 404, collider = { 1, 12, 10, 7 } })
  P({ sprite = "tree_c", x = 300, y = 170 })
  P({ sprite = "tree_a", x = 560, y = 180 })
  P({ sprite = "bush_a", x = 210, y = 420 })
  P({ sprite = "bush_b", x = 520, y = 418 })

  -- ===== north-east: empty lot, trees, cat =====
  P({ sprite = "tree_b", x = 780, y = 210 })
  P({ sprite = "tree_c", x = 880, y = 300 })
  P({ sprite = "tree_a", x = 1150, y = 170 })
  P({ sprite = "bush_a", x = 900, y = 388 })
  P({ sprite = "bush_b", x = 760, y = 400 })
  w:addEntity(E.Eyes(910, 396, { 0.85, 0.8, 0.3 }, 3))

  -- ===== east: the store =====
  P({ sprite = "store", x = 960, y = 248, collider = { 0, 56, 272, 112 } })
  P({ sprite = "bench", x = 1004, y = 418, collider = { 0, 8, 32, 8 } })
  P({ sprite = "vending", x = 1222, y = 384, collider = { 0, 22, 18, 12 } })
  P({ sprite = "trash_can", x = 1146, y = 410, collider = { 1, 12, 10, 7 } })
  for _, x in ipairs({ 1010, 1096, 1182 }) do
    w:addLight({ x = x, y = 428, z = 28, r = 150, color = { 0.78, 0.95, 0.86 }, intensity = 1.05, shadows = true, halo = 0.05,
      spot = { 0, 1, math.cos(math.rad(75)) } })
  end
  self.neon = w:addLight({ x = 1096, y = 410, z = 52, r = 130, color = { 1.0, 0.3, 0.25 }, intensity = 0.55, halo = 0.12, flicker = "soft" })
  w:addLight({ x = 1231, y = 422, z = 16, r = 60, color = { 0.6, 0.8, 1.0 }, intensity = 0.6 })

  -- ===== the street =====
  for _, d in ipairs({ { 110, 452 }, { 300, 452, nil, "soft" }, { 840, 452, nil, "broken" }, { 1240, 452 } }) do lamp(d[1], d[2], d[3], d[4]) end
  for _, d in ipairs({ { 210, 592, true }, { 430, 592, true }, { 900, 592, true, "dying" }, { 1110, 592, true } }) do lamp(d[1], d[2], d[3], d[4]) end
  lamp(578, 330, false, "soft")
  lamp(718, 280, true)
  lamp(718, 690, true, "broken")
  P({ sprite = "traffic_light", x = 586, y = 412, collider = { 4, 56, 4, 4 } })
  P({ sprite = "traffic_light", x = 700, y = 536, collider = { 4, 56, 4, 4 } })
  local blink = function(t) return (t % 1.4) < 0.7 and 1 or 0.05 end
  w:addLight({ x = 592, y = 416, z = 54, r = 80, color = { 1.0, 0.65, 0.15 }, intensity = 0.7, flicker = blink, halo = 0.1, shadows = false })
  w:addLight({ x = 706, y = 540, z = 54, r = 80, color = { 1.0, 0.65, 0.15 }, intensity = 0.7, flicker = blink, halo = 0.1, shadows = false })
  P({ sprite = "car_red", x = 820, y = 470, collider = { 1, 16, 48, 14 } })
  P({ sprite = "car_gray", x = 160, y = 530, collider = { 1, 16, 48, 14 }, flip = true })
  P({ sprite = "hydrant", x = 612, y = 432, collider = { 1, 9, 6, 4 } })
  for _, x in ipairs({ 250, 760, 1160 }) do
    P({ sprite = "power_pole", x = x - 13, y = 446 - 99, collider = { 10, 94, 6, 5 } })
  end
  w:addEntity(E.Wire(250, 446, 760, 446, 90))
  w:addEntity(E.Wire(760, 446, 1160, 446, 90))
  w:addEntity(E.Wire(250, 446, 0, 446, 90))
  w:addEntity(E.Wire(1160, 446, 1280, 446, 90))
  w:addEntity(E.Steam(560, 506))
  w:addEntity(E.Steam(760, 534))

  -- ===== south-west: houses =====
  P({ sprite = "house_a", x = 70, y = 640, collider = { 0, 54, 96, 72 } })
  P({ sprite = "house_b", x = 250, y = 630, collider = { 0, 54, 96, 72 } })
  P({ sprite = "tree_c", x = 196, y = 650 })
  P({ sprite = "bush_a", x = 30, y = 760 })
  P({ sprite = "bush_b", x = 380, y = 700 })
  w:addLight({ x = 88, y = 770, z = 24, r = 70, color = { 1.0, 0.75, 0.45 }, intensity = 0.4, flicker = "soft" })

  -- ===== south-east: billboard, payphone, a house =====
  P({ sprite = "billboard", x = 860, y = 610, collider = { 18, 86, 60, 6 } })
  P({ sprite = "house_c", x = 1130, y = 620, collider = { 0, 54, 96, 72 } })
  P({ sprite = "payphone", x = 760, y = 584, collider = { 4, 34, 6, 5 } })
  w:addLight({ x = 767, y = 600, z = 34, r = 50, color = { 0.6, 0.7, 1.0 }, intensity = 0.5, flicker = "broken", seed = 3 })
  P({ sprite = "tree_b", x = 1010, y = 680 })

  -- ===== south: the dealership =====
  P({ sprite = "office", x = 760, y = 760, collider = { 0, 46, 208, 96 } })
  P({ sprite = "deal_sign", x = 556, y = 704, collider = { 20, 90, 8, 5 } })
  local signLight = w:addLight({ x = 580, y = 800, z = 80, r = 120, color = { 0.4, 0.75, 1.0 }, intensity = 0.6, flicker = "broken", seed = 11, halo = 0.12 })
  for i, x in ipairs({ 400, 436, 472, 508, 544 }) do
    local cars = { "car_blue_v", "car_white_v", "car_green_v", "car_red_v", "car_gray_v" }
    P({ sprite = cars[i], x = x, y = 800, collider = { 1, 12, 26, 44 } })
  end
  for i, x in ipairs({ 420, 492, 564 }) do
    local cars = { "car_gray_v", "car_red_v", "car_white_v" }
    P({ sprite = cars[i], x = x, y = 890, collider = { 1, 12, 26, 44 } })
  end
  for x = 384, 576, 32 do P({ sprite = "chainlink", x = x, y = 739, collider = { 0, 26, 32, 3 } }) end
  for x = 704, 992, 32 do P({ sprite = "chainlink", x = x, y = 739, collider = { 0, 26, 32, 3 } }) end
  w:addEntity(E.Pennants(400, 796, 600, 796, 34))
  lamp(500, 870, false, "dying", { r = 160 })
  w:addLight({ x = 911, y = 868, z = 20, r = 50, color = { 1.0, 0.8, 0.5 }, intensity = 0.5 })
  self.signLight = signLight

  if withPlayer ~= false then
    self:buildInteractions()
    local pl = Player(w, N.SPAWN[1], N.SPAWN[2], "down")
    w:addEntity(pl)
  end
end

-- ---------------------------------------------------------------- interactions
function N:buildInteractions()
  local w = self.world

  -- the broken lock near the gate
  local lockProp = w:addProp({ sprite = "outdoor/lock", x = 700, y = 154 })
  local lockTaken = false
  w:addInteract({ x = 696, y = 150, w = 14, h = 12, label = "Something on the ground", priority = 4,
    enabled = function() return not lockTaken end,
    action = function()
      lockTaken = true
      lockProp.visible = false
      Game.give("lock")
      say({ "A padlock. Rusted through, the shackle snapped clean in half.", "Somebody cut it off the gate. Then somebody put a new one on." })
    end })
  w:addEntity(E.Glint(703, 154, 0, function() return not lockTaken end))

  -- school gate: the memory
  local gateSeen = 0
  w:addInteract({ x = 592, y = 140, w = 112, h = 12, label = "School gate", action = function()
    gateSeen = gateSeen + 1
    if gateSeen == 1 then
      self.cutscene = true
      Script.run(function()
        G.audio.play("gate_rattle", 0.8)
        self.camera:shake(0.15)
        Game.sayWait({ "Locked. A new chain, a shiny new padlock.",
          "Alder Street Elementary. I went here. Third grade, Mrs. Halloran's class.",
          "We used to dare each other to touch this gate after dark. Tommy Reyes swore something lived in the boiler room.",
          "One night I stayed out past the streetlights. Somebody was standing in the yard, right about... there.",
          "I ran all the way home and never told anyone.",
          "...I'd forgotten that. Why would I forget that?" })
        Game.setFlag("gate_memory")
        self.cutscene = false
        if not lockTaken then say({ "Something's lying in the gutter by the gate." }) end
      end)
    else
      say({ "The swings are moving. There's no wind." })
    end
  end })

  local examine = function(def)
    local n = 0
    def.action = function()
      n = n + 1
      say((def.again and n > 1) and def.again or def.lines)
    end
    return w:addInteract(def)
  end

  examine({ x = 424, y = 404, w = 32, h = 14, label = "Building door",
    lines = { "The door clicked shut behind me. Key's in my pocket.", "Food first." } })
  examine({ x = 140, y = 404, w = 50, h = 14, label = "Apartment block",
    lines = { "The block next door. Forty apartments and not one light on.", "Nobody awake on Alder Street but me." },
    again = { "A curtain on the second floor twitched. Or I imagined it." } })
  examine({ x = 304, y = 392, w = 38, h = 22, label = "Dumpster",
    lines = { "Something in there is eating better than I am." } })
  examine({ x = 860, y = 690, w = 96, h = 14, label = "Billboard",
    lines = { "HOLLOW CREEK - A GREAT PLACE TO GROW UP.", "Somebody tore the little boy's face off the poster." } })
  local rung = false
  examine({ x = 756, y = 610, w = 22, h = 14, label = "Payphone",
    lines = { "A payphone. I didn't know they still had these." } })
  w:addTrigger({ x = 700, y = 560, w = 140, h = 80, enabled = function() return Game.flag("faint_done") end, fn = function()
    if rung then return end
    rung = true
    G.audio.play("phone_ring", 0.6)
    Script.run(function()
      Script.wait(2.2)
      say({ "The payphone is ringing.", "...I'm not answering that. I'm NOT answering that." })
    end)
  end })
  examine({ x = 1222, y = 400, w = 18, h = 18, label = "Vending machine",
    lines = { "OUT OF ORDER, in marker, on a sticky note. The note looks older than me." } })
  examine({ x = 1004, y = 420, w = 32, h = 10, label = "Bench",
    lines = { "Can't sit down. If I sit down I won't get back up." } })
  examine({ x = 70, y = 750, w = 96, h = 16, label = "The Doyles' house",
    lines = { "The Doyles. Mrs. Doyle used to leave her porch light on for the paperboy.", "The paperboy stopped coming years ago. The light's still on." } })
  examine({ x = 250, y = 740, w = 96, h = 16, label = "House",
    lines = { "FOR SALE, says the sign. It's been for sale since I moved in." } })
  examine({ x = 556, y = 790, w = 48, h = 12, label = "Dealership sign",
    lines = { "HOLLOW CREEK MOTORS. Half the letters are dead.", "The newspaper said the night watchman went missing here." } })
  examine({ x = 398, y = 850, w = 176, h = 14, label = "Used cars",
    lines = { "$1,999. AS IS. NO REFUNDS.", "There's a child's handprint on the inside of the windshield." } })
  examine({ x = 760, y = 900, w = 208, h = 12, label = "Office",
    lines = { "A desk lamp is on inside. Nobody at the desk." } })
  examine({ x = 812, y = 482, w = 54, h = 20, label = "Parked car",
    lines = { "Frost on the windshield. Someone wrote in it with a finger:", { text = "HUNGRY?", style = "system" } } })

  -- edges of the map: the four directions
  local edge = function(x, y, ww, hh, lines)
    local cool = 0
    w:addTrigger({ x = x, y = y, w = ww, h = hh, once = false, fn = function()
      if self.world.time > cool and not G.ui.blocking() then
        cool = self.world.time + 8
        say(lines)
      end
    end })
  end
  edge(0, 440, 22, 160, { "West is just more apartment blocks. Dark windows all the way down.", "Nothing for me that way. The store's east." })
  edge(1258, 440, 22, 160, { "Past the store there's only the underpass. Not tonight." })
  edge(560, 936, 160, 24, { "The road runs on into the dark past the lot.", "No streetlights down there. I'm not going down there." })
  edge(576, 144, 144, 10, { "The gate's chained shut." })

  -- the hunger attack at the crossroads
  w:addTrigger({ x = 576, y = 448, w = 144, h = 144, fn = function() self:faintEvent() end,
    enabled = function() return not Game.flag("faint_done") end })

  -- the store
  w:addTrigger({ x = 1060, y = 414, w = 72, h = 34, fn = function() self:reachStore() end })
  w:addInteract({ x = 1080, y = 404, w = 32, h = 14, label = "24/7 MART", action = function() self:reachStore() end })

  -- the figure in the dealership lot
  w:addEntity(E.Figure(470, 930, { vanishDist = 150, onVanish = function()
    G.audio.play("sting", 0.4)
    Game.setFlag("saw_figure")
  end }))
end

-- ---------------------------------------------------------------- events
function N:faintEvent()
  if Game.flag("faint_done") or self.cutscene then return end
  self.cutscene = true
  Game.setFlag("faint_started")
  local pl = self.world.player
  Script.run(function()
    G.audio.play("growl", 1.0, 0.8)
    G.audio.loop("heart", "heartbeat", 0.9)
    G.audio.loop("ring", "tinnitus", 0.0)
    local t = 0
    Script.waitUntil(function()
      t = t + Script.dt
      self.faint = math.min(1, t / 2.2)
      G.audio.setLoopVolume("ring", self.faint * 0.5)
      if t > 1.0 and pl.state ~= "kneel" then
        pl.state = "kneel"
        self.camera:shake(0.6)
        G.audio.play("thud", 0.8)
      end
      return t >= 2.4
    end)
    G.state.hunger = 94
    Game.sayWait({ "...!", "My legs just - go. The street tilts.",
      "Everything turns grey and far away. My heart is a fist on a door.",
      "Breathe. Breathe. Don't pass out here. Not out here." })
    local t2 = 0
    Script.waitUntil(function()
      t2 = t2 + Script.dt
      self.faint = math.max(0.15, 1 - t2 / 2.5)
      G.audio.setLoopVolume("ring", self.faint * 0.4)
      return t2 >= 2.5
    end)
    pl.state = "free"
    G.audio.setLoopVolume("heart", 0.35)
    Game.sayWait({ "When did I last eat. Really eat.", "Food. Now. The store is east, at the end of the street. Hurry." })
    Game.setFlag("faint_done")
    G.ui.objectiveUpdated("Objective updated")
    G.ui.toast("The 24/7 MART is to the EAST")
    local t3 = 0
    Script.waitUntil(function()
      t3 = t3 + Script.dt
      self.faint = 0.15 * (1 - t3 / 3)
      return t3 >= 3
    end)
    self.faint = 0
    G.audio.setLoopVolume("ring", 0)
    self.cutscene = false
  end)
end

function N:reachStore()
  if self.reached then return end
  self.reached = true
  self.cutscene = true
  local pl = self.world.player
  Script.run(function()
    Script.waitUntil(function() return not G.ui.blocking() end)
    self:walkTo(N.STORE_DOOR[1], N.STORE_DOOR[2] + 10, 4)
    pl.facing = "up"
    G.audio.play("door_chime", 0.8)
    Script.wait(0.6)
    if not Game.flag("faint_done") then
      Game.sayWait({ "Made it. My stomach is screaming." })
    end
    Game.sayWait({ "The doors shudder open. Fluorescent hum. Warm air that smells like old coffee and bleach.",
      "Bread. Instant noodles. A hot dog that's been turning since yesterday. I could cry.",
      "There's nobody behind the counter.", "...Hello?" })
    Game.setFlag("reached_store")
    G.audio.fadeOutAll()
    G.scenes.switch(G.sceneList.ending, {}, { speed = 0.5 })
  end)
end

-- ---------------------------------------------------------------- scene api
function N:enter(args)
  self.reached = false
  self:build(true)
  self:baseEnter()
  G.ui.hudVisible = true
  self.outsideT = 0
  G.audio.loop("amb", "amb_outdoor", 0.8)
  if not args.skipIntro then
    self.cutscene = true
    G.scenes.showCard(select(1, U.formatClock(G.state.clock)) .. " AM", "Alder Street", 3)
    Script.run(function()
      Script.wait(2.4)
      G.audio.play("door_close", 0.6)
      Game.sayWait({ "Cold. The air smells like wet leaves and exhaust.",
        "Alder Street at 2AM. North, the old school. South, the car lot. West, more of the same.",
        "East, at the end of the street, the 24/7 MART. Never closed. Never." })
      self.cutscene = false
    end)
  end
end

function N:update(dt)
  N.super.update(self, dt)
  self.outsideT = (self.outsideT or 0) + dt
  -- if the player dawdles, the hunger finds them anyway
  if not Game.flag("faint_started") and self.outsideT > 60 and not G.ui.blocking() and not self.cutscene then
    self:faintEvent()
  end
end

-- drifting ground fog, drawn over the lit image before post
function N:fogOverlay()
  if not self.fogImg then
    local d = love.image.newImageData(128, 128)
    d:mapPixel(function(x, y)
      local n = 0
      local f, a = 1 / 32, 0.6
      for _ = 1, 4 do
        n = n + love.math.noise(x * f, y * f, 3.7) * a
        f, a = f * 2, a * 0.5
      end
      return 1, 1, 1, math.max(0, n - 0.55) * 0.5
    end)
    self.fogImg = love.graphics.newImage(d)
    self.fogImg:setWrap("repeat", "repeat")
    self.fogImg:setFilter("linear", "linear")
    self.fogQuad = love.graphics.newQuad(0, 0, R.W + 256, R.H + 256, 128, 128)
  end
  local cx, cy = self.camera:drawPos()
  local t = love.timer.getTime()
  local ox = -((cx * 1.0 + t * 6) % 128)
  local oy = -((cy * 1.0 + t * 2) % 128)
  love.graphics.setBlendMode("add")
  love.graphics.setColor(0.10, 0.12, 0.16, 1)
  love.graphics.draw(self.fogImg, self.fogQuad, ox, oy, 0, 1, 1)
  love.graphics.setColor(0.07, 0.08, 0.11, 1)
  love.graphics.draw(self.fogImg, self.fogQuad, -((cx + t * 11) % 128), -((cy - t * 3) % 128), 0, 1, 1)
  love.graphics.setBlendMode("alpha")
  love.graphics.setColor(1, 1, 1, 1)
end

function N:draw()
  self.extraOverlay = function() self:fogOverlay() end
  N.super.draw(self)
end

return N
