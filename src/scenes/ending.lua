-- End of Part I: a few lines over black, a summary, back to the title.
local Class = require("lib.classic")
local G = require("src.g")
local R = require("src.core.renderer")
local Input = require("src.core.input")
local Script = require("src.core.script")
local T = require("src.ui.theme")
local U = require("src.core.util")
local Game = require("src.game.game")

local Ending = Class:extend()

local LINES = {
  "The fluorescent tubes hum one long note.",
  "Behind the counter, the stockroom door stands open.",
  "Something in there is chewing.",
}

function Ending:enter()
  G.ui.reset()
  Script.clear()
  G.ui.hudVisible = false
  self.t = 0
  R.fx.blur, R.fx.desat, R.saturation = 0, 0, 0.85
  G.audio.loop("music", "drone", 0.6)
  local st = G.state
  local found = 0
  for _ in pairs(st.inv) do found = found + 1 end
  local secrets = (Game.flag("gate_memory") and 1 or 0) + (Game.flag("saw_figure") and 1 or 0) + (Game.has("lock") and 1 or 0)
  local hm, suf = U.formatClock(st.clock)
  self.stats = {
    string.format("Arrived at        %s %s", hm, suf),
    string.format("Coins             %d", Game.count("coin")),
    string.format("Kinds of items    %d / 9", found),
    string.format("Things noticed    %d / 3", secrets),
  }
end

function Ending:update(dt)
  self.t = self.t + dt
  G.ui.update(dt)
  if self.t > 9 and Input.pressed("interact") and not self.leaving then
    self.leaving = true
    G.audio.fadeOutAll()
    G.scenes.switch(G.sceneList.title, {}, { speed = 0.6 })
  end
end

function Ending:draw()
  love.graphics.setCanvas(R.final)
  love.graphics.clear(0, 0, 0, 1)
  love.graphics.setCanvas()
end

function Ending:drawUI()
  local t = self.t
  love.graphics.setFont(T.fBody)
  for i, l in ipairs(LINES) do
    local a = U.clamp((t - (i - 1) * 1.6) / 1.2, 0, 1)
    T.setColor(T.col.thought, a)
    love.graphics.printf(l, 0, 120 + (i - 1) * 34, 960, "center")
  end
  local a = U.clamp((t - 5.5) / 1.5, 0, 1)
  love.graphics.setFont(T.fTitle)
  T.setColor(T.col.accent, a)
  love.graphics.printf("END OF PART I  -  EMPTY", 0, 270, 960, "center")
  love.graphics.setFont(T.fBodySmall)
  for i, s in ipairs(self.stats) do
    T.setColor(T.col.dim, a)
    love.graphics.print(s, 360, 320 + (i - 1) * 24)
  end
  if t > 9 then
    local blink = 0.5 + 0.5 * math.sin(t * 3)
    T.hints({ { "interact", "Return to title" } }, 380, 460, blink)
  end
  love.graphics.setFont(T.fBodySmall)
  T.setColor(T.col.dim, a * 0.8)
  love.graphics.printf("To be continued.", 0, 500, 960, "center")
  love.graphics.setColor(1, 1, 1, 1)
end

return Ending
