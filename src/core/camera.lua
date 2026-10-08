local U = require("src.core.util")

local Camera = {}
Camera.__index = Camera

function Camera.new(w, h)
  return setmetatable({ x = 0, y = 0, w = w, h = h, bounds = nil, trauma = 0, t = 0, ox = 0, oy = 0, smooth = 6 }, Camera)
end

function Camera:setBounds(x, y, w, h)
  self.bounds = { x = x, y = y, w = w, h = h }
end

function Camera:clampPos(x, y)
  local b = self.bounds
  if not b then return x, y end
  if b.w <= self.w then x = b.x + (b.w - self.w) / 2 else x = U.clamp(x, b.x, b.x + b.w - self.w) end
  if b.h <= self.h then y = b.y + (b.h - self.h) / 2 else y = U.clamp(y, b.y, b.y + b.h - self.h) end
  return x, y
end

function Camera:snapTo(tx, ty)
  self.x, self.y = self:clampPos(tx - self.w / 2, ty - self.h / 2)
end

function Camera:follow(tx, ty, dt)
  local gx, gy = self:clampPos(tx - self.w / 2, ty - self.h / 2)
  local k = 1 - math.exp(-self.smooth * dt)
  self.x = self.x + (gx - self.x) * k
  self.y = self.y + (gy - self.y) * k
end

function Camera:shake(amount)
  self.trauma = math.min(1, self.trauma + amount)
end

function Camera:update(dt)
  self.t = self.t + dt
  self.trauma = math.max(0, self.trauma - dt * 0.9)
  local s = self.trauma * self.trauma
  self.ox = (love.math.noise(self.t * 9, 1) - 0.5) * 10 * s
  self.oy = (love.math.noise(self.t * 9, 7) - 0.5) * 10 * s
end

-- integer position used for drawing (prevents shimmering pixels)
function Camera:drawPos()
  return math.floor(self.x + self.ox + 0.5), math.floor(self.y + self.oy + 0.5)
end

return Camera
