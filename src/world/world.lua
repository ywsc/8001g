-- A playable map: background sprite, props, dynamic entities (y-sorted),
-- collision (bump), interactables, triggers and lights.
local Class = require("lib.classic")
local bump = require("lib.bump")
local A = require("src.core.assets")
local R = require("src.core.renderer")
local U = require("src.core.util")

local World = Class:extend()

function World:new(w, h)
  self.w, self.h = w, h
  self.bump = bump.newWorld(32)
  self.props = {}
  self.entities = {}
  self.interacts = {}
  self.triggers = {}
  self.lights = {}
  self.time = 0
  self.ambient = { 0.05, 0.05, 0.07 }
  self.surface = function() return "wood" end
end

-- ------------------------------------------------------------------ geometry
function World:addSolid(x, y, w, h, tag)
  local box = { solid = true, tag = tag or "wall" }
  self.bump:add(box, x, y, w, h)
  return box
end

-- merge horizontal runs of solid cells into rectangles
function World:solidsFromGrid(grid, tile, isSolid)
  for y, row in ipairs(grid) do
    local x = 1
    while x <= #row do
      if isSolid(row:sub(x, x)) then
        local x2 = x
        while x2 + 1 <= #row and isSolid(row:sub(x2 + 1, x2 + 1)) do x2 = x2 + 1 end
        self:addSolid((x - 1) * tile, (y - 1) * tile, (x2 - x + 1) * tile, tile)
        x = x2 + 1
      else
        x = x + 1
      end
    end
  end
  -- map border
  self:addSolid(-16, -16, self.w + 32, 16)
  self:addSolid(-16, self.h, self.w + 32, 16)
  self:addSolid(-16, 0, 16, self.h)
  self:addSolid(self.w, 0, 16, self.h)
end

function World.loadGrid(path)
  local rows = {}
  for line in love.filesystem.lines(path) do
    if #line > 0 then rows[#rows + 1] = line end
  end
  return rows
end

-- ------------------------------------------------------------------ props
-- def: sprite (path), x, y, collider {ox,oy,w,h}, frames, fps, baseH, emit,
--      layer ("floor"|nil), sortY, visible, id
function World:addProp(def)
  local p = U.shallowCopy(def)
  p.isProp = true
  p.spr = A.sprite(def.sprite)
  if def.frames and def.frames > 1 then
    p.quads = A.frames(p.spr, def.frames)
    p.fw = p.spr.w / def.frames
  else
    p.fw = p.spr.w
  end
  p.fh = p.spr.h
  p.frame = 1
  p.visible = def.visible ~= false
  p.emit = def.emit or 1
  p.sortY = def.sortY or (def.y + p.fh - (def.foot or 0))
  if def.collider then
    local c = def.collider
    p.box = self:addSolid(def.x + c[1], def.y + c[2], c[3], c[4], "prop")
  end
  table.insert(self.props, p)
  if def.id then self.props[def.id] = p end
  return p
end

function World:setPropSprite(p, path)
  p.spr = A.sprite(path)
  p.fw, p.fh = p.spr.w, p.spr.h
end

function World:addEntity(e)
  table.insert(self.entities, e)
  e.world = self
  return e
end

function World:removeEntity(e)
  for i, v in ipairs(self.entities) do
    if v == e then table.remove(self.entities, i) return end
  end
end

-- ------------------------------------------------------------------ interaction
-- def: x,y,w,h, label, action(), enabled() -> bool, priority
function World:addInteract(def)
  def.enabled = def.enabled or function() return true end
  table.insert(self.interacts, def)
  if def.id then self.interacts[def.id] = def end
  return def
end

function World:findInteract(px, py, fx, fy)
  local probeX, probeY = px + fx * 10, py - 4 + fy * 10
  local best, bestD = nil, 1e9
  for _, it in ipairs(self.interacts) do
    if it.enabled() then
      local d1 = U.distToRect(probeX, probeY, it.x, it.y, it.w, it.h)
      local d2 = U.distToRect(px, py - 3, it.x, it.y, it.w, it.h)
      local d = math.min(d1, d2 + 3) - (it.priority or 0)
      if (d1 < 9 or d2 < 7) and d < bestD then best, bestD = it, d end
    end
  end
  return best
end

-- def: x,y,w,h, once (default true), fn(), enabled()
function World:addTrigger(def)
  if def.once == nil then def.once = true end
  def.enabled = def.enabled or function() return true end
  table.insert(self.triggers, def)
  return def
end

-- ------------------------------------------------------------------ lights
-- def: x,y (ground), z, r, color, intensity, flicker ("soft"|"broken"|"dying"|fn), seed, halo, shadows, spot
function World:addLight(def)
  def.base = def.intensity or 1
  def.intensity = def.base
  def.seed = def.seed or love.math.random() * 100
  def.on = def.on ~= false
  table.insert(self.lights, def)
  if def.id then self.lights[def.id] = def end
  return def
end

local function flickerValue(l, t)
  local f = l.flicker
  if not f then return 1 end
  if type(f) == "function" then return f(t, l) end
  local s = l.seed
  if f == "soft" then
    return 0.92 + 0.08 * U.flicker(t * 0.6, s)
  elseif f == "broken" then
    -- mostly on, stutters off in bursts
    local burst = love.math.noise(t * 0.7, s)
    if burst > 0.72 then
      return (love.math.noise(t * 30, s + 3) > 0.5) and 1 or 0.05
    end
    return 0.94 + 0.06 * U.flicker(t, s)
  elseif f == "dying" then
    local n = love.math.noise(t * 2.2, s)
    if n < 0.3 then return 0.15 + n end
    return 0.75 + 0.25 * U.flicker(t * 1.5, s)
  elseif f == "tv" then
    return 0.55 + 0.45 * love.math.noise(t * 14, s)
  end
  return 1
end

-- ------------------------------------------------------------------ update/draw
function World:update(dt)
  self.time = self.time + dt
  for _, l in ipairs(self.lights) do
    l.mult = l.on and flickerValue(l, self.time) or 0
    l.intensity = l.base * l.mult
  end
  for _, p in ipairs(self.props) do
    if p.quads and p.fps then
      p.frame = math.floor(self.time * p.fps) % #p.quads + 1
    end
    if p.lightLink then p.emit = (p.emitBase or 1) * p.lightLink.mult end
  end
  for i = #self.entities, 1, -1 do
    local e = self.entities[i]
    if e.update then e:update(dt, self) end
    if e.dead then table.remove(self.entities, i) end
  end
  local pl = self.player
  if pl then
    for _, tr in ipairs(self.triggers) do
      if not tr.done and tr.enabled() and U.pointInRect(pl.x, pl.y, tr.x, tr.y, tr.w, tr.h) then
        if tr.once then tr.done = true end
        tr.fn(tr)
      end
    end
  end
end

function World:draw(camx, camy)
  if self.bg then R.drawSprite(self.bg, 0, 0) end
  local list = {}
  local vx0, vy0, vx1, vy1 = camx - 64, camy - 64, camx + R.W + 64, camy + R.H + 200
  for _, p in ipairs(self.props) do
    if p.visible and p.x < vx1 and p.x + p.fw > vx0 and p.y < vy1 and p.y + p.fh > vy0 then
      if p.layer == "floor" then
        self:drawProp(p)
      else
        list[#list + 1] = p
      end
    end
  end
  for _, e in ipairs(self.entities) do
    if e.drawFloor then e:drawFloor() end
    list[#list + 1] = e
  end
  table.sort(list, function(a, b)
    if a.sortY == b.sortY then return (a.x or 0) < (b.x or 0) end
    return a.sortY < b.sortY
  end)
  for _, d in ipairs(list) do
    if d.isProp then self:drawProp(d) else d:draw() end
  end
end

function World:drawProp(p)
  R.drawSprite(p.spr, p.x, p.y, {
    quad = p.quads and p.quads[p.frame],
    quadW = p.fw,
    baseH = p.baseH,
    emit = p.emit,
    sx = p.flip and -1 or 1,
  })
end

return World
