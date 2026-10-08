local Class = require("lib.classic")
local anim8 = require("lib.anim8")
local A = require("src.core.assets")
local R = require("src.core.renderer")
local Input = require("src.core.input")
local G = require("src.g")

local Player = Class:extend()

local FW, FH = 20, 32
local ROW = { down = 1, left = 2, right = 3, up = 4 }
local DIRV = { down = { 0, 1 }, up = { 0, -1 }, left = { -1, 0 }, right = { 1, 0 } }

Player.WALK = 50
Player.RUN = 86

function Player:new(world, x, y, facing)
  self.world = world
  self.x, self.y = x, y
  self.facing = facing or "down"
  self.spr = A.sprite("chars/player")
  self.lying = A.sprite("chars/player_lying")
  self.kneel = A.sprite("chars/player_kneel")
  local g = anim8.newGrid(FW, FH, self.spr.w, self.spr.h)
  self.anims = {}
  for dir, row in pairs(ROW) do
    self.anims[dir] = {
      idle = anim8.newAnimation(g("1-2", row), { 1.1, 0.9 }),
      walk = anim8.newAnimation(g("3-6", row), 0.14),
    }
  end
  self.state = "free"   -- free | locked | lying | kneel
  self.moving = false
  self.running = false
  self.speedMul = 1
  self.lastFrame = 1
  self.sortY = y
  self.box = { player = true }
  world.bump:add(self.box, x - 5, y - 4, 10, 5)
  world.player = self
  self.stepT = 0
end

function Player:teleport(x, y, facing)
  self.x, self.y = x, y
  if facing then self.facing = facing end
  self.world.bump:update(self.box, x - 5, y - 4)
end

local function filter(item, other)
  if other.solid then return "slide" end
  return nil
end

function Player:update(dt)
  local mx, my = 0, 0
  if self.state == "free" and not G.ui.blocking() then
    mx, my = Input.move()
  end
  if self.autoMove then
    mx, my = self.autoMove[1], self.autoMove[2]
  end
  local len = math.sqrt(mx * mx + my * my)
  self.moving = len > 0.2
  if self.moving then
    mx, my = mx / math.max(1, len), my / math.max(1, len)
    if math.abs(mx) > math.abs(my) + 0.05 then
      self.facing = mx < 0 and "left" or "right"
    elseif math.abs(my) > 0.05 then
      self.facing = my < 0 and "up" or "down"
    end
    self.running = Input.down("run") and self.state == "free"
    local speed = (self.running and Player.RUN or Player.WALK) * self.speedMul
    local tx = self.x + mx * speed * dt
    local ty = self.y + my * speed * dt
    local ax, ay = self.world.bump:move(self.box, tx - 5, ty - 4, filter)
    self.x, self.y = ax + 5, ay + 4
  end
  local a = self.anims[self.facing]
  local cur = self.moving and a.walk or a.idle
  if cur ~= self.cur then cur:gotoFrame(1); self.cur = cur end
  cur:update(dt * (self.running and 1.6 or 1) * (self.moving and self.speedMul or 1))
  -- footsteps on contact frames
  if self.moving then
    local f = cur.position
    if f ~= self.lastFrame and (f == 1 or f == 3) then
      local surf = self.world.surface(self.x, self.y)
      G.audio.play("step_" .. surf, self.running and 0.55 or 0.38, 0.9 + love.math.random() * 0.2)
    end
    self.lastFrame = f
  end
  self.sortY = self.y
end

function Player:facingVec()
  local v = DIRV[self.facing]
  return v[1], v[2]
end

-- hand position + aim for the phone flashlight
function Player:flashlight()
  local fx, fy = self:facingVec()
  return {
    x = self.x + fx * 4, y = self.y + fy * 2 + 1, z = 14, r = 190,
    color = { 0.85, 0.9, 1.0 }, intensity = 1.25,
    spot = { fx, fy, math.cos(math.rad(30)) }, shadows = true, halo = 0.05,
  }
end

function Player:drawFloor()
  if self.state == "lying" then return end
  R.decal()
  love.graphics.setColor(0, 0, 0, 0.55)
  love.graphics.ellipse("fill", math.floor(self.x), math.floor(self.y) - 1, 6, 2.5)
  love.graphics.setColor(1, 1, 1, 1)
end

function Player:draw()
  if self.hidden then return end
  if self.state == "lying" then
    R.drawSprite(self.lying, self.lyingX, self.lyingY, { baseH = 12 })
    return
  end
  if self.state == "kneel" then
    R.drawSprite(self.kneel, self.x - FW / 2, self.y - FH + 1)
    return
  end
  local q = self.cur and self.cur.frames[self.cur.position]
  if not q then
    self.cur = self.anims[self.facing].idle
    q = self.cur.frames[1]
  end
  R.drawSprite(self.spr, self.x - FW / 2, self.y - FH + 1, { quad = q, quadW = FW })
end

return Player
