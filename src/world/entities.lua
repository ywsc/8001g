-- Small living details: roaches, item glints, steam, cat eyes, the figure,
-- pennant flags. Each entity has update(dt, world), draw(), sortY.
local Class = require("lib.classic")
local A = require("src.core.assets")
local R = require("src.core.renderer")
local U = require("src.core.util")
local G = require("src.g")

local E = {}

-- ---------------------------------------------------------------- roach
E.Roach = Class:extend()

function E.Roach:new(x, y, area)
  self.x, self.y, self.area = x, y, area   -- area = {x,y,w,h}
  self.spr = A.sprite("apartment/roach")
  self.quads = A.frames(self.spr, 2)
  self.dir = love.math.random() * math.pi * 2
  self.speed = 0
  self.t = love.math.random() * 3
  self.sortY = y
end

function E.Roach:update(dt, world)
  self.t = self.t - dt
  local pl = world.player
  local flee = pl and U.dist(pl.x, pl.y, self.x, self.y) < 26
  if flee then
    self.dir = math.atan2(self.y - pl.y, self.x - pl.x) + (love.math.random() - 0.5) * 0.6
    self.speed = 70
  elseif self.t <= 0 then
    self.t = 0.4 + love.math.random() * 2.5
    if love.math.random() < 0.45 then self.speed = 0 else
      self.speed = 18 + love.math.random() * 20
      self.dir = self.dir + (love.math.random() - 0.5) * 2.5
    end
  end
  local a = self.area
  local nx = self.x + math.cos(self.dir) * self.speed * dt
  local ny = self.y + math.sin(self.dir) * self.speed * dt
  if nx < a[1] or nx > a[1] + a[3] then self.dir = math.pi - self.dir; nx = self.x end
  if ny < a[2] or ny > a[2] + a[4] then self.dir = -self.dir; ny = self.y end
  self.x, self.y = nx, ny
  self.sortY = self.y - 6
end

function E.Roach:draw()
  local f = (self.speed > 0 and math.floor(love.timer.getTime() * 14) % 2 or 0) + 1
  R.drawSprite(self.spr, self.x - 2, self.y - 2, { quad = self.quads[f], quadW = 5 })
end

-- ---------------------------------------------------------------- glint
-- a tiny sparkle that helps the player notice pickups in the dark
E.Glint = Class:extend()

function E.Glint:new(x, y, h, cond)
  self.x, self.y, self.h, self.cond = x, y, h or 0, cond
  self.phase = love.math.random() * 4
  self.sortY = y + 1000 -- always on top
end

function E.Glint:update(dt)
  if self.cond and not self.cond() then self.dead = true end
end

function E.Glint:draw()
  local t = (love.timer.getTime() + self.phase) % 3.2
  if t > 0.5 then return end
  local k = math.sin(t / 0.5 * math.pi)
  local s = math.floor(k * 2.5 + 0.5)
  R.flat({ 0, 0, 1 }, 60, { 1.6, 1.5, 1.2 })
  love.graphics.setColor(1, 0.95, 0.75, 1)
  local x, y = math.floor(self.x), math.floor(self.y)
  love.graphics.rectangle("fill", x, y - s, 1, s * 2 + 1)
  love.graphics.rectangle("fill", x - s, y, s * 2 + 1, 1)
  love.graphics.setColor(1, 1, 1, 1)
end

-- ---------------------------------------------------------------- steam
E.Steam = Class:extend()

function E.Steam:new(x, y)
  self.x, self.y = x, y
  self.parts = {}
  self.acc = 0
  self.sortY = y + 2
end

function E.Steam:update(dt)
  self.acc = self.acc + dt
  while self.acc > 0.12 do
    self.acc = self.acc - 0.12
    table.insert(self.parts, { x = self.x + (love.math.random() - 0.5) * 8, y = self.y, life = 0, vx = (love.math.random() - 0.3) * 6, s = 2 + love.math.random() * 2 })
  end
  for i = #self.parts, 1, -1 do
    local p = self.parts[i]
    p.life = p.life + dt
    p.x = p.x + p.vx * dt
    p.y = p.y - 9 * dt
    p.s = p.s + dt * 3
    if p.life > 2.6 then table.remove(self.parts, i) end
  end
end

function E.Steam:draw()
  -- drawn as soft albedo-only puffs so lights pick them up
  R.flat({ 0, 0.4, 0.9 }, 30)
  for _, p in ipairs(self.parts) do
    local a = (1 - p.life / 2.6) * 0.9
    if (math.floor(p.x * 3 + p.y * 7) % 3) < 3 * a then
      love.graphics.setColor(0.45, 0.47, 0.5, 1)
      love.graphics.rectangle("fill", math.floor(p.x), math.floor(p.y), math.floor(p.s), math.floor(p.s * 0.7))
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
end

-- ---------------------------------------------------------------- eyes
E.Eyes = Class:extend()

function E.Eyes:new(x, y, color, gap)
  self.x, self.y = x, y
  self.color = color or { 0.9, 0.85, 0.3 }
  self.gap = gap or 3
  self.sortY = y + 400
  self.blinkT = 2 + love.math.random() * 3
  self.open = true
  self.visible = true
end

function E.Eyes:update(dt, world)
  self.blinkT = self.blinkT - dt
  if self.blinkT < 0 then
    self.open = not self.open
    self.blinkT = self.open and (2 + love.math.random() * 4) or 0.15
  end
  local pl = world.player
  if pl and U.dist(pl.x, pl.y, self.x, self.y) < 50 then
    self.visible = false
    self.hideT = 6
  elseif self.hideT then
    self.hideT = self.hideT - dt
    if self.hideT <= 0 then self.hideT = nil; self.visible = true end
  end
end

function E.Eyes:draw()
  if not (self.open and self.visible) then return end
  R.flat({ 0, 0, 1 }, 6, self.color)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.rectangle("fill", math.floor(self.x), math.floor(self.y), 1, 1)
  love.graphics.rectangle("fill", math.floor(self.x) + self.gap, math.floor(self.y), 1, 1)
end

-- ---------------------------------------------------------------- figure
-- a silhouette that stands under a far light and is gone when you get close
E.Figure = Class:extend()

function E.Figure:new(x, y, opts)
  opts = opts or {}
  self.x, self.y = x, y
  self.spr = A.sprite("chars/figure")
  self.alpha = 1
  self.sortY = y
  self.vanishDist = opts.vanishDist or 120
  self.gone = false
  self.onVanish = opts.onVanish
end

function E.Figure:update(dt, world)
  local pl = world.player
  if self.gone then
    self.alpha = math.max(0, self.alpha - dt * 1.5)
    if self.alpha <= 0 then self.dead = true end
    return
  end
  if pl and U.dist(pl.x, pl.y, self.x, self.y) < self.vanishDist then
    self.gone = true
    if self.onVanish then self.onVanish() end
  end
end

function E.Figure:draw()
  if self.alpha < 1 and (math.floor(love.timer.getTime() * 30) % 2 == 0 or love.math.random() > self.alpha) then return end
  R.drawSprite(self.spr, self.x - self.spr.w / 2, self.y - self.spr.h + 1)
end

-- ---------------------------------------------------------------- pennants
-- a string of triangular flags between two poles, swaying
E.Pennants = Class:extend()

function E.Pennants:new(x1, y1, x2, y2, h)
  self.x1, self.y1, self.x2, self.y2, self.h = x1, y1, x2, y2, h or 40
  self.x = x1
  self.sortY = math.max(y1, y2) + 1
  self.colors = { { 0.5, 0.12, 0.1 }, { 0.6, 0.55, 0.2 }, { 0.15, 0.25, 0.45 }, { 0.55, 0.55, 0.55 } }
end

function E.Pennants:draw()
  local t = love.timer.getTime()
  local n = math.floor(math.abs(self.x2 - self.x1) / 9)
  R.flat({ 0, 0.7, 0.7 }, self.h)
  love.graphics.setColor(0.1, 0.1, 0.1, 1)
  local px, py
  for i = 0, n do
    local k = i / n
    local sag = math.sin(k * math.pi) * 8
    local x = U.lerp(self.x1, self.x2, k)
    local y = U.lerp(self.y1, self.y2, k) - self.h + sag
    if px then love.graphics.line(px, py, x, y) end
    px, py = x, y
  end
  for i = 1, n - 1 do
    local k = i / n
    local sag = math.sin(k * math.pi) * 8
    local x = math.floor(U.lerp(self.x1, self.x2, k))
    local y = math.floor(U.lerp(self.y1, self.y2, k) - self.h + sag)
    local sway = math.floor(math.sin(t * 2.3 + i * 0.9) * 1.5 + 0.5)
    local c = self.colors[i % #self.colors + 1]
    love.graphics.setColor(c[1], c[2], c[3], 1)
    love.graphics.polygon("fill", x - 2, y, x + 2, y, x + sway, y + 5)
  end
  love.graphics.setColor(1, 1, 1, 1)
end

-- ---------------------------------------------------------------- wires
-- power lines sagging between poles (drawn high so they cast no shadow)
E.Wire = Class:extend()

function E.Wire:new(x1, y1, x2, y2, h)
  self.x1, self.y1, self.x2, self.y2, self.h = x1, y1, x2, y2, h
  self.x = x1
  self.sortY = 1e6
end

function E.Wire:draw()
  R.flat({ 0, 0.5, 0.85 }, 0)
  love.graphics.setColor(0.05, 0.05, 0.06, 1)
  local px, py
  local n = 24
  for i = 0, n do
    local k = i / n
    local x = U.lerp(self.x1, self.x2, k)
    local y = U.lerp(self.y1, self.y2, k) - self.h + math.sin(k * math.pi) * 14
    if px then love.graphics.line(math.floor(px), math.floor(py), math.floor(x), math.floor(y)) end
    px, py = x, y
  end
  love.graphics.setColor(1, 1, 1, 1)
end

return E
