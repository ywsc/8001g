-- Face-to-face conversation engine.
--
-- A script (src/dialogue/<npc>.lua) is plain data:
--   id, name, start(npc) -> node id, face(npc, node) -> image name,
--   nodes = { [id] = node }, topics = { topic... }, present = { [itemId] = node id }
--
-- node   = { say = lines | fn(npc, conv) -> lines, choices = {...} | fn,
--            go = next node (when no choices), run = fn(npc, conv), face = image,
--            hub = true (topic menu), exit = true }
-- line   = "text" (NPC speaks) | { "text", who = "you" | "narration" }
-- choice = { text, go, open = delta, when = fn(npc), once = true, id, run = fn,
--            need = minimum openness, fail = node used when openness is too low }
--
-- Every NPC keeps a persistent record in G.state.npcs[id]:
--   open (0..100, hidden "openness"), done (topics used), met, visits,
--   secret (true once told), flags (free-form).
-- Openness rises with patience and real attention and drops with pushing or
-- carelessness; the secret only comes out past a threshold.
local G = require("src.g")

local D = {}
D.__index = D

function D.npcState(script)
  local st = G.state
  st.npcs = st.npcs or {}
  local n = st.npcs[script.id]
  if not n then
    n = { open = script.startOpen or 20, done = {}, met = false, visits = 0, secret = false, flags = {} }
    st.npcs[script.id] = n
  end
  return n
end

-- mood word shown in the conversation header
function D.mood(open)
  if open < 15 then return "shut off" elseif open < 35 then return "guarded" elseif open < 55 then return "wary"
  elseif open < 80 then return "listening" end
  return "open"
end

function D.start(script, opts)
  local self = setmetatable({}, D)
  self.script = script
  self.npc = D.npcState(script)
  self.npc.visits = self.npc.visits + 1
  self.opts = opts or {}
  self.lines = {}
  self.choices = nil
  self.active = true
  self.log = {}
  self.delta = 0        -- last openness change, for UI feedback
  self.deltaT = 0
  self:enter(script.start(self.npc, self))
  return self
end

local function norm(line)
  if type(line) == "string" then return { text = line, who = "npc" } end
  return { text = line[1] or line.text, who = line.who or "npc" }
end

function D:node(id)
  local n = self.script.nodes[id]
  assert(n, "dialogue node missing: " .. tostring(id))
  return n
end

function D:enter(id)
  if id == "end" or id == nil then return self:finish() end
  if id == "hub" and not self.script.nodes.hub then id = "_hub" end
  local node = id == "_hub" and { hub = true } or self:node(id)
  self.nodeId = id
  self.cur = node
  if node.run then node.run(self.npc, self) end
  if node.face then self.face = node.face end
  local say = node.say
  if type(say) == "function" then say = say(self.npc, self) end
  if type(say) == "string" then say = { say } end
  self.lines = {}
  for _, l in ipairs(say or {}) do self.lines[#self.lines + 1] = norm(l) end
  self.choices = nil
  if #self.lines == 0 then self:afterLines() end
end

-- the current line, or nil when the node is waiting for a choice
function D:line()
  return self.lines[1]
end

function D:advance()
  if #self.lines > 0 then
    local l = table.remove(self.lines, 1)
    self.log[#self.log + 1] = l
    if #self.log > 30 then table.remove(self.log, 1) end
  end
  if #self.lines == 0 then self:afterLines() end
end

function D:afterLines()
  local node = self.cur
  if self.npc.open <= 0 and self.script.nodes.shutdown and self.nodeId ~= "shutdown" then
    return self:enter("shutdown")
  end
  if node.exit then return self:finish() end
  if node.hub then
    self.choices = self:hubChoices()
    return
  end
  local ch = node.choices
  if type(ch) == "function" then ch = ch(self.npc, self) end
  if ch and #ch > 0 then
    local list = {}
    for _, c in ipairs(ch) do
      if (not c.when or c.when(self.npc, self)) and not (c.once and self.npc.done[c.id or c.text]) then
        list[#list + 1] = c
      end
    end
    self.choices = list
  elseif node.go then
    self:enter(type(node.go) == "function" and node.go(self.npc, self) or node.go)
  else
    self:enter("hub")
  end
end

function D:hubChoices()
  local list = {}
  for _, t in ipairs(self.script.topics or {}) do
    local key = t.id or t.text
    local doneOk = not (t.once ~= false and self.npc.done[key])
    if doneOk and (not t.when or t.when(self.npc, self)) then list[#list + 1] = t end
  end
  if self.script.present and #G.state.invOrder > 0 then
    list[#list + 1] = { text = "Show something...", present = true }
  end
  list[#list + 1] = { text = self.script.leaveText or "That's all.", go = "leave", leave = true }
  return list
end

function D:changeOpen(d)
  if not d or d == 0 then return end
  local n = self.npc
  n.open = math.max(0, math.min(100, n.open + d))
  self.delta = d
  self.deltaT = 2.2
  if G.audio then G.audio.play(d > 0 and "open_up" or "close_off", 0.45) end
end

function D:choose(c)
  if c.present then
    self.picking = true
    return
  end
  self.choices = nil
  local key = c.id or c.text
  if c.once ~= false then self.npc.done[key] = true end
  self.log[#self.log + 1] = { text = c.text, who = "you" }
  if c.need and self.npc.open < c.need then
    self:changeOpen(c.failOpen or -4)
    return self:enter(c.fail or "hub")
  end
  self:changeOpen(c.open)
  if c.run then c.run(self.npc, self) end
  if self.npc.open <= 0 and self.script.nodes.shutdown then
    return self:enter("shutdown")
  end
  if c.leave and not self.script.nodes.leave then return self:finish() end
  local go = c.go
  if type(go) == "function" then go = go(self.npc, self) end
  self:enter(go or "hub")
end

-- show an inventory item (puzzle input); returns false if the NPC has no reaction
function D:present(itemId)
  self.picking = false
  local map = self.script.present or {}
  local nodeId = map[itemId] or map.default
  self.log[#self.log + 1] = { text = "(You show the " .. require("src.game.items").get(itemId).name .. ")", who = "you" }
  self.choices = nil
  self:enter(nodeId or "hub")
end

function D:revealSecret()
  if self.npc.secret then return end
  self.npc.secret = true
  if self.script.onSecret then self.script.onSecret(self.npc, self) end
end

function D:finish()
  self.active = false
  self.lines, self.choices = {}, nil
  self.npc.met = true
  if self.script.onExit then self.script.onExit(self.npc, self) end
  if self.opts.onExit then self.opts.onExit(self.npc, self) end
end

function D:update(dt)
  self.deltaT = math.max(0, self.deltaT - dt)
end

return D
