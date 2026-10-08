-- Lazy asset cache. A "sprite" bundles the four maps produced by
-- tools/gen_assets.py: name.png (albedo), name_n.png, name_h.png, name_e.png.
local A = { sprites = {}, fonts = {}, sounds = {}, icons = {} }

local function img(path)
  if love.filesystem.getInfo(path) then
    local i = love.graphics.newImage(path)
    i:setFilter("nearest", "nearest")
    return i
  end
end

function A.sprite(path)
  local s = A.sprites[path]
  if s then return s end
  local image = img("assets/gfx/" .. path .. ".png")
  assert(image, "missing sprite: " .. path)
  s = {
    image = image,
    normal = img("assets/gfx/" .. path .. "_n.png"),
    height = img("assets/gfx/" .. path .. "_h.png"),
    emit = img("assets/gfx/" .. path .. "_e.png"),
    w = image:getWidth(),
    h = image:getHeight(),
    name = path,
  }
  A.sprites[path] = s
  return s
end

-- horizontal strip of `n` frames -> list of quads
function A.frames(spr, n, fw, fh, row)
  fw = fw or spr.w / n
  fh = fh or spr.h
  row = row or 0
  local q = {}
  for i = 0, n - 1 do
    q[i + 1] = love.graphics.newQuad(i * fw, row * fh, fw, fh, spr.w, spr.h)
  end
  return q
end

function A.icon(name)
  local i = A.icons[name]
  if i == nil then
    i = img("assets/gfx/items/" .. name .. ".png") or false
    A.icons[name] = i
  end
  return i or nil
end

function A.image(path)
  local key = "img:" .. path
  if A.icons[key] == nil then A.icons[key] = img(path) or false end
  return A.icons[key] or nil
end

local FONT_FILES = {
  body = "assets/fonts/VT323-Regular.ttf",
  title = "assets/fonts/PixelifySans.ttf",
  small = "assets/fonts/Silkscreen-Regular.ttf",
}

function A.font(kind, size)
  local key = kind .. size
  local f = A.fonts[key]
  if not f then
    f = love.graphics.newFont(FONT_FILES[kind], size, "mono")
    f:setFilter("nearest", "nearest")
    A.fonts[key] = f
  end
  return f
end

return A
