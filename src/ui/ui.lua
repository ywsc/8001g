-- All 2D interface: dialogue, HUD, toasts, prompts and modal screens.
-- Drawn on the 960x540 UI canvas (2x the world resolution).
local G = require("src.g")
local T = require("src.ui.theme")
local Input = require("src.core.input")
local U = require("src.core.util")
local Items = require("src.game.items")

local UI = {}

-- ============================================================================
-- dialogue
-- ============================================================================
local D = { active = false, queue = {}, cur = nil, shown = 0, t = 0, cps = 42, choice = 1, blipAcc = 0 }
UI.dialogue = D

local function normLine(l)
  if type(l) == "string" then return { text = l, style = "thought" } end
  l.style = l.style or "thought"
  return l
end

function UI.say(lines, onDone)
  if type(lines) == "string" then lines = { lines } end
  for i, l in ipairs(lines) do
    local nl = normLine(l)
    if i == #lines then nl.onDone = onDone end
    table.insert(D.queue, nl)
  end
  if not D.active then UI.nextLine() end
end

function UI.nextLine()
  local prev = D.cur
  D.cur = table.remove(D.queue, 1)
  if prev and prev.onDone then prev.onDone() end
  if D.cur then
    D.active = true
    D.shown, D.t, D.choice = 0, 0, 1
    local f = T.fBody
    local _, wrapped = f:getWrap(D.cur.text, 660)
    D.lines = wrapped
    D.len = #D.cur.text
  elseif #D.queue == 0 then
    D.active = false
  end
end

local function updateDialogue(dt)
  local c = D.cur
  if not c then D.active = false return end
  D.t = D.t + dt
  local before = math.floor(D.shown)
  D.shown = math.min(D.len, D.shown + dt * D.cps * (c.speed or 1))
  if math.floor(D.shown) ~= before then
    D.blipAcc = D.blipAcc + (math.floor(D.shown) - before)
    if D.blipAcc >= 3 and G.audio then
      D.blipAcc = 0
      local ch = c.text:sub(math.floor(D.shown), math.floor(D.shown))
      if ch:match("%w") then G.audio.play("blip", 0.18, 0.9 + love.math.random() * 0.2) end
    end
  end
  local done = D.shown >= D.len
  if done and c.choices then
    if Input.pressed("up") then D.choice = (D.choice - 2) % #c.choices + 1; G.audio.play("ui_move", 0.4) end
    if Input.pressed("down") then D.choice = D.choice % #c.choices + 1; G.audio.play("ui_move", 0.4) end
  end
  if Input.pressed("interact") or (c.auto and done and D.t > D.len / D.cps + c.auto) then
    Input.consume("interact")
    if not done then
      D.shown = D.len
    else
      local pick = c.choices and c.choices[D.choice]
      G.audio.play("ui_select", 0.35)
      UI.nextLine()
      if pick and pick[2] then pick[2]() end
    end
  end
end

local function drawDialogue()
  local c = D.cur
  if not c then return end
  local x, y, w, h = 130, 402, 700, 120
  T.panel(x, y, w, h, 0.97)
  local col = c.style == "thought" and T.col.thought or (c.style == "system" and T.col.accent or T.col.dim)
  love.graphics.setFont(T.fBody)
  local remaining = math.floor(D.shown)
  local ly = y + 18
  for _, line in ipairs(D.lines) do
    if remaining <= 0 then break end
    local part = line:sub(1, remaining)
    remaining = remaining - #line
    -- skip the whitespace consumed by wrapping
    if remaining > 0 then remaining = remaining - 1 end
    T.setColor(col)
    love.graphics.print(part, x + 22, ly)
    ly = ly + 27
  end
  if c.speaker then
    love.graphics.setFont(T.fLabel)
    local sw = T.fLabel:getWidth(c.speaker) + 20
    T.panel(x + 16, y - 16, sw, 26, 1, T.col.accent)
    T.setColor(T.col.accent)
    love.graphics.print(c.speaker, x + 26, y - 11)
  end
  if D.shown >= D.len then
    if c.choices then
      local cy = y + h - 12 - #c.choices * 26
      for i, ch in ipairs(c.choices) do
        local sel = i == D.choice
        T.setColor(sel and T.col.accent or T.col.dim)
        love.graphics.setFont(T.fBody)
        love.graphics.print((sel and "> " or "  ") .. ch[1], x + w - 230, cy + (i - 1) * 26)
      end
    elseif math.floor(D.t * 2.5) % 2 == 0 then
      T.setColor(T.col.text)
      love.graphics.polygon("fill", x + w - 30, y + h - 26, x + w - 18, y + h - 26, x + w - 24, y + h - 19)
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================================
-- toasts, banner, prompt
-- ============================================================================
local toasts = {}
local banner = nil
UI.prompt = nil
UI.hudAlpha = 1
UI.hudVisible = false
UI.flashObjective = 0

function UI.toast(text, icon)
  table.insert(toasts, 1, { text = text, icon = icon, t = 0 })
  if #toasts > 4 then table.remove(toasts) end
end

function UI.objectiveUpdated(text)
  banner = { text = text or "Objective updated", t = 0 }
  UI.flashObjective = 1.5
  if G.audio then G.audio.play("objective", 0.6) end
end

local function drawToasts()
  local y = 128
  for i, t in ipairs(toasts) do
    local a = U.clamp(math.min(t.t * 5, (3.4 - t.t) * 2), 0, 1)
    local slide = (1 - U.clamp(t.t * 6, 0, 1)) * 40
    love.graphics.setFont(T.fBodySmall)
    local w = T.fBodySmall:getWidth(t.text) + (t.icon and 50 or 24)
    local x = 960 - 18 - w + slide
    T.panel(x, y, w, 36, a * 0.95)
    if t.icon then T.icon(t.icon, x + 8, y + 6, 1, a) end
    T.setColor(T.col.text, a)
    love.graphics.print(t.text, x + (t.icon and 40 or 12), y + 7)
    y = y + 42
  end
  love.graphics.setColor(1, 1, 1, 1)
end

local function drawBanner()
  if not banner then return end
  local t = banner.t
  local a = U.clamp(math.min(t * 3, (3 - t) * 1.5), 0, 1)
  love.graphics.setFont(T.fLabel)
  local txt = string.upper(banner.text)
  local w = T.fLabel:getWidth(txt)
  T.setColor({ 0, 0, 0, 0.6 }, a)
  love.graphics.rectangle("fill", 480 - w / 2 - 30, 70, w + 60, 30)
  T.setColor(T.col.accent, a)
  love.graphics.rectangle("fill", 480 - w / 2 - 30, 70, w + 60, 2)
  love.graphics.rectangle("fill", 480 - w / 2 - 30, 98, w + 60, 2)
  love.graphics.print(txt, math.floor(480 - w / 2), 77)
  love.graphics.setColor(1, 1, 1, 1)
end

local function drawPrompt(a)
  local p = UI.prompt
  if not p then return end
  love.graphics.setFont(T.fBodySmall)
  local kw = math.max(26, T.fLabel:getWidth(T.keyName("interact")) + 12)
  local w = kw + 8 + T.fBodySmall:getWidth(p.text)
  local x = math.floor(U.clamp(p.x - w / 2, 8, 952 - w))
  local y = math.floor(U.clamp(p.y - 30, 8, 500))
  T.setColor({ 0, 0, 0, 0.55 }, a)
  love.graphics.rectangle("fill", x - 6, y - 4, w + 12, 32, 4, 4)
  T.key("interact", x, y, a)
  T.setColor(T.col.text, a)
  love.graphics.setFont(T.fBodySmall)
  love.graphics.print(p.text, x + kw + 8, y)
  love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================================
-- HUD
-- ============================================================================
local function drawObjective(a)
  local Game = require("src.game.game")
  local st = G.state
  if not st or st.stage > 2 then return end
  local list = Game.objectives()
  local title = Game.STAGES[st.stage].title
  local w = 330
  local h = 62 + #list * 26
  local flash = U.clamp(UI.flashObjective, 0, 1)
  local accent = flash > 0 and { U.lerp(0.36, 0.86, flash), U.lerp(0.33, 0.64, flash), U.lerp(0.29, 0.3, flash), 1 } or nil
  T.panel(14, 14, w, h, a * 0.92, accent)
  love.graphics.setFont(T.fLabel)
  T.setColor(T.col.accent, a)
  love.graphics.print("OBJECTIVE", 30, 26)
  love.graphics.setFont(T.fBody)
  T.setColor(T.col.text, a)
  love.graphics.print(title, 30, 44)
  local y = 74
  love.graphics.setFont(T.fBodySmall)
  for _, o in ipairs(list) do
    if o.sep then
      T.setColor(T.col.dim, a)
      love.graphics.print(o.text, 58, y)
    else
      T.setColor(o.done and T.col.good or T.col.dim, a)
      love.graphics.setLineWidth(2)
      love.graphics.rectangle("line", 32, y + 5, 14, 14)
      if o.done then
        love.graphics.line(35, y + 12, 39, y + 16, 45, y + 7)
      end
      T.setColor(o.done and T.col.dim or T.col.text, a)
      love.graphics.print(o.text, 56, y)
      if o.done then
        love.graphics.setColor(T.col.dim[1], T.col.dim[2], T.col.dim[3], a * 0.8)
        love.graphics.rectangle("fill", 56, y + 12, T.fBodySmall:getWidth(o.text), 2)
      end
    end
    y = y + 26
  end
  love.graphics.setColor(1, 1, 1, 1)
end

local function drawClock(a)
  local Game = require("src.game.game")
  local st = G.state
  if not st then return end
  local hm, suffix = U.formatClock(st.clock)
  local x, w = 960 - 14 - 200, 200
  T.panel(x, 14, w, 98, a * 0.92)
  love.graphics.setFont(T.fTitle)
  local blink = math.floor(love.timer.getTime() * 1.2) % 2 == 0
  local txt = blink and hm or hm:gsub(":", " ")
  T.setColor(T.col.text, a)
  love.graphics.print(txt, x + 18, 18)
  love.graphics.setFont(T.fLabel)
  T.setColor(T.col.dim, a)
  love.graphics.print(suffix, x + 26 + T.fTitle:getWidth("00:00"), 34)
  -- hunger
  local hv = st.hunger / 100
  local label = Game.hungerLabel()
  love.graphics.setFont(T.fBodySmall)
  local pulse = hv > 0.85 and (0.6 + 0.4 * math.sin(love.timer.getTime() * 6)) or 1
  T.setColor(hv > 0.85 and T.col.danger or T.col.dim, a * pulse)
  love.graphics.print(label, x + 18, 58)
  love.graphics.setColor(0.08, 0.06, 0.06, a)
  love.graphics.rectangle("fill", x + 18, 88, w - 36, 8)
  T.setColor(T.col.danger, a * pulse)
  love.graphics.rectangle("fill", x + 18, 88, (w - 36) * hv, 8)
  -- status icons
  local ix = x + w - 26
  if st.flashlight then
    T.icon("phone", ix - 4, 56, 1, a)
    ix = ix - 30
  end
  if st.equipped == "knife" then T.icon("knife", ix - 4, 56, 1, a) end
  love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================================
-- modals
-- ============================================================================
UI.modal = nil

function UI.blocking()
  return D.active or UI.modal ~= nil
end

function UI.close()
  if UI.modal and UI.modal.onClose then UI.modal.onClose() end
  UI.modal = nil
end

local function menuNav(sel, n, horiz)
  local prevK, nextK = horiz and "left" or "up", horiz and "right" or "down"
  if Input.pressed(prevK) then sel = (sel - 2) % n + 1; G.audio.play("ui_move", 0.4) end
  if Input.pressed(nextK) then sel = sel % n + 1; G.audio.play("ui_move", 0.4) end
  return sel
end

-- ---------------------------------------------------------------- inventory
local Inventory = {}
Inventory.__index = Inventory

function UI.openInventory()
  G.audio.play("ui_open", 0.5)
  UI.modal = setmetatable({ kind = "inventory", sel = 1, t = 0 }, Inventory)
end

function Inventory:update(dt)
  self.t = self.t + dt
  local ids = G.state.invOrder
  local n = math.max(1, #ids)
  local cols = 4
  if Input.pressed("left") then self.sel = math.max(1, self.sel - 1); G.audio.play("ui_move", 0.4) end
  if Input.pressed("right") then self.sel = math.min(n, self.sel + 1); G.audio.play("ui_move", 0.4) end
  if Input.pressed("up") and self.sel - cols >= 1 then self.sel = self.sel - cols; G.audio.play("ui_move", 0.4) end
  if Input.pressed("down") and self.sel + cols <= n then self.sel = self.sel + cols; G.audio.play("ui_move", 0.4) end
  self.sel = U.clamp(self.sel, 1, n)
  if Input.pressed("cancel") or Input.pressed("inventory") then
    Input.consume("cancel"); Input.consume("pause")
    G.audio.play("ui_close", 0.5)
    UI.close()
    return
  end
  if Input.pressed("interact") and ids[self.sel] then
    Input.consume("interact")
    local Game = require("src.game.game")
    local id = ids[self.sel]
    local def = Items.get(id)
    if def.use then
      Game.useItem(id)
    else
      Game.say({ def.desc })
    end
  end
end

function Inventory:draw()
  local ids = G.state.invOrder
  love.graphics.setColor(0, 0, 0, 0.55)
  love.graphics.rectangle("fill", 0, 0, 960, 540)
  local x, y, w, h = 150, 96, 660, 330
  T.panel(x, y, w, h, 1)
  love.graphics.setFont(T.fLabel)
  T.setColor(T.col.accent)
  love.graphics.print("INVENTORY", x + 22, y + 16)
  local cols, size, gap = 4, 64, 10
  for i = 1, 12 do
    local cx = x + 22 + ((i - 1) % cols) * (size + gap)
    local cy = y + 48 + math.floor((i - 1) / cols) * (size + gap)
    love.graphics.setColor(0.07, 0.065, 0.06, 1)
    love.graphics.rectangle("fill", cx, cy, size, size)
    local sel = i == self.sel and ids[i]
    T.setColor(sel and T.col.accent or T.col.borderDim)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", cx + 1, cy + 1, size - 2, size - 2)
    local id = ids[i]
    if id then
      local def = Items.get(id)
      T.icon(def.icon, cx + 8, cy + 8, 2)
      local n = G.state.inv[id]
      if n and n > 1 then
        love.graphics.setFont(T.fLabel)
        T.setColor(T.col.text)
        love.graphics.print("x" .. n, cx + size - 26, cy + size - 20)
      end
      if G.state.equipped == id then
        love.graphics.setFont(T.fLabelSmall)
        T.setColor(T.col.good)
        love.graphics.print("EQUIPPED", cx + 4, cy + 4)
      end
    end
  end
  -- details
  local dx = x + 22 + cols * (size + gap) + 12
  local dw = x + w - dx - 22
  local id = ids[self.sel]
  if id then
    local def = Items.get(id)
    T.icon(def.icon, dx + dw / 2 - 48, y + 44, 4)
    love.graphics.setFont(T.fBody)
    T.setColor(T.col.text)
    love.graphics.printf(def.name, dx, y + 148, dw, "center")
    love.graphics.setFont(T.fBodySmall)
    T.setColor(T.col.dim)
    love.graphics.printf(def.desc, dx, y + 180, dw, "left")
    local useLabel = def.useLabel or "Examine"
    if def.use and id == "phone" and G.state.flashlight then useLabel = "Flashlight off" end
    T.hints({ { "interact", useLabel }, { "cancel", "Close" } }, dx, y + h - 40)
  else
    love.graphics.setFont(T.fBodySmall)
    T.setColor(T.col.dim)
    love.graphics.printf("My pockets are empty.\nThey usually are.", dx, y + 120, dw, "center")
    T.hints({ { "cancel", "Close" } }, dx, y + h - 40)
  end
  love.graphics.setColor(1, 1, 1, 1)
end

-- ---------------------------------------------------------------- container
local Container = {}
Container.__index = Container

-- def = { title, items = {ids...}, onTake = fn(id), onClose = fn, emptyText }
function UI.openContainer(def)
  G.audio.play("ui_open", 0.4)
  UI.modal = setmetatable({ kind = "container", def = def, sel = 1, t = 0, onClose = def.onClose }, Container)
end

function Container:take(i)
  local id = table.remove(self.def.items, i)
  if id and self.def.onTake then self.def.onTake(id) end
  self.sel = U.clamp(self.sel, 1, math.max(1, #self.def.items))
end

function Container:update(dt)
  self.t = self.t + dt
  local items = self.def.items
  if #items > 0 then self.sel = menuNav(self.sel, #items) end
  if Input.pressed("cancel") then
    Input.consume("cancel"); Input.consume("pause")
    UI.close()
    return
  end
  if Input.pressed("interact") then
    Input.consume("interact")
    if #items > 0 then self:take(self.sel) else UI.close() end
  elseif Input.pressed("takeall") and #items > 0 then
    while #self.def.items > 0 do self:take(1) end
  end
end

function Container:draw()
  local items = self.def.items
  love.graphics.setColor(0, 0, 0, 0.45)
  love.graphics.rectangle("fill", 0, 0, 960, 540)
  local w, h = 440, 120 + math.max(1, #items) * 52
  local x, y = 480 - w / 2, 230 - h / 2
  T.panel(x, y, w, h, 1)
  love.graphics.setFont(T.fLabel)
  T.setColor(T.col.accent)
  love.graphics.print(string.upper(self.def.title), x + 22, y + 16)
  if #items == 0 then
    love.graphics.setFont(T.fBodySmall)
    T.setColor(T.col.dim)
    love.graphics.printf(self.def.emptyText or "Empty.", x + 22, y + 52, w - 44, "left")
  end
  for i, id in ipairs(items) do
    local def = Items.get(id)
    local ry = y + 44 + (i - 1) * 52
    local sel = i == self.sel
    if sel then
      love.graphics.setColor(0.2, 0.15, 0.08, 0.8)
      love.graphics.rectangle("fill", x + 14, ry, w - 28, 46)
      T.setColor(T.col.accent)
      love.graphics.rectangle("fill", x + 14, ry, 3, 46)
    end
    T.icon(def.icon, x + 26, ry + 7, 1.33)
    love.graphics.setFont(T.fBody)
    T.setColor(sel and T.col.text or T.col.dim)
    love.graphics.print(def.name, x + 70, ry + 9)
  end
  local hints = #items > 0 and { { "interact", "Take" }, { "takeall", "Take all" }, { "cancel", "Close" } } or { { "cancel", "Close" } }
  T.hints(hints, x + 22, y + h - 40)
  love.graphics.setColor(1, 1, 1, 1)
end

-- ---------------------------------------------------------------- document
local Doc = {}
Doc.__index = Doc

function UI.openDocument(doc)
  G.audio.play("paper", 0.6)
  UI.modal = setmetatable({ kind = "document", doc = doc, page = 1, t = 0 }, Doc)
end

function Doc:update(dt)
  self.t = self.t + dt
  local n = #self.doc.pages
  local before = self.page
  if Input.pressed("left") then self.page = math.max(1, self.page - 1) end
  if Input.pressed("right") or Input.pressed("interact") then
    Input.consume("interact")
    if self.page == n and Input.pressed("interact") then UI.close() return end
    self.page = math.min(n, self.page + 1)
  end
  if before ~= self.page then G.audio.play("paper", 0.5) end
  if Input.pressed("cancel") then
    Input.consume("cancel"); Input.consume("pause")
    UI.close()
  end
end

function Doc:draw()
  love.graphics.setColor(0, 0, 0, 0.7)
  love.graphics.rectangle("fill", 0, 0, 960, 540)
  local pg = self.doc.pages[self.page]
  local x, y, w, h = 200, 50, 560, 420
  -- paper with a shadow and torn bottom edge
  love.graphics.setColor(0, 0, 0, 0.5)
  love.graphics.rectangle("fill", x + 8, y + 10, w, h)
  T.setColor(T.col.paper)
  love.graphics.rectangle("fill", x, y, w, h - 10)
  for i = 0, w - 1, 8 do
    local d = (love.math.noise(i * 0.13, self.page) * 10)
    love.graphics.rectangle("fill", x + i, y + h - 10, 8, d)
  end
  love.graphics.setColor(0.3, 0.25, 0.15, 0.25)
  love.graphics.circle("fill", x + w - 90, y + 300, 48)
  love.graphics.setScissor(x, y, w, h)
  love.graphics.setColor(1, 1, 1, 0.6)
  love.graphics.draw(T.grit, T.gritQuad, x, y)
  love.graphics.setScissor()
  T.setColor(T.col.ink)
  love.graphics.setFont(T.fLabel)
  love.graphics.printf(self.doc.title, x, y + 22, w, "center")
  love.graphics.rectangle("fill", x + 30, y + 46, w - 60, 2)
  love.graphics.rectangle("fill", x + 30, y + 50, w - 60, 1)
  love.graphics.setFont(T.fTitle)
  love.graphics.printf(pg.head, x + 30, y + 64, w - 60, "left")
  love.graphics.setFont(T.fBodySmall)
  love.graphics.printf(pg.body, x + 30, y + 160, w - 60, "left")
  love.graphics.setColor(0.2, 0.17, 0.13, 1)
  love.graphics.printf(pg.foot, x + 30, y + h - 52, w - 60, "right")
  if pg.head:find("24/7") then
    love.graphics.setColor(0.55, 0.08, 0.06, 0.85)
    love.graphics.setLineWidth(3)
    love.graphics.ellipse("line", x + w / 2, y + 96, w / 2 - 12, 48)
  end
  love.graphics.setColor(1, 1, 1, 1)
  T.hints({ { "interact", self.page < #self.doc.pages and "Next" or "Close" }, { "cancel", "Close" } }, x + 6, y + h + 12)
  love.graphics.setFont(T.fBodySmall)
  T.setColor(T.col.dim)
  love.graphics.printf(string.format("%d / %d", self.page, #self.doc.pages), x, y + h + 12, w, "right")
  love.graphics.setColor(1, 1, 1, 1)
end

-- ---------------------------------------------------------------- menu (pause)
local Menu = {}
Menu.__index = Menu

-- options = { {label, fn}, ... }
function UI.openMenu(title, options, opts)
  opts = opts or {}
  UI.modal = setmetatable({ kind = "menu", title = title, options = options, sel = 1, t = 0, cancel = opts.cancel }, Menu)
end

function Menu:update(dt)
  self.t = self.t + dt
  self.sel = menuNav(self.sel, #self.options)
  if Input.pressed("interact") then
    Input.consume("interact")
    G.audio.play("ui_select", 0.5)
    local opt = self.options[self.sel]
    if opt[2] then opt[2]() end
  elseif Input.pressed("cancel") and self.cancel then
    Input.consume("cancel"); Input.consume("pause")
    self.cancel()
  end
end

function Menu:draw()
  love.graphics.setColor(0, 0, 0, 0.65)
  love.graphics.rectangle("fill", 0, 0, 960, 540)
  local w, h = 360, 110 + #self.options * 40
  local x, y = 480 - w / 2, 270 - h / 2
  T.panel(x, y, w, h)
  love.graphics.setFont(T.fTitle)
  T.setColor(T.col.text)
  love.graphics.printf(self.title, x, y + 20, w, "center")
  love.graphics.setFont(T.fBody)
  for i, o in ipairs(self.options) do
    local sel = i == self.sel
    T.setColor(sel and T.col.accent or T.col.dim)
    local label = type(o[1]) == "function" and o[1]() or o[1]
    love.graphics.printf((sel and "> " or "") .. label .. (sel and " <" or ""), x, y + 76 + (i - 1) * 40, w, "center")
  end
  love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================================
-- frame
-- ============================================================================
function UI.init()
  T.init()
end

function UI.reset()
  D.active, D.queue, D.cur = false, {}, nil
  toasts = {}
  banner = nil
  UI.modal = nil
  UI.prompt = nil
end

function UI.update(dt)
  for i = #toasts, 1, -1 do
    toasts[i].t = toasts[i].t + dt
    if toasts[i].t > 3.4 then table.remove(toasts, i) end
  end
  if banner then
    banner.t = banner.t + dt
    if banner.t > 3 then banner = nil end
  end
  UI.flashObjective = math.max(0, UI.flashObjective - dt)
  if D.active then
    updateDialogue(dt)
  elseif UI.modal then
    UI.modal:update(dt)
  end
  local target = UI.hudVisible and 1 or 0
  UI.hudAlpha = U.approach(UI.hudAlpha, target, dt * 2)
end

function UI.draw()
  local a = UI.hudAlpha
  if a > 0.01 then
    local dim = (D.active or UI.modal) and 0.5 or 1
    drawObjective(a * dim)
    drawClock(a * dim)
    if not UI.blocking() then drawPrompt(a) end
  end
  drawToasts()
  drawBanner()
  if UI.modal then UI.modal:draw() end
  if D.active then drawDialogue() end
end

return UI
