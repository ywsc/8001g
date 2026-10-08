-- SCENE 1 - Apartment 4B, 02:03 AM.
local G = require("src.g")
local R = require("src.core.renderer")
local Script = require("src.core.script")
local Game = require("src.game.game")
local World = require("src.world.world")
local Player = require("src.world.player")
local E = require("src.world.entities")
local WS = require("src.scenes.worldscene")

local Apartment = WS:extend()

local T = 16

function Apartment:new()
  Apartment.super.new(self)
end

-- ---------------------------------------------------------------- helpers
local function say(lines, done) Game.say(lines, done) end

-- one-line (or rotating) examine text
local function examine(world, def)
  local n = 0
  def.action = def.action or function()
    n = n + 1
    local lines = def.lines
    if def.again and n > 1 then lines = def.again end
    say(lines)
    if def.after then def.after(n) end
  end
  return world:addInteract(def)
end

function Apartment:pickup(def)
  local w = self.world
  local prop = w:addProp({ sprite = "apartment/" .. def.sprite, x = def.x, y = def.y, baseH = def.baseH, sortY = def.sortY })
  local taken = false
  local it = w:addInteract({
    -- things lying on furniture can be reached from in front of it
    x = def.x - 3, y = def.y - 3, w = prop.fw + 6, h = prop.fh + 6 + (def.baseH or 0),
    label = def.label, priority = 4,
    enabled = function() return not taken end,
    action = function()
      taken = true
      prop.visible = false
      Game.give(def.item, def.count or 1)
      if def.lines then say(def.lines) end
      if def.after then def.after() end
    end,
  })
  w:addEntity(E.Glint(def.x + prop.fw / 2, def.y - (def.baseH or 0) + 1, 0, function() return not taken end))
  return prop, it
end

-- ---------------------------------------------------------------- build
function Apartment:build()
  local grid = World.loadGrid("maps/apartment.txt")
  local w = World(#grid[1] * T, #grid * T)
  self.world = w
  w.grid = grid
  w.bg = require("src.core.assets").sprite("apartment/apartment_bg")
  w.ambient = { 0.040, 0.040, 0.055 }
  w:solidsFromGrid(grid, T, function(c) return c == "#" end)
  w.surface = function(x, y)
    local row = grid[math.floor(y / T) + 1]
    local c = row and row:sub(math.floor(x / T) + 1, math.floor(x / T) + 1)
    if c == "b" then return "carpet" elseif c == "t" or c == "k" then return "tile" end
    return "wood"
  end

  local P = function(def) def.sprite = "apartment/" .. def.sprite; return w:addProp(def) end

  -- ===== bedroom =====
  self.bed = P({ sprite = "bed", x = 20, y = 40, collider = { 0, 12, 36, 46 } })
  P({ sprite = "nightstand", x = 58, y = 36, collider = { 0, 24, 16, 10 } })
  P({ sprite = "desk", x = 110, y = 30, collider = { 0, 28, 36, 12 } })
  P({ sprite = "chair", x = 121, y = 62, collider = { 1, 20, 12, 6 } })
  P({ sprite = "wardrobe", x = 186, y = 14, collider = { 0, 46, 30, 12 } })
  P({ sprite = "clothes_a", x = 86, y = 118 })
  P({ sprite = "clothes_b", x = 150, y = 142 })
  P({ sprite = "clothes_c", x = 28, y = 150 })
  P({ sprite = "pizza_boxes", x = 188, y = 104 })
  P({ sprite = "trashbag_a", x = 200, y = 152, collider = { 2, 10, 14, 6 } })
  self.lamp = w:addLight({ x = 66, y = 64, z = 26, r = 120, color = { 1.0, 0.72, 0.42 }, intensity = 1.0, flicker = "soft", halo = 0.05 })
  w:addLight({ x = 84, y = 60, z = 30, r = 120, color = { 0.42, 0.52, 0.85 }, intensity = 0.65,
    spot = { 0, 1, math.cos(math.rad(50)) } })

  -- ===== bathroom =====
  P({ sprite = "toilet", x = 248, y = 36, collider = { 1, 14, 12, 10 } })
  P({ sprite = "sink", x = 288, y = 38, collider = { 0, 12, 18, 8 } })
  P({ sprite = "bathtub", x = 322, y = 56, collider = { 0, 10, 30, 56 } })
  P({ sprite = "curtain", x = 319, y = 52, sortY = 123 })
  P({ sprite = "bathmat", x = 266, y = 96, layer = "floor" })
  P({ sprite = "puddle", x = 246, y = 138, layer = "floor" })
  local tube = P({ sprite = "tube_light", x = 258, y = 20, sortY = 30 })
  self.tubeLight = w:addLight({ x = 268, y = 58, z = 30, r = 130, color = { 0.75, 0.95, 0.85 }, intensity = 1.0, flicker = "broken", halo = 0.04 })
  tube.lightLink = self.tubeLight

  -- ===== kitchen =====
  P({ sprite = "counter", x = 372, y = 34, collider = { 0, 18, 96, 14 } })
  self.fridge = P({ sprite = "fridge", x = 478, y = 20, collider = { 0, 40, 24, 14 } })
  P({ sprite = "trashcan", x = 506, y = 50, collider = { 1, 14, 12, 10 } })
  P({ sprite = "trashbag_b", x = 524, y = 60, collider = { 2, 10, 14, 6 } })
  P({ sprite = "trashbag_c", x = 540, y = 74, collider = { 2, 10, 14, 6 } })
  P({ sprite = "table", x = 430, y = 110, collider = { 0, 14, 36, 10 } })
  P({ sprite = "chair_k", x = 414, y = 112, collider = { 1, 20, 12, 6 } })
  P({ sprite = "chair_k", x = 470, y = 118, collider = { 1, 20, 12, 6 }, flip = true })
  w:addLight({ x = 450, y = 112, z = 36, r = 140, color = { 1.0, 0.8, 0.5 }, intensity = 0.55, flicker = "dying", halo = 0.05 })
  w:addLight({ x = 460, y = 56, z = 22, r = 36, color = { 0.3, 1.0, 0.45 }, intensity = 0.5, shadows = false })
  self.fridgeLight = w:addLight({ x = 490, y = 80, z = 22, r = 110, color = { 0.75, 0.92, 0.88 }, intensity = 1.3,
    spot = { 0, 1, math.cos(math.rad(65)) }, on = false, halo = 0.05 })

  -- ===== living room =====
  P({ sprite = "bookshelf", x = 40, y = 184, collider = { 0, 38, 32, 10 } })
  local tv = P({ sprite = "tv", x = 212, y = 196, collider = { 0, 26, 32, 10 } })
  local static = P({ sprite = "tv_static", x = 219, y = 206, frames = 4, fps = 14, sortY = tv.sortY + 1, baseH = 0 })
  P({ sprite = "coffee_table", x = 208, y = 252, collider = { 0, 6, 40, 14 } })
  P({ sprite = "couch", x = 196, y = 284, collider = { 0, 6, 64, 24 } })
  P({ sprite = "doormat", x = 257, y = 338, layer = "floor" })
  self.doorStrip = P({ sprite = "door_light", x = 259, y = 350, layer = "floor" })
  P({ sprite = "shoe_pile", x = 232, y = 330 })
  P({ sprite = "coat_rack", x = 298, y = 298, collider = { 4, 44, 6, 5 } })
  P({ sprite = "trashbag_a", x = 318, y = 326, collider = { 2, 10, 14, 6 } })
  P({ sprite = "trashbag_b", x = 334, y = 334, collider = { 2, 10, 14, 6 } })
  P({ sprite = "trashbag_c", x = 300, y = 338 })
  P({ sprite = "clothes_b", x = 120, y = 300 })
  P({ sprite = "pizza_boxes", x = 420, y = 270 })
  local tvLight = w:addLight({ x = 228, y = 248, z = 18, r = 150, color = { 0.6, 0.72, 0.9 }, intensity = 1.0, flicker = "tv",
    spot = { 0, 1, math.cos(math.rad(70)) }, halo = 0.06 })
  static.lightLink = tvLight
  w:addLight({ x = 330, y = 276, z = 36, r = 190, color = { 1.0, 0.78, 0.5 }, intensity = 0.6, flicker = "dying", halo = 0.06, seed = 7 })
  -- corridor light leaking under the front door; feet pass by sometimes
  self.doorLight = w:addLight({ x = 272, y = 356, z = 3, r = 70, color = { 1.0, 0.75, 0.4 }, intensity = 0.7, shadows = false,
    flicker = function(t)
      local c = t % 23
      if c > 18 and c < 19.2 then return 0.15 + math.abs(math.sin((c - 18) * 5)) * 0.5 end
      return 0.95 + 0.05 * math.sin(t * 3)
    end })
  self.doorStrip.lightLink = self.doorLight

  -- roaches
  w:addEntity(E.Roach(400, 150, { 372, 90, 180, 80 }))
  w:addEntity(E.Roach(520, 130, { 372, 90, 180, 80 }))
  w:addEntity(E.Roach(100, 330, { 30, 300, 500, 46 }))
  w:addEntity(E.Roach(270, 160, { 244, 130, 70, 40 }))

  self:buildInteractions()

  local pl = Player(w, 66, 100, "down")
  w:addEntity(pl)
end

function Apartment:buildInteractions()
  local w = self.world

  -- --- pickups -----------------------------------------------------------
  self:pickup({ sprite = "coin", x = 46, y = 66, baseH = 16, sortY = 100, item = "coin", count = 1, label = "Coin",
    lines = { "A coin, warm from my own body heat. Gross." } })
  self:pickup({ sprite = "coin", x = 44, y = 86, baseH = 15, sortY = 100, item = "coin", count = 1, label = "Coin",
    lines = { "Another one, down between the sheets." } })
  self:pickup({ sprite = "coin", x = 282, y = 150, item = "coin", label = "Coin",
    lines = { "A coin by the drain. I'm not too proud." } })
  self:pickup({ sprite = "phone", x = 66, y = 50, baseH = 10, sortY = 72, item = "phone", label = "Cellphone",
    lines = {
      "My phone. Cracked screen, 9% battery.",
      "One new message. Unknown number, sent 02:01:",
      { text = "\"are you awake\"", style = "system" },
      "...Wrong number. Probably.",
    },
    after = function()
      G.ui.toast("Press " .. require("src.ui.theme").keyName("flashlight") .. " - phone flashlight", "phone")
    end })
  self:pickup({ sprite = "key", x = 135, y = 48, baseH = 14, sortY = 72, item = "key", label = "Keys",
    lines = { "The building key, under a pile of bills. FINAL NOTICE. FINAL, FINAL NOTICE." } })
  self:pickup({ sprite = "backpack", x = 166, y = 66, item = "backpack", label = "Backpack",
    lines = { "My old backpack. Heavy - stuffed with newspapers.", "Rubbish. I keep meaning to throw them out." },
    after = function() G.ui.toast("Tab - read it from the inventory", "backpack") end })

  -- --- bedroom -----------------------------------------------------------
  examine(w, { x = 20, y = 52, w = 36, h = 46, label = "Bed",
    lines = { "The sheets are damp. I was sweating in my sleep again." },
    again = { "I won't sleep again tonight. Not hungry like this." } })
  self.lampOn = true
  w:addInteract({ x = 58, y = 54, w = 16, h = 16, label = "Lamp", action = function()
    self.lampOn = not self.lampOn
    self.lamp.on = self.lampOn
    G.audio.play("click", 0.7)
  end })
  examine(w, { x = 110, y = 54, w = 36, h = 16, label = "Desk",
    lines = { "Bills. Takeout menus. A sticky note in my handwriting:", { text = "DON'T ANSWER IT", style = "system" }, "Answer what?" } })
  examine(w, { x = 186, y = 56, w = 30, h = 16, label = "Wardrobe",
    lines = { "The door's open a crack.", "I don't remember leaving it open." },
    again = { "Just clothes in there. Just clothes." } })
  examine(w, { x = 70, y = 46, w = 28, h = 10, label = "Window",
    lines = { "Alder Street, four floors down. Every window across the road is dark.", "Except one. Someone standing in it. Looking up.", "...At me?" },
    again = { "The lit window across the road is dark now." } })
  examine(w, { x = 146, y = 46, w = 40, h = 10, label = "Posters",
    lines = { "I don't remember what band this was. Or buying it." } })
  examine(w, { x = 84, y = 118, w = 22, h = 14, label = "Clothes",
    lines = { "Smells like last week. Nothing in the pockets." } })

  -- --- bathroom ----------------------------------------------------------
  examine(w, { x = 248, y = 46, w = 14, h = 18, label = "Toilet",
    lines = { "I'm not lifting that lid. Not at 2AM." } })
  examine(w, { x = 288, y = 46, w = 18, h = 18, label = "Mirror",
    lines = { "I look like I haven't slept in weeks.", "There's someone behind m-", "...", "Just the shower curtain. Get it together." },
    after = function(n)
      if n == 1 then
        Script.run(function()
          Script.wait(0.9)
          G.audio.play("sting", 0.7)
          self.camera:shake(0.5)
        end)
      end
    end })
  examine(w, { x = 316, y = 60, w = 34, h = 64, label = "Shower curtain",
    lines = { "I don't open it.", "I never open it at night." } })

  -- --- kitchen -----------------------------------------------------------
  self.fridgeItems = { "water", "coke", "meat", "knife" }
  w:addInteract({ x = 478, y = 56, w = 24, h = 20, label = "Fridge", action = function() self:openFridge() end })
  examine(w, { x = 372, y = 50, w = 36, h = 18, label = "Sink",
    lines = { "Dishes. A month of them.", "Something moved under the water. A bubble. Just a bubble." } })
  examine(w, { x = 412, y = 50, w = 24, h = 18, label = "Stove",
    lines = { "Something's been in that pot since... I don't want to know." } })
  examine(w, { x = 440, y = 50, w = 26, h = 18, label = "Microwave",
    lines = { "The clock blinks 02:03. It's been 02:03 in this kitchen for a year." } })
  examine(w, { x = 504, y = 60, w = 50, h = 30, label = "Trash",
    lines = { "Overflowing. The roaches have their own economy now." } })
  examine(w, { x = 430, y = 118, w = 36, h = 22, label = "Table",
    lines = { "Takeout boxes. All empty. I checked. Twice." } })

  -- --- living room -------------------------------------------------------
  examine(w, { x = 212, y = 222, w = 32, h = 16, label = "TV",
    lines = { "Static. I fell asleep with it on again.", "...I don't remember turning it on." } })
  examine(w, { x = 196, y = 286, w = 64, h = 26, label = "Couch",
    lines = { "There's a dent in the cushion the exact shape of me." } })
  examine(w, { x = 40, y = 222, w = 32, h = 14, label = "Bookshelf",
    lines = { "Books I bought to become a better person. Spines uncracked." } })
  examine(w, { x = 140, y = 196, w = 20, h = 28, label = "Clock", promptY = 196,
    action = function()
      local hm, suf = require("src.core.util").formatClock(G.state.clock)
      say({ hm .. " " .. suf .. ". Still dark for hours." })
    end })
  examine(w, { x = 54, y = 200, w = 20, h = 24, label = "Flyer",
    lines = { "A flyer someone slid under my door. MISSING. A little boy, gap-toothed smile.", "Thomas Wren. Last seen near the school gates." } })
  examine(w, { x = 300, y = 324, w = 52, h = 26, label = "Trash bags",
    lines = { "I keep saying I'll take them down tomorrow." } })

  -- --- front door --------------------------------------------------------
  w:addInteract({ x = 254, y = 336, w = 36, h = 16, label = "Front door", priority = 2, action = function() self:tryDoor() end })
end

-- ---------------------------------------------------------------- fridge
function Apartment:openFridge()
  local w = self.world
  w:setPropSprite(self.fridge, "apartment/fridge_open")
  self.fridgeLight.on = true
  G.audio.play("fridge_open", 0.7)
  G.audio.loop("fridge", "fridge_hum", 0.5)
  local first = not self.fridgeSeen
  self.fridgeSeen = true
  G.ui.openContainer({
    title = "Fridge",
    items = self.fridgeItems,
    emptyText = "Nothing left worth taking. Just the smell, and a container of something green.",
    onTake = function(id)
      Game.give(id, 1)
    end,
    onClose = function()
      w:setPropSprite(self.fridge, "apartment/fridge")
      self.fridgeLight.on = false
      G.audio.play("fridge_close", 0.7)
      G.audio.setLoopVolume("fridge", 0)
      if first then
        say({ "Water, a flat coke, meat that's turning grey... and a knife. Why is there a knife in the fridge?",
          "None of it is food. Not real food." })
      end
    end,
  })
end

-- ---------------------------------------------------------------- door
function Apartment:tryDoor()
  if G.state.stage < 2 then
    say({ "I can't go out with empty pockets.", "I need money. A few coins... or my phone, it can pay." })
    return
  end
  if not Game.has("key") then
    Game.setFlag("door_needs_key")
    G.audio.play("door_locked", 0.8)
    say({ "Locked. The deadbolt needs the key.", "Where did I leave it... the desk, probably. It's always the desk." })
    return
  end
  self.cutscene = true
  G.audio.play("door_unlock", 0.8)
  Script.run(function()
    Script.wait(0.5)
    Game.sayWait({ "The hallway light buzzes on the other side." })
    G.audio.play("door_open", 0.8)
    Game.setFlag("left_apartment")
    G.audio.fadeOutAll()
    G.scenes.switch(G.sceneList.neighborhood, {}, { speed = 0.8 })
  end)
end

-- ---------------------------------------------------------------- intro
function Apartment:intro()
  local pl = self.world.player
  pl.state = "lying"
  pl.lyingX, pl.lyingY = 28, 43
  pl.sortY = 101
  self.eyelid = 1
  self.cutscene = true
  G.ui.hudVisible = false
  self.camTarget = { 60, 80 }
  self.camera:snapTo(60, 80)
  G.scenes.showCard("02:03 AM", "Apartment 4B  -  Alder Street", 3.4)
  Script.run(function()
    Script.wait(3.6)
    G.audio.play("growl", 0.9)
    Script.wait(1.2)
    -- eyes open, flutter, open
    for _, v in ipairs({ 0.55, 0.9, 0.3, 0.7, 0 }) do
      local start = self.eyelid
      local t = 0
      Script.waitUntil(function()
        t = t + Script.dt * 2.2
        self.eyelid = start + (v - start) * math.min(1, t)
        return t >= 1
      end)
      Script.wait(0.2)
    end
    Game.sayWait({ "...", "My stomach wakes me up before the dream ends. Again.",
      "When did I last eat? Yesterday morning? The day before?" })
    G.audio.play("growl", 1.0, 0.9)
    self.camera:shake(0.25)
    Game.sayWait({ "There's nothing in this apartment worth eating.",
      "The 24-hour store at the end of Alder Street is still open.",
      "I need money first. Three coins would do it... or my phone. It can pay." })
    pl.state = "free"
    pl:teleport(66, 100, "down")
    G.audio.play("bed_creak", 0.7)
    self.camTarget = nil
    self.cutscene = false
    G.ui.hudVisible = true
    G.ui.objectiveUpdated("New objective")
    Script.wait(0.6)
    G.ui.toast("WASD / Arrows - move    Shift - run")
    Script.wait(0.5)
    G.ui.toast("E - interact    Tab - inventory")
  end)
end

-- ---------------------------------------------------------------- scene api
function Apartment:enter(args)
  self:build()
  self:baseEnter()
  G.audio.loop("amb", "amb_apartment", 0.7)
  if args.skipIntro then
    G.ui.hudVisible = true
    self.cutscene = false
  else
    self:intro()
  end
end

function Apartment:update(dt)
  Apartment.super.update(self, dt)
  local pl = self.world.player
  if pl.state == "lying" then pl.sortY = 101 end
  -- buzzing tube volume by distance
  local d = math.sqrt((pl.x - 270) ^ 2 + (pl.y - 60) ^ 2)
  local buzz = math.max(0, 1 - d / 160) * (self.tubeLight.mult or 1)
  G.audio.loop("buzz", "buzz", buzz * 0.5)
  local dtv = math.sqrt((pl.x - 228) ^ 2 + (pl.y - 240) ^ 2)
  G.audio.loop("static", "tv_static", math.max(0, 1 - dtv / 200) * 0.35)
end

-- clock hands on the living room wall
function Apartment:drawWorldExtra()
  local m = G.state.clock
  local cx, cy = 150, 202
  local ah = (m / 60 % 12) / 12 * math.pi * 2 - math.pi / 2
  local am = (m % 60) / 60 * math.pi * 2 - math.pi / 2
  R.flat({ 0, 0.92, 0.38 }, 26)
  love.graphics.setColor(0.08, 0.07, 0.06, 1)
  love.graphics.setLineWidth(1)
  love.graphics.setLineStyle("rough")
  love.graphics.line(cx + 0.5, cy + 0.5, cx + 0.5 + math.cos(ah) * 2.5, cy + 0.5 + math.sin(ah) * 2.5)
  love.graphics.line(cx + 0.5, cy + 0.5, cx + 0.5 + math.cos(am) * 4, cy + 0.5 + math.sin(am) * 4)
  love.graphics.setColor(1, 1, 1, 1)
end

return Apartment
