-- SCENE 3 - the 24/7 MART. Three cells: the shop floor, the staff room and
-- the parking lot. Talking to people switches to the face-to-face mode.
local Class = require("lib.classic")
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

local Mart = WS:extend()
local T = 16

local SPAWNS = {
  store = { from_street = { 400, 276, "up" }, from_lot = { 400, 276, "up" }, from_staff = { 454, 66, "down" } },
  staff = { from_store = { 128, 160, "up" } },
  lot = { from_store = { 400, 116, "down" } },
}

local function say(lines, done) Game.say(lines, done) end

-- ---------------------------------------------------------------- NPC in the world
local NPC = Class:extend()

function NPC:new(sprite, x, y)
  self.spr = A.sprite(sprite)
  self.quads = A.frames(self.spr, 2)
  self.x, self.y = x, y
  self.sortY = y
end

function NPC:draw()
  local f = math.floor(love.timer.getTime() * 0.9) % 2 + 1
  R.drawSprite(self.spr, self.x - 10, self.y - 31, { quad = self.quads[f], quadW = 20 })
end

function NPC:drawFloor()
  R.decal()
  love.graphics.setColor(0, 0, 0, 0.5)
  love.graphics.ellipse("fill", math.floor(self.x), math.floor(self.y) - 1, 6, 2.5)
  love.graphics.setColor(1, 1, 1, 1)
end

-- ---------------------------------------------------------------- helpers
local function newWorld(mapName, bgName)
  local grid = World.loadGrid("maps/" .. mapName .. ".txt")
  local w = World(#grid[1] * T, #grid * T)
  w.grid = grid
  w.bg = A.sprite("mart/" .. bgName)
  return w, grid
end

local function examine(w, def)
  local n = 0
  def.action = def.action or function()
    n = n + 1
    say((def.again and n > 1) and def.again or def.lines)
    if def.after then def.after(n) end
  end
  return w:addInteract(def)
end

-- ---------------------------------------------------------------- cells
function Mart:buildStore()
  local w, grid = newWorld("mart_store", "store_bg")
  w.ambient = { 0.07, 0.075, 0.08 }
  w:solidsFromGrid(grid, T, function(c) return c == "#" end)
  w.surface = function() return "tile" end
  local P = function(def) def.sprite = "mart/" .. def.sprite; return w:addProp(def) end

  for i, x in ipairs({ 24, 72, 120, 168, 216 }) do
    P({ sprite = ({ "cooler_a", "cooler_b", "cooler_c" })[(i - 1) % 3 + 1], x = x, y = 8, collider = { 0, 42, 48, 10 } })
  end
  P({ sprite = "staff_door", x = 440, y = 16, sortY = 49 })
  P({ sprite = "mop_bucket", x = 474, y = 30, collider = { 1, 22, 14, 6 } })
  local shelves = { "shelf_a", "shelf_b", "shelf_c", "shelf_d", "shelf_b", "shelf_a" }
  local k = 0
  for _, y in ipairs({ 96, 150, 204 }) do
    for _, x in ipairs({ 36, 156 }) do
      k = k + 1
      P({ sprite = shelves[k], x = x, y = y, collider = { 0, 30, 96, 14 } })
    end
  end
  P({ sprite = "counter", x = 330, y = 196, collider = { 0, 26, 112, 16 } })
  P({ sprite = "side_counter", x = 470, y = 70, collider = { 0, 24, 24, 76 } })
  P({ sprite = "magazine_rack", x = 40, y = 262, collider = { 0, 14, 40, 8 } })
  P({ sprite = "atm", x = 300, y = 250, collider = { 0, 26, 18, 10 } })
  P({ sprite = "wet_floor", x = 286, y = 170 })
  local flyer = P({ sprite = "flyer", x = 418, y = 274, sortY = 300 })

  for i, p in ipairs({ { 96, 120 }, { 240, 120 }, { 96, 230 }, { 240, 230 }, { 400, 130 }, { 400, 240 } }) do
    w:addLight({ x = p[1], y = p[2], z = 70, r = 190, color = { 0.82, 0.95, 0.9 }, intensity = 0.8, halo = 0.03,
      flicker = (i == 4) and "broken" or "soft", seed = i * 7 })
  end
  w:addLight({ x = 140, y = 70, z = 20, r = 110, color = { 0.6, 0.85, 0.8 }, intensity = 0.6, shadows = false })
  w:addLight({ x = 470, y = 120, z = 26, r = 60, color = { 1.0, 0.6, 0.3 }, intensity = 0.5 })

  -- Vincent behind the counter
  self.vincent = w:addEntity(NPC("mart/vincent", 400, 210))
  w:addSolid(392, 206, 16, 6)
  w:addSolid(442, 196, 28, 44)   -- you can't get behind the counter

  -- interactions
  w:addInteract({ x = 380, y = 236, w = 44, h = 14, label = "Talk to the clerk", priority = 3, promptY = 180,
    action = function() self:talkVincent() end })
  examine(w, { x = 470, y = 96, w = 24, h = 60, label = "Hot dogs",
    lines = { "They've been turning since nine. The skins have gone shiny and tight.", "I want one so badly my jaw hurts." } })
  examine(w, { x = 24, y = 50, w = 240, h = 12, label = "Coolers",
    lines = { "The hum of the coolers fills the whole store. Rows of drinks lit up like an aquarium." } })
  examine(w, { x = 36, y = 126, w = 216, h = 140, label = "Shelves",
    lines = { "Bread. Noodles. Canned soup. The good stuff is all at the till anyway." },
    again = { "Half the shelf labels are for things that aren't there anymore." } })
  examine(w, { x = 300, y = 266, w = 18, h = 12, label = "ATM",
    lines = { "OUT OF SERVICE. The screen still glows like it's waiting for someone." } })
  examine(w, { x = 40, y = 276, w = 40, h = 12, label = "Magazines",
    lines = { "Last month's magazines. A word search half done in pen." } })
  w:addInteract({ x = 410, y = 270, w = 18, h = 16, label = "Poster on the door", priority = 2,
    action = function()
      Game.setFlag("saw_flyer")
      say({ "MISSING. Thomas Wren, 8. Last seen near Alder Street Elementary.",
        "Somebody's put fresh tape on the corners. Recently." })
    end })
  w:addInteract({ x = 438, y = 48, w = 34, h = 14, label = "Staff room", priority = 2,
    action = function() self:tryStaffDoor() end })
  w:addInteract({ x = 380, y = 280, w = 40, h = 10, label = "Go outside", priority = 1,
    action = function() self:goCell("lot", "from_store") end })

  local pl = Player(w, 400, 276, "up")
  w:addEntity(pl)
  return w
end

function Mart:buildStaff()
  local w, grid = newWorld("mart_staff", "staff_bg")
  w.ambient = { 0.04, 0.04, 0.05 }
  w:solidsFromGrid(grid, T, function(c) return c == "#" end)
  w.surface = function() return "concrete" end
  local P = function(def) def.sprite = "mart/" .. def.sprite; return w:addProp(def) end

  P({ sprite = "desk_laptop", x = 20, y = 20, collider = { 0, 26, 40, 12 } })
  w:addProp({ sprite = "apartment/chair", x = 32, y = 54, collider = { 1, 20, 12, 6 } })
  local pasta = P({ sprite = "pasta", x = 48, y = 30, baseH = 14, sortY = 60 })
  P({ sprite = "cot", x = 74, y = 40, collider = { 0, 10, 56, 14 } })
  P({ sprite = "note", x = 99, y = 26, sortY = 49 })
  P({ sprite = "mini_fridge", x = 136, y = 30, collider = { 0, 18, 18, 10 } })
  P({ sprite = "lockers", x = 196, y = 6, collider = { 0, 42, 40, 10 } })
  P({ sprite = "boxes", x = 200, y = 110, collider = { 0, 20, 34, 18 } })
  w:addLight({ x = 128, y = 100, z = 40, r = 160, color = { 1.0, 0.78, 0.5 }, intensity = 0.8, flicker = "dying", halo = 0.08 })
  w:addLight({ x = 40, y = 48, z = 22, r = 70, color = { 0.55, 0.7, 1.0 }, intensity = 0.7 })

  examine(w, { x = 20, y = 40, w = 40, h = 22, label = "Laptop", action = function()
    Game.setFlag("saw_laptop")
    G.ui.openDocument(Mart.LAPTOP)
  end })
  local ate = false
  w:addInteract({ x = 44, y = 26, w = 14, h = 34, label = "Pasta", priority = 2,
    enabled = function() return not ate end,
    action = function()
      say({ { text = "Leftover pasta in a plastic tub, fork still in it. Cold. Somebody's dinner.",
        choices = {
          { "Eat it.", function()
            ate = true
            pasta.visible = false
            Game.setFlag("ate_pasta")
            Game.addHunger(-20)
            say({ "I eat it with his fork, standing up. It tastes like the fridge.", "I'll tell him. Probably." })
          end },
          { "Leave it.", function() say({ "Not mine." }) end },
        } } })
    end })
  examine(w, { x = 156, y = 44, w = 24, h = 10, label = "Poster",
    lines = { "A swimsuit calendar from 2009, still on March.", "Somebody circled the 14th. It's the only thing in here that isn't grey." } })
  examine(w, { x = 74, y = 50, w = 56, h = 20, label = "Cot",
    lines = { "A camping cot with a sleeping bag. The pillow still has the dent of a head in it.", "He sleeps here. Some nights, at least." } })
  examine(w, { x = 196, y = 48, w = 40, h = 12, label = "Lockers",
    lines = { "Three lockers. Two names have been peeled off. The third says V. MORALES." } })
  examine(w, { x = 136, y = 48, w = 18, h = 10, label = "Mini fridge",
    lines = { "Energy drinks and one sad yogurt." } })
  w:addInteract({ x = 94, y = 30, w = 16, h = 40, label = "Note on the wall", priority = 3,
    action = function() self:readNote() end })
  w:addInteract({ x = 110, y = 166, w = 36, h = 14, label = "Back to the shop", priority = 1,
    action = function() self:goCell("store", "from_staff") end })

  local pl = Player(w, 128, 160, "up")
  w:addEntity(pl)
  return w
end

function Mart:buildLot()
  local w, grid = newWorld("mart_lot", "lot_bg")
  w.ambient = { 0.045, 0.05, 0.075 }
  w:solidsFromGrid(grid, T, function(c) return c == "#" end)
  w.surface = function() return "concrete" end
  local P = function(def) return w:addProp(def) end

  P({ sprite = "outdoor/store", x = 264, y = -72, collider = { 0, 56, 272, 112 } })
  for _, x in ipairs({ 320, 400, 480 }) do
    w:addLight({ x = x, y = 112, z = 28, r = 150, color = { 0.78, 0.95, 0.86 }, intensity = 1.0, halo = 0.05,
      spot = { 0, 1, math.cos(math.rad(75)) } })
  end
  w:addLight({ x = 400, y = 90, z = 52, r = 130, color = { 1.0, 0.3, 0.25 }, intensity = 0.5, halo = 0.12, flicker = "soft" })
  for i, p in ipairs({ { 60, 148, "car_blue_v" }, { 204, 148, "car_white_v" }, { 588, 148, "car_green_v" }, { 684, 148, "car_gray_v" },
    { 156, 330, "car_red_v" }, { 636, 330, "car_white_v" } }) do
    P({ sprite = "outdoor/" .. p[3], x = p[1], y = p[2], collider = { 1, 12, 26, 44 } })
  end
  P({ sprite = "mart/car_running", x = 96, y = 262, collider = { 1, 16, 48, 14 } })
  w:addEntity(E.Steam(94, 290))
  -- the headlights: the beam is the path to her
  self.beam = w:addLight({ x = 150, y = 288, z = 7, r = 330, color = { 1.0, 0.97, 0.85 }, intensity = 1.6,
    spot = { 1, 0, math.cos(math.rad(13)) }, halo = 0.05 })
  P({ sprite = "mart/woman_down", x = 372, y = 280 })
  P({ sprite = "mart/cart", x = 500, y = 214, collider = { 2, 12, 20, 8 } })
  P({ sprite = "outdoor/dumpster", x = 730, y = 96, collider = { 0, 8, 36, 20 } })
  P({ sprite = "outdoor/streetlight", x = 26, y = 360, collider = { 2, 64, 5, 5 } })
  w:addLight({ x = 41, y = 432, z = 62, r = 170, color = { 1.0, 0.78, 0.48 }, intensity = 1.0, flicker = "dying", halo = 0.18 })
  P({ sprite = "outdoor/bush_a", x = 760, y = 380 })
  w:addEntity(E.Eyes(770, 388, { 0.85, 0.8, 0.3 }, 3))

  examine(w, { x = 96, y = 270, w = 52, h = 30, label = "Running car",
    lines = { "The engine's running. Headlights on full. The driver's door is open and the seat is empty.",
      "Warm air comes out of the vents. Whoever was driving left in a hurry. Or didn't leave." },
    again = { "The keys are in it. A little plastic tag on the ring: a red heart." } })
  w:addInteract({ x = 366, y = 274, w = 50, h = 26, label = "The woman", priority = 3,
    action = function() self:talkRed() end })
  w:addInteract({ x = 384, y = 98, w = 32, h = 14, label = "Back inside", priority = 2,
    action = function() self:goCell("store", "from_lot") end })
  local cool = 0
  w:addTrigger({ x = 0, y = 400, w = 800, h = 30, once = false, fn = function()
    if w.time > cool and not G.ui.blocking() then
      cool = w.time + 8
      say({ "Alder Street's back that way. Not yet." })
    end
  end })
  w:addTrigger({ x = 0, y = 100, w = 800, h = 320, fn = function()
    Game.setFlag("saw_running_car")
    say({ "There's a car idling in the middle of the lot, headlights on full.", "Something's lying in the light." })
  end })

  local pl = Player(w, 400, 116, "down")
  w:addEntity(pl)
  return w
end

-- ---------------------------------------------------------------- cell switching
function Mart:setCell(name, spawn)
  self.cell = name
  self.world = self.cells[name]
  G.world = self.world
  local pl = self.world.player
  local sp = SPAWNS[name][spawn]
  if sp then pl:teleport(sp[1], sp[2], sp[3]) end
  self.camera:setBounds(-8, -8, self.world.w + 16, self.world.h + 16)
  self.camera:snapTo(pl.x, pl.y - 14)
  if name == "lot" then
    G.audio.loop("amb", "amb_outdoor", 0.7)
    G.audio.loop("engine", "engine_idle", 0.0)
  else
    G.audio.loop("amb", name == "store" and "fridge_hum" or "amb_apartment", 0.5)
    G.audio.setLoopVolume("engine", 0)
  end
end

function Mart:goCell(name, spawn)
  if self.cellFade then return end
  self.cutscene = true
  G.audio.play(name == "lot" and "door_chime" or "door_open", 0.5)
  self.cellFade = { t = 0, name = name, spawn = spawn, swapped = false }
end

-- ---------------------------------------------------------------- events
function Mart:talkVincent()
  local V = require("src.dialogue.vincent")
  G.ui.openConversation(V, { onExit = function(npc)
    if Game.flag("bought_food") and not self.ateLine then
      self.ateLine = true
      say({ "Food. Actual food. The shaking in my hands is finally stopping." })
    end
  end })
end

function Mart:talkRed()
  local Red = require("src.dialogue.red")
  G.ui.openConversation(Red)
end

function Mart:tryStaffDoor()
  if Game.has("staff_key") then
    G.audio.play("door_unlock", 0.7)
    Game.setFlag("entered_staff")
    self:goCell("staff", "from_store")
    return
  end
  local first = not Game.flag("tried_staff_door")
  Game.setFlag("tried_staff_door")
  G.audio.play("door_locked", 0.7)
  if first then
    say({ "Locked. STAFF ONLY.", "There's light under the door. And the sound of a laptop fan." })
  else
    say({ "Still locked. The clerk would have the key." })
  end
end

function Mart:readNote()
  say({ "A sheet of paper taped above the cot. The handwriting is mine." }, function()
    Game.setFlag("read_note")
    G.ui.openDocument(Mart.NOTE)
    G.ui.modal.onClose = function() self:wakeUp() end
  end)
end

function Mart:wakeUp()
  self.cutscene = true
  Script.run(function()
    G.audio.play("sting", 0.9)
    G.audio.loop("ring", "tinnitus", 0.6)
    local t = 0
    Script.waitUntil(function()
      t = t + Script.dt
      self.faint = math.min(1, t / 1.6)
      self.camera:shake(0.08)
      return t >= 1.8
    end)
    G.audio.fadeOutAll()
    Game.setFlag("scene4")
    G.state.stage = 4
    G.scenes.switch(G.sceneList.scene4, {}, { speed = 2.5 })
  end)
end

-- ---------------------------------------------------------------- documents
Mart.NOTE = {
  title = "",
  pages = { { head = "wake up", body = "", foot = "" } },
  handwritten = true,
}

Mart.LAPTOP = {
  title = "VINCENT'S LAPTOP",
  pages = {
    { head = "Messages", body = "Mom - 3 missed calls\nMom: are you eating\nMom: call me when you wake up\nMom: vinnie??\n\nNo replies sent.", foot = "1 of 3" },
    { head = "Open tabs", body = "how many night shifts is too many\njobs no experience no phone interview\nis it normal to not talk to anyone for a week\ndoes it get better\n\nThe last one has been open for 41 days.", foot = "2 of 3" },
    { head = "days.xlsx", body = "Column A counts up from 1. The last row is 1,461.\nNext to each number, one word.\nAlmost all of them say: same.", foot = "3 of 3" },
  },
}

-- ---------------------------------------------------------------- scene api
function Mart:enter(args)
  self.cells = { store = self:buildStore(), staff = self:buildStaff(), lot = self:buildLot() }
  self.cellFade = nil
  self.world = self.cells.store
  self:baseEnter()
  G.ui.hudVisible = true
  self:setCell(args.cell or "store", args.spawn or "from_street")
  if G.state.stage < 3 then G.state.stage = 3 end
  if not args.skipIntro then
    self.cutscene = true
    G.scenes.showCard("24/7 MART", nil, 2.6)
    Script.run(function()
      Script.wait(2.2)
      Game.sayWait({ "Too bright after the street. Every tube in the ceiling buzzes at a slightly different pitch.",
        "The clerk is behind the counter. He hasn't looked up yet." })
      self.cutscene = false
      G.ui.objectiveUpdated("New objective")
    end)
  end
end

function Mart:update(dt)
  -- cell transition: fade to black, swap, fade back
  local cf = self.cellFade
  if cf then
    cf.t = cf.t + dt
    if cf.t >= 0.35 and not cf.swapped then
      cf.swapped = true
      self:setCell(cf.name, cf.spawn)
    end
    if cf.t >= 0.75 then
      self.cellFade = nil
      self.cutscene = false
    end
  end
  Mart.super.update(self, dt)
  if self.cell == "lot" then
    local pl = self.world.player
    local d = U.dist(pl.x, pl.y, 120, 280)
    G.audio.setLoopVolume("engine", math.max(0, 1 - d / 420) * 0.7)
  end
end

function Mart:drawOverlayLowRes()
  Mart.super.drawOverlayLowRes(self)
  local cf = self.cellFade
  if cf then
    local a = cf.t < 0.35 and cf.t / 0.35 or math.max(0, 1 - (cf.t - 0.35) / 0.4)
    love.graphics.setColor(0, 0, 0, a)
    love.graphics.rectangle("fill", 0, 0, R.W, R.H)
    love.graphics.setColor(1, 1, 1, 1)
  end
end

return Mart
