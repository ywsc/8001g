-- Scene manager with fade-to-black transitions and a title-card overlay.
local G = require("src.g")
local T = require("src.ui.theme")
local U = require("src.core.util")

local SM = { current = nil, fade = 1, fadeTarget = 0, fadeSpeed = 1.2, pending = nil, card = nil }

function SM.switch(scene, args, opts)
  opts = opts or {}
  if SM.current == nil or opts.instant then
    if SM.current and SM.current.leave then SM.current:leave() end
    SM.current = scene
    scene:enter(args or {})
    SM.fadeTarget = 0
    return
  end
  SM.pending = { scene = scene, args = args or {} }
  SM.fadeTarget = 1
  SM.fadeSpeed = opts.speed or 1.2
end

-- a centred line of text over black, e.g. "02:03 AM"
function SM.showCard(text, sub, dur)
  SM.card = { text = text, sub = sub, t = 0, dur = dur or 3 }
end

function SM.update(dt)
  SM.fade = U.approach(SM.fade, SM.fadeTarget, dt * SM.fadeSpeed)
  if SM.pending and SM.fade >= 1 then
    local p = SM.pending
    SM.pending = nil
    if SM.current and SM.current.leave then SM.current:leave() end
    SM.current = p.scene
    p.scene:enter(p.args)
    SM.fadeTarget = 0
  end
  if SM.card then
    SM.card.t = SM.card.t + dt
    if SM.card.t > SM.card.dur then SM.card = nil end
  end
  if SM.current and SM.current.update then SM.current:update(dt) end
end

function SM.draw()
  if SM.current and SM.current.draw then SM.current:draw() end
end

-- drawn last on the UI canvas
function SM.drawOverlay()
  if SM.fade > 0.001 then
    love.graphics.setColor(0, 0, 0, SM.fade)
    love.graphics.rectangle("fill", 0, 0, 960, 540)
  end
  local c = SM.card
  if c then
    local a = U.clamp(math.min(c.t / 0.8, (c.dur - c.t) / 0.8), 0, 1)
    love.graphics.setFont(T.fTitle)
    T.setColor(T.col.text, a)
    love.graphics.printf(c.text, 0, 236, 960, "center")
    if c.sub then
      love.graphics.setFont(T.fBodySmall)
      T.setColor(T.col.dim, a)
      love.graphics.printf(c.sub, 0, 282, 960, "center")
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
end

return SM
