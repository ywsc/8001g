local U = {}

function U.clamp(v, a, b) return v < a and a or (v > b and b or v) end
function U.lerp(a, b, t) return a + (b - a) * t end
function U.sign(v) return v > 0 and 1 or (v < 0 and -1 or 0) end

function U.approach(v, target, step)
  if v < target then return math.min(v + step, target) end
  return math.max(v - step, target)
end

function U.dist(x1, y1, x2, y2)
  local dx, dy = x2 - x1, y2 - y1
  return math.sqrt(dx * dx + dy * dy)
end

function U.pointInRect(px, py, x, y, w, h)
  return px >= x and px < x + w and py >= y and py < y + h
end

function U.rectsOverlap(ax, ay, aw, ah, bx, by, bw, bh)
  return ax < bx + bw and bx < ax + aw and ay < by + bh and by < ay + ah
end

-- distance from a point to a rectangle (0 when inside)
function U.distToRect(px, py, x, y, w, h)
  local dx = math.max(x - px, 0, px - (x + w))
  local dy = math.max(y - py, 0, py - (y + h))
  return math.sqrt(dx * dx + dy * dy)
end

-- smooth deterministic flicker in [0,1]
function U.flicker(t, seed)
  seed = seed or 0
  local a = math.sin(t * 13.1 + seed * 7.3) * 0.5 + math.sin(t * 7.7 + seed * 3.1) * 0.3 + math.sin(t * 23.3 + seed) * 0.2
  return a * 0.5 + 0.5
end

function U.formatClock(minutes)
  local m = math.floor(minutes) % (24 * 60)
  local h = math.floor(m / 60)
  local mm = m % 60
  local suffix = h < 12 and "AM" or "PM"
  local h12 = h % 12
  if h12 == 0 then h12 = 12 end
  return string.format("%02d:%02d", h12, mm), suffix
end

function U.shallowCopy(t)
  local o = {}
  for k, v in pairs(t) do o[k] = v end
  return o
end

return U
