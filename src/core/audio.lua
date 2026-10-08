-- Tiny audio manager. Every call is guarded: the game must keep running on
-- machines (and CI containers) without an audio device.
local Au = { cache = {}, loops = {}, master = 0.9, sfxVol = 1, musicVol = 0.8, enabled = true }

local function load(name, kind)
  local key = name .. ":" .. kind
  if Au.cache[key] ~= nil then return Au.cache[key] end
  local src = false
  for _, ext in ipairs({ ".ogg", ".wav" }) do
    local path = "assets/sfx/" .. name .. ext
    if love.filesystem.getInfo(path) then
      local ok, s = pcall(love.audio.newSource, path, kind)
      if ok then src = s end
      break
    end
  end
  Au.cache[key] = src
  return src
end

function Au.init()
  local ok = pcall(function() love.audio.setVolume(Au.master) end)
  Au.enabled = ok and love.audio ~= nil
  Au.played = {}
end

function Au.play(name, vol, pitch)
  Au.played[#Au.played + 1] = name
  if #Au.played > 64 then table.remove(Au.played, 1) end
  if not Au.enabled then return end
  local s = load(name, "static")
  if not s then return end
  local ok, c = pcall(function() return s:clone() end)
  if not ok then return end
  pcall(function()
    c:setVolume((vol or 1) * Au.sfxVol)
    c:setPitch(pitch or 1)
    c:play()
  end)
  return c
end

-- looping ambience; `id` lets callers manage several layers
function Au.loop(id, name, vol)
  local cur = Au.loops[id]
  if cur and cur.name == name then
    cur.target = vol or 1
    return cur
  end
  if cur then Au.stopLoop(id) end
  local entry = { name = name, vol = 0, target = vol or 1, src = nil }
  if Au.enabled then
    local s = load(name, "stream")
    if s then
      local ok, c = pcall(function() return s:clone() end)
      if ok then
        entry.src = c
        pcall(function()
          c:setLooping(true)
          c:setVolume(0)
          c:play()
        end)
      end
    end
  end
  Au.loops[id] = entry
  return entry
end

function Au.setLoopVolume(id, vol)
  local l = Au.loops[id]
  if l then l.target = vol end
end

function Au.stopLoop(id)
  local l = Au.loops[id]
  if l and l.src then pcall(function() l.src:stop() end) end
  Au.loops[id] = nil
end

function Au.fadeOutAll()
  for _, l in pairs(Au.loops) do l.target = 0; l.dying = true end
end

function Au.update(dt)
  for id, l in pairs(Au.loops) do
    local speed = dt * 0.8
    if l.vol < l.target then l.vol = math.min(l.target, l.vol + speed) else l.vol = math.max(l.target, l.vol - speed) end
    if l.src then pcall(function() l.src:setVolume(l.vol * Au.musicVol) end) end
    if l.dying and l.vol <= 0 then Au.stopLoop(id) end
  end
end

-- volume falloff for positional one-shots
function Au.atten(dx, dy, radius)
  local d = math.sqrt(dx * dx + dy * dy)
  return math.max(0, 1 - d / radius)
end

return Au
