-- Title screen: the real street, slowly panning, under the logo.
local Class = require("lib.classic")
local G = require("src.g")
local R = require("src.core.renderer")
local Input = require("src.core.input")
local Camera = require("src.core.camera")
local Script = require("src.core.script")
local T = require("src.ui.theme")
local Game = require("src.game.game")

local Title = Class:extend()

function Title:enter()
  G.ui.reset()
  Script.clear()
  G.ui.hudVisible = false
  G.ui.hudAlpha = 0
  local Neighborhood = require("src.scenes.neighborhood")
  self.nb = Neighborhood()
  self.nb:build(false)
  self.world = self.nb.world
  G.world = nil
  self.camera = Camera.new(R.W, R.H)
  self.camera:setBounds(0, 0, self.world.w, self.world.h)
  self.t = 0
  self.sel = 1
  self.options = {
    { "New Game", function() self:newGame() end },
    { "Controls", function() G.showControls() end },
    { function() return love.window.getFullscreen() and "Windowed" or "Fullscreen" end, function() G.toggleFullscreen() end },
    { "Quit", function() love.event.quit() end },
  }
  G.audio.loop("amb", "amb_outdoor", 0.6)
  G.audio.loop("music", "drone", 0.5)
  R.fx.blur, R.fx.desat, R.fx.chroma, R.saturation = 0, 0, 0.6, 0.85
end

function Title:newGame()
  if self.starting then return end
  self.starting = true
  G.audio.play("ui_select", 0.6)
  G.audio.fadeOutAll()
  Game.reset()
  G.scenes.switch(G.sceneList.apartment, {}, { speed = 0.6 })
end

function Title:leave()
  self.starting = false
end

function Title:update(dt)
  self.t = self.t + dt
  self.world:update(dt)
  local x = 760 + math.sin(self.t * 0.035) * 320
  self.camera:snapTo(x, 400 + math.sin(self.t * 0.05) * 30)
  G.ui.update(dt)
  if G.ui.blocking() or self.starting then return end
  if Input.pressed("up") then self.sel = (self.sel - 2) % #self.options + 1; G.audio.play("ui_move", 0.4) end
  if Input.pressed("down") then self.sel = self.sel % #self.options + 1; G.audio.play("ui_move", 0.4) end
  if Input.pressed("interact") then
    Input.consume("interact")
    G.audio.play("ui_select", 0.5)
    self.options[self.sel][2]()
  end
end

function Title:draw()
  local cx, cy = self.camera:drawPos()
  R.beginWorld(cx, cy)
  self.world:draw(cx, cy)
  R.endWorld()
  local lights = {}
  for _, l in ipairs(self.world.lights) do lights[#lights + 1] = l end
  R.light(lights, self.world.ambient)
  self.nb.camera = self.camera
  R.postProcess(function() self.nb:fogOverlay() end)
end

function Title:drawUI()
  -- darken the left side so the logo reads
  for i = 0, 47 do
    love.graphics.setColor(0, 0, 0, 0.82 * (1 - i / 48))
    love.graphics.rectangle("fill", i * 10, 0, 10, 540)
  end
  local t = self.t
  love.graphics.setFont(T.fHuge)
  local jitter = (love.math.noise(t * 3) > 0.82) and 2 or 0
  love.graphics.setColor(0.6, 0.08, 0.08, 0.7)
  love.graphics.print("HOLLOW", 58 + jitter, 120)
  love.graphics.print("HOURS", 58 + jitter, 186)
  love.graphics.setColor(0.08, 0.3, 0.4, 0.5)
  love.graphics.print("HOLLOW", 54 - jitter, 120)
  love.graphics.print("HOURS", 54 - jitter, 186)
  T.setColor(T.col.text)
  love.graphics.print("HOLLOW", 56, 120)
  love.graphics.print("HOURS", 56, 186)
  love.graphics.setFont(T.fLabel)
  T.setColor(T.col.accent)
  love.graphics.print("PART I  -  EMPTY", 60, 268)
  love.graphics.setFont(T.fBody)
  for i, o in ipairs(self.options) do
    local sel = i == self.sel
    local label = type(o[1]) == "function" and o[1]() or o[1]
    T.setColor(sel and T.col.text or T.col.dim)
    love.graphics.print((sel and "> " or "  ") .. label, 60, 318 + (i - 1) * 34)
  end
  love.graphics.setFont(T.fBodySmall)
  T.setColor(T.col.dim, 0.7)
  love.graphics.print("Alder Street, 02:03 AM.  Best with headphones.", 60, 500)
  G.ui.draw()
end

return Title
