-- Face-to-face conversation screen (the interrogation mode).
-- The low-res layer shows the NPC (first person, AI-painted and pixelated);
-- this module draws the talk UI on top and routes input into the engine.
local G = require("src.g")
local T = require("src.ui.theme")
local A = require("src.core.assets")
local R = require("src.core.renderer")
local Input = require("src.core.input")
local U = require("src.core.util")
local Items = require("src.game.items")
local Engine = require("src.dialogue.engine")

local C = {}
C.__index = C

local CPS = 46

function C.open(script, opts)
  local self = setmetatable({}, C)
  self.conv = Engine.start(script, opts)
  self.script = script
  self.t = 0
  self.shown = 0
  self.sel = 1
  self.pickSel = 1
  self.lastLine = nil
  self.zoom = 0
  self.lineRef = nil
  G.audio.play("ui_open", 0.3)
  return self
end

function C:active() return self.conv.active end

function C:face()
  local c = self.conv
  return c.face or (self.script.face and self.script.face(c.npc, c)) or self.script.id
end

local function wrap(text, width)
  local _, lines = T.fBody:getWrap(text, width)
  return lines
end

function C:update(dt)
  local c = self.conv
  self.t = self.t + dt
  c:update(dt)
  local secretZoom = c.npc.flags.raw and 1 or 0
  self.zoom = U.approach(self.zoom, secretZoom, dt * 0.15)
  local line = c:line()
  if line ~= self.lineRef then
    self.lineRef = line
    self.shown = 0
  end
  if line then
    local before = math.floor(self.shown)
    self.shown = math.min(#line.text, self.shown + dt * CPS)
    if line.who == "npc" and math.floor(self.shown) ~= before and math.floor(self.shown) % 3 == 0 then
      G.audio.play("blip", 0.12, 0.75 + love.math.random() * 0.1)
    end
    if Input.pressed("interact") then
      Input.consume("interact")
      if self.shown < #line.text then
        self.shown = #line.text
      else
        if line.who ~= "you" then self.lastLine = line end
        c:advance()
        self.sel = 1
      end
    end
    return
  end
  if c.picking then
    local ids = G.state.invOrder
    local n = #ids + 1
    if Input.pressed("up") then self.pickSel = (self.pickSel - 2) % n + 1; G.audio.play("ui_move", 0.3) end
    if Input.pressed("down") then self.pickSel = self.pickSel % n + 1; G.audio.play("ui_move", 0.3) end
    if Input.pressed("cancel") or (Input.pressed("interact") and self.pickSel == n) then
      Input.consume("cancel"); Input.consume("interact"); Input.consume("pause")
      c.picking = false
      return
    end
    if Input.pressed("interact") then
      Input.consume("interact")
      G.audio.play("ui_select", 0.4)
      c:present(ids[self.pickSel])
      self.sel = 1
    end
    return
  end
  local ch = c.choices
  if ch and #ch > 0 then
    if Input.pressed("up") then self.sel = (self.sel - 2) % #ch + 1; G.audio.play("ui_move", 0.3) end
    if Input.pressed("down") then self.sel = self.sel % #ch + 1; G.audio.play("ui_move", 0.3) end
    self.sel = U.clamp(self.sel, 1, #ch)
    if Input.pressed("interact") then
      Input.consume("interact")
      G.audio.play("ui_select", 0.4)
      local pick = ch[self.sel]
      self.sel = 1
      self.pickSel = 1
      c:choose(pick)
    elseif Input.pressed("cancel") then
      Input.consume("cancel"); Input.consume("pause")
      for _, x in ipairs(ch) do
        if x.leave then c:choose(x) return end
      end
    end
  end
end

-- low-res layer: the NPC in front of you
function C:drawFace()
  local img = A.image("assets/gfx/faces/" .. self:face() .. ".png")
  love.graphics.setCanvas(R.lit)
  love.graphics.clear(0, 0, 0, 1)
  if img then
    local t = self.t
    -- breathing drift + flickering tube light
    -- whole-pixel drift only: any fractional scaling would smear the pixel art
    local z = 1
    local ox = math.floor(math.sin(t * 0.21) * 2 + 0.5)
    local oy = math.floor(math.sin(t * 0.33) * 1.5 + 0.5) - math.floor(self.zoom * 6 + 0.5)
    local fl = 0.93 + 0.07 * love.math.noise(t * 3.1, 4.2)
    if love.math.noise(t * 1.3, 9) > 0.86 then fl = fl * 0.75 end
    love.graphics.setColor(fl, fl, fl * 1.02, 1)
    local w, h = img:getDimensions()
    love.graphics.draw(img, R.W / 2 + ox, R.H * 0.42 + oy, 0, z * R.W / w, z * R.H / h, w / 2, h * 0.42)
  end
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setCanvas()
  R.fx.blur, R.fx.desat = 0, 0
  R.fx.glow = false          -- the painted face is already lit; bloom would blow it out
  R.postProcess()
  R.fx.glow = true
end

local function whoColor(who)
  if who == "narration" then return T.col.dim end
  if who == "you" then return T.col.thought end
  return T.col.text
end

function C:drawLine(line, x, y, w, partial)
  local text = line.text
  if line.who == "you" then text = "\"" .. text .. "\"" end
  local lines = wrap(text, w)
  local remaining = partial and math.floor(self.shown) + (line.who == "you" and 1 or 0) or #text
  love.graphics.setFont(T.fBody)
  T.setColor(whoColor(line.who))
  for i, l in ipairs(lines) do
    if remaining <= 0 then break end
    love.graphics.print(l:sub(1, remaining), x, y + (i - 1) * 27)
    remaining = remaining - #l - 1
  end
  return #lines * 27
end

function C:drawUI()
  local c = self.conv
  local npc = c.npc
  -- header: who you're talking to and how they seem
  local name = string.upper(self.script.name)
  love.graphics.setFont(T.fLabel)
  local mood = Engine.mood(npc.open)
  local hw = math.max(T.fLabel:getWidth(name), T.fBodySmall:getWidth("seems " .. mood)) + 40
  T.panel(24, 22, hw, 64, 0.9)
  T.setColor(T.col.accent)
  love.graphics.print(name, 40, 34)
  love.graphics.setFont(T.fBodySmall)
  T.setColor(T.col.dim)
  love.graphics.print("seems " .. mood, 40, 54)
  if c.deltaT > 0 then
    local a = U.clamp(c.deltaT, 0, 1)
    local msg = c.delta > 0 and "He lets his guard down a little." or "He pulls back."
    if self.script.id == "red" then msg = c.delta > 0 and "Something gives a little." or "She goes still." end
    love.graphics.setFont(T.fBodySmall)
    T.setColor(c.delta > 0 and T.col.good or T.col.danger, a)
    love.graphics.print(msg, 40 + hw, 44)
  end
  if npc.secret then
    love.graphics.setFont(T.fLabel)
    T.setColor(T.col.accent, 0.8)
    love.graphics.print("SECRET LEARNED", 960 - 24 - T.fLabel:getWidth("SECRET LEARNED"), 34)
  end

  -- bottom panel: the current line (or the last thing said)
  local x, y, w, h = 60, 392, 840, 132
  T.panel(x, y, w, h, 0.95)
  local line = c:line()
  if line then
    if line.who == "npc" then
      love.graphics.setFont(T.fLabel)
      T.setColor(T.col.accent)
      love.graphics.print(self.script.name, x + 22, y + 14)
    end
    self:drawLine(line, x + 22, y + 38, w - 60, true)
    if self.shown >= #line.text and math.floor(self.t * 2.5) % 2 == 0 then
      T.setColor(T.col.text)
      love.graphics.polygon("fill", x + w - 30, y + h - 24, x + w - 18, y + h - 24, x + w - 24, y + h - 17)
    end
  elseif self.lastLine then
    if self.lastLine.who == "npc" then
      love.graphics.setFont(T.fLabel)
      T.setColor(T.col.accent, 0.7)
      love.graphics.print(self.script.name, x + 22, y + 14)
    end
    love.graphics.setColor(1, 1, 1, 1)
    self:drawLine(self.lastLine, x + 22, y + 38, w - 60, false)
  end

  -- choices / item picker on the right
  local list
  if c.picking then
    list = {}
    for _, id in ipairs(G.state.invOrder) do
      local def = Items.get(id)
      list[#list + 1] = { text = def.name, icon = def.icon }
    end
    list[#list + 1] = { text = "(Never mind.)" }
  elseif not line and c.choices then
    list = c.choices
  end
  if list and #list > 0 then
    local sel = c.picking and self.pickSel or self.sel
    local rowH = 30
    local cw = 0
    love.graphics.setFont(T.fBody)
    for _, it in ipairs(list) do cw = math.max(cw, T.fBody:getWidth(it.text) + (it.icon and 34 or 0)) end
    cw = math.min(560, cw + 70)
    local ch = #list * rowH + 30
    local cx, cy = 960 - 40 - cw, y - ch - 10
    T.panel(cx, cy, cw, ch, 0.95)
    for i, it in ipairs(list) do
      local ry = cy + 15 + (i - 1) * rowH
      local isSel = i == sel
      if isSel then
        love.graphics.setColor(0.2, 0.15, 0.08, 0.85)
        love.graphics.rectangle("fill", cx + 8, ry - 2, cw - 16, rowH - 2)
        T.setColor(T.col.accent)
        love.graphics.rectangle("fill", cx + 8, ry - 2, 3, rowH - 2)
      end
      local tx = cx + 22
      if it.icon then
        T.icon(it.icon, tx, ry, 1)
        tx = tx + 34
      end
      local col = isSel and T.col.text or T.col.dim
      if it.leave or it.present then col = isSel and T.col.text or { 0.42, 0.4, 0.37, 1 } end
      T.setColor(col)
      love.graphics.print(it.text, tx, ry)
    end
    T.hints({ { "interact", c.picking and "Show it" or "Say it" }, { "cancel", c.picking and "Back" or "Leave" } }, x + 4, y - 32, 0.8)
  end
  love.graphics.setColor(1, 1, 1, 1)
end

return C
