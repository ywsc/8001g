-- SCENE 4 - placeholder. Reading the "wake up" note in the staff room sends
-- the player here. The scene itself has not been designed yet; this shows
-- where the story stands and returns to the title.
local Class = require("lib.classic")
local G = require("src.g")
local R = require("src.core.renderer")
local Input = require("src.core.input")
local Script = require("src.core.script")
local T = require("src.ui.theme")
local U = require("src.core.util")
local Game = require("src.game.game")

local S4 = Class:extend()

function S4:enter()
  G.ui.reset()
  Script.clear()
  G.ui.hudVisible = false
  self.t = 0
  self.leaving = false
  R.fx.blur, R.fx.desat, R.saturation = 0, 0, 0.85
  G.audio.loop("music", "drone", 0.6)
  local st = G.state
  local hm, suf = U.formatClock(st.clock)
  local secrets = 0
  for _, n in pairs(st.npcs or {}) do if n.secret then secrets = secrets + 1 end end
  local noticed = (Game.flag("gate_memory") and 1 or 0) + (Game.flag("saw_figure") and 1 or 0) +
      (Game.flag("saw_laptop") and 1 or 0) + (Game.flag("met_red") and 1 or 0)
  self.stats = {
    string.format("Time              %s %s", hm, suf),
    string.format("Secrets learned   %d", secrets),
    string.format("Things noticed    %d / 4", noticed),
  }
end

function S4:update(dt)
  self.t = self.t + dt
  G.ui.update(dt)
  if self.t > 7 and Input.pressed("interact") and not self.leaving then
    self.leaving = true
    G.audio.fadeOutAll()
    G.scenes.switch(G.sceneList.title, {}, { speed = 0.6 })
  end
end

function S4:draw()
  love.graphics.setCanvas(R.final)
  love.graphics.clear(0, 0, 0, 1)
  love.graphics.setCanvas()
end

function S4:drawUI()
  local t = self.t
  local a1 = U.clamp(t / 1.5, 0, 1) * U.clamp((4 - t) / 1, 0, 1)
  love.graphics.setFont(T.fHuge)
  T.setColor(T.col.thought, a1)
  love.graphics.printf("wake up", 0, 210, 960, "center")
  local a = U.clamp((t - 4.2) / 1.2, 0, 1)
  love.graphics.setFont(T.fTitle)
  T.setColor(T.col.accent, a)
  love.graphics.printf("SCENE 4", 0, 170, 960, "center")
  love.graphics.setFont(T.fBodySmall)
  T.setColor(T.col.dim, a)
  love.graphics.printf("This scene hasn't been written yet.", 0, 214, 960, "center")
  for i, s in ipairs(self.stats) do
    love.graphics.print(s, 360, 280 + (i - 1) * 24)
  end
  if t > 7 then
    T.hints({ { "interact", "Return to title" } }, 380, 440, 0.5 + 0.5 * math.sin(t * 3))
  end
  love.graphics.setColor(1, 1, 1, 1)
end

return S4
