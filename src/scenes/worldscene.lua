-- Shared behaviour of playable scenes: input routing, camera, interaction
-- prompts, the render pipeline, pause menu and the faint/hunger effects.
local Class = require("lib.classic")
local G = require("src.g")
local R = require("src.core.renderer")
local Input = require("src.core.input")
local Camera = require("src.core.camera")
local Script = require("src.core.script")
local U = require("src.core.util")
local Game = require("src.game.game")

local WS = Class:extend()

function WS:new()
  self.camera = Camera.new(R.W, R.H)
  self.eyelid = 0          -- 0 open .. 1 closed
  self.faint = 0           -- 0..1 strength of the hunger blackout effect
  self.pulse = 0
  self.extraOverlay = nil
end

function WS:baseEnter()
  self.cutscene = false
  self.camTarget = nil
  self.faint = 0
  self.eyelid = 0
  G.ui.reset()
  Script.clear()
  G.world = self.world
  self.camera:setBounds(-8, -8, self.world.w + 16, self.world.h + 16)
  if self.world.player then self.camera:snapTo(self.world.player.x, self.world.player.y - 12) end
end

function WS:canAct()
  return not G.ui.blocking() and not self.cutscene and G.scenes.fadeTarget == 0 and
      self.world.player and self.world.player.state == "free"
end

function WS:openPause()
  local SM = G.scenes
  G.audio.play("ui_open", 0.5)
  G.ui.openMenu("PAUSED", {
    { "Resume", function() G.ui.close() end },
    { function() return love.window.getFullscreen() and "Windowed" or "Fullscreen" end, function() G.toggleFullscreen() end },
    { "Controls", function() G.ui.close(); G.showControls() end },
    { "Quit to title", function()
      G.ui.close()
      G.audio.fadeOutAll()
      SM.switch(G.sceneList.title)
    end },
    { "Quit game", function() love.event.quit() end },
  }, { cancel = function() G.ui.close() end })
end

function WS:update(dt)
  local world = self.world
  local pl = world.player
  Script.update(dt)
  Game.update(dt)

  -- global actions
  if Input.pressed("pause") and not G.ui.blocking() then
    Input.consume("pause"); Input.consume("cancel")
    self:openPause()
  end
  if self:canAct() then
    if Input.pressed("inventory") then
      Input.consume("inventory")
      G.ui.openInventory()
    end
    if Input.pressed("flashlight") then
      if Game.has("phone") then Game.toggleFlashlight() end
    end
  end

  world:update(dt)

  -- interaction
  G.ui.prompt = nil
  self.focus = nil
  if pl and self:canAct() then
    local fx, fy = pl:facingVec()
    local it = world:findInteract(pl.x, pl.y, fx, fy)
    if it then
      self.focus = it
      local cx, cy = self.camera:drawPos()
      local px = (it.promptX or (it.x + it.w / 2)) - cx
      local py = (it.promptY or it.y) - cy
      G.ui.prompt = { text = it.label, x = px * 2, y = py * 2 }
      if Input.pressed("interact") then
        Input.consume("interact")
        it.action(it)
      end
    end
  end

  -- camera
  if pl then
    local lead = 10
    local fx, fy = pl:facingVec()
    local tx, ty = pl.x + (pl.moving and fx * lead or 0), pl.y - 14 + (pl.moving and fy * lead or 0)
    if self.camTarget then tx, ty = self.camTarget[1], self.camTarget[2] end
    self.camera:follow(tx, ty, dt)
  end
  self.camera:update(dt)

  -- hunger / faint post effects
  local st = G.state
  self.pulse = self.pulse + dt
  local starving = st.hunger >= 88 and 1 or 0
  local wave = starving * math.max(0, math.sin(self.pulse * 0.9)) ^ 6 * 0.6
  local f = math.max(self.faint, wave)
  R.fx.blur = f * 2.2
  R.fx.desat = f * 0.8
  R.fx.vignette = 0.75 + f * 0.25
  R.fx.chroma = 0.6 + f * 3
  R.saturation = 0.85 - f * 0.4
  if pl then pl.speedMul = 1 - f * 0.45 end
  G.ui.update(dt)
end

function WS:collectLights()
  local lights = {}
  local pl = self.world.player
  if pl and G.state.flashlight and Game.has("phone") and pl.state ~= "lying" then
    lights[#lights + 1] = pl:flashlight()
  end
  for _, l in ipairs(self.world.lights) do lights[#lights + 1] = l end
  -- faint personal fill so the player never fully disappears into the dark
  if pl and not pl.hidden then
    lights[#lights + 1] = { x = pl.x, y = pl.y + 14, z = 22, r = 46, color = { 0.55, 0.6, 0.75 }, intensity = 0.32, shadows = false }
  end
  return lights
end

function WS:drawOverlayLowRes()
  -- eyelids (black bars closing from top and bottom)
  if self.eyelid > 0.001 then
    local h = math.floor(R.H / 2 * self.eyelid + 0.5)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, R.W, h)
    love.graphics.rectangle("fill", 0, R.H - h, R.W, h)
    love.graphics.setColor(1, 1, 1, 1)
  end
  if self.faint > 0.01 then
    love.graphics.setColor(0, 0, 0, self.faint * 0.35)
    love.graphics.rectangle("fill", 0, 0, R.W, R.H)
    love.graphics.setColor(1, 1, 1, 1)
  end
end

function WS:draw()
  if G.ui.inConversation() then
    G.ui.conv:drawFace()
    return
  end
  local cx, cy = self.camera:drawPos()
  R.beginWorld(cx, cy)
  self.world:draw(cx, cy)
  if self.drawWorldExtra then self:drawWorldExtra() end
  R.endWorld()
  R.light(self:collectLights(), self.world.ambient)
  R.postProcess(self.extraOverlay)
  R.beginFinal()
  self:drawOverlayLowRes()
  R.endFinal()
end

-- walk the player to a point (used by cutscenes); returns when arrived
function WS:walkTo(x, y, timeout)
  local pl = self.world.player
  local t = 0
  Script.waitUntil(function()
    local dx, dy = x - pl.x, y - pl.y
    local d = math.sqrt(dx * dx + dy * dy)
    t = t + Script.dt
    if d < 2 or t > (timeout or 6) then
      pl.autoMove = nil
      return true
    end
    pl.autoMove = { dx / d, dy / d }
    return false
  end)
end

return WS
