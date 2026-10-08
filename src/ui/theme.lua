local A = require("src.core.assets")
local Input = require("src.core.input")

local T = {}

T.col = {
  panel = { 0.035, 0.033, 0.04, 0.88 },
  border = { 0.36, 0.33, 0.29, 1 },
  borderDim = { 0.15, 0.14, 0.13, 1 },
  text = { 0.86, 0.83, 0.76, 1 },
  thought = { 0.80, 0.80, 0.84, 1 },
  dim = { 0.52, 0.50, 0.47, 1 },
  accent = { 0.86, 0.64, 0.30, 1 },
  danger = { 0.72, 0.18, 0.16, 1 },
  good = { 0.55, 0.72, 0.45, 1 },
  paper = { 0.50, 0.47, 0.40, 1 },
  ink = { 0.08, 0.07, 0.06, 1 },
}

function T.init()
  -- grit texture to keep flat panels from looking clean
  local d = love.image.newImageData(64, 64)
  d:mapPixel(function(x, y)
    local n = love.math.noise(x * 0.3, y * 0.3) * 0.5 + love.math.random() * 0.5
    return 1, 1, 1, n * 0.07
  end)
  T.grit = love.graphics.newImage(d)
  T.grit:setWrap("repeat", "repeat")
  T.gritQuad = love.graphics.newQuad(0, 0, 2048, 2048, 64, 64)
  T.fBody = A.font("body", 26)
  T.fBodySmall = A.font("body", 22)
  T.fLabel = A.font("small", 16)
  T.fLabelSmall = A.font("small", 8)
  T.fTitle = A.font("title", 32)
  T.fHuge = A.font("title", 64)
end

function T.setColor(c, a)
  love.graphics.setColor(c[1], c[2], c[3], (c[4] or 1) * (a or 1))
end

function T.panel(x, y, w, h, alpha, accent)
  alpha = alpha or 1
  x, y, w, h = math.floor(x), math.floor(y), math.floor(w), math.floor(h)
  T.setColor(T.col.panel, alpha)
  love.graphics.rectangle("fill", x, y, w, h)
  love.graphics.setScissor(x, y, w, h)
  love.graphics.setColor(1, 1, 1, alpha)
  love.graphics.draw(T.grit, T.gritQuad, x, y)
  love.graphics.setScissor()
  love.graphics.setLineWidth(2)
  love.graphics.setLineStyle("rough")
  T.setColor(T.col.borderDim, alpha)
  love.graphics.rectangle("line", x + 5, y + 5, w - 10, h - 10)
  T.setColor(accent or T.col.border, alpha)
  love.graphics.rectangle("line", x + 1, y + 1, w - 2, h - 2)
  -- chipped corners
  T.setColor({ 0, 0, 0, 1 }, alpha)
  love.graphics.rectangle("fill", x, y, 4, 4)
  love.graphics.rectangle("fill", x + w - 4, y + h - 4, 4, 4)
  love.graphics.setColor(1, 1, 1, 1)
end

local PAD_NAMES = { interact = "A", cancel = "B", inventory = "Y", flashlight = "X", takeall = "LB", pause = "START" }
local KEY_NAMES = { interact = "E", cancel = "ESC", inventory = "TAB", flashlight = "F", takeall = "R", pause = "ESC", run = "SHIFT" }

function T.keyName(action)
  if Input.usingGamepad() then return PAD_NAMES[action] or action end
  return KEY_NAMES[action] or action
end

-- keycap glyph; returns width
function T.key(action, x, y, alpha)
  alpha = alpha or 1
  local label = T.keyName(action)
  local f = T.fLabel
  local w = math.max(26, f:getWidth(label) + 12)
  T.setColor({ 0.12, 0.11, 0.1, 1 }, alpha * 0.95)
  love.graphics.rectangle("fill", x, y, w, 24, 3, 3)
  T.setColor(T.col.text, alpha)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", x + 1, y + 1, w - 2, 22, 3, 3)
  love.graphics.setFont(f)
  love.graphics.print(label, x + math.floor((w - f:getWidth(label)) / 2), y + 4)
  return w
end

-- "[E] Take  [R] Take all" style hint row; returns total width
function T.hints(list, x, y, alpha, measure)
  local cx = x
  love.graphics.setFont(T.fBodySmall)
  for _, h in ipairs(list) do
    local kw
    if measure then
      kw = math.max(26, T.fLabel:getWidth(T.keyName(h[1])) + 12)
    else
      kw = T.key(h[1], cx, y, alpha)
      T.setColor(T.col.dim, alpha)
      love.graphics.setFont(T.fBodySmall)
      love.graphics.print(h[2], cx + kw + 6, y)
    end
    cx = cx + kw + 6 + T.fBodySmall:getWidth(h[2]) + 18
  end
  love.graphics.setColor(1, 1, 1, 1)
  return cx - x - 18
end

function T.icon(name, x, y, scale, alpha)
  local img = A.icon(name)
  if not img then return end
  love.graphics.setColor(1, 1, 1, alpha or 1)
  love.graphics.draw(img, math.floor(x), math.floor(y), 0, scale, scale)
  love.graphics.setColor(1, 1, 1, 1)
end

return T
