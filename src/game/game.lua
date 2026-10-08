-- Game rules: inventory, quest stages, flags, clock and hunger.
-- UI-facing helpers (say, toast) forward to G.ui so scenes and items share
-- one vocabulary.
local G = require("src.g")
local Items = require("src.game.items")
local Script = require("src.core.script")

local Game = {}

local START_CLOCK = 2 * 60 + 3      -- 02:03 AM
local MINUTE_SECONDS = 15           -- real seconds per in-game minute

function Game.newState()
  return {
    inv = {},             -- id -> count
    invOrder = {},        -- pickup order (for the inventory grid)
    flags = {},
    stage = 1,
    clock = START_CLOCK,
    hunger = 58,
    flashlight = false,
    equipped = nil,
    playTime = 0,
  }
end

function Game.reset()
  G.state = Game.newState()
end

-- ---------------------------------------------------------------- inventory
function Game.count(id) return G.state.inv[id] or 0 end
function Game.has(id) return Game.count(id) > 0 end

function Game.give(id, n, silent)
  n = n or 1
  local st = G.state
  if not st.inv[id] then table.insert(st.invOrder, id) end
  st.inv[id] = (st.inv[id] or 0) + n
  local def = Items.get(id)
  if not silent and G.ui then
    local label = def.name
    if id == "coin" then label = string.format("Coin  (%d/3)", Game.count("coin")) end
    G.ui.toast("+ " .. label, def.icon)
  end
  if G.audio then G.audio.play(id == "coin" and "coin" or "pickup", 0.7) end
  Game.checkQuest()
end

function Game.take(id, n)
  n = n or 1
  local st = G.state
  st.inv[id] = math.max(0, (st.inv[id] or 0) - n)
  if st.inv[id] == 0 then
    st.inv[id] = nil
    for i, v in ipairs(st.invOrder) do
      if v == id then table.remove(st.invOrder, i) break end
    end
  end
  if id == "phone" then st.flashlight = false end
  if st.equipped == id and not Game.has(id) then st.equipped = nil end
end

function Game.useItem(id)
  local def = Items.get(id)
  if not def or not def.use then
    Game.say({ def and def.desc or "..." })
    return
  end
  if def.use(Game) then Game.take(id, 1) end
end

-- ---------------------------------------------------------------- flags
function Game.flag(name) return G.state.flags[name] end
function Game.setFlag(name, v)
  if v == nil then v = true end
  G.state.flags[name] = v
  Game.checkQuest()
end

-- ---------------------------------------------------------------- quests
Game.STAGES = {
  { title = "Scrape together some money" },
  { title = "Get to the 24-hour store" },
  { title = "The 24/7 MART" },
  { title = "..." },
}

function Game.stage1Done()
  return Game.count("coin") >= 3 or Game.has("phone")
end

function Game.objectives()
  local st = G.state
  local list = {}
  if st.stage == 1 then
    list[#list + 1] = { text = string.format("Find 3 coins  (%d/3)", math.min(3, Game.count("coin"))), done = Game.count("coin") >= 3 }
    list[#list + 1] = { text = "- or -", sep = true }
    list[#list + 1] = { text = "Find my cellphone", done = Game.has("phone") }
  elseif st.stage == 2 then
    if not Game.flag("left_apartment") then
      if Game.flag("door_needs_key") and not Game.has("key") then
        list[#list + 1] = { text = "Find the building key", done = false }
      end
      list[#list + 1] = { text = "Leave the apartment", done = false }
    else
      list[#list + 1] = { text = "Leave the apartment", done = true }
      if Game.flag("faint_done") then
        list[#list + 1] = { text = "Hurry east to the 24-hour store", done = Game.flag("reached_store") }
      else
        list[#list + 1] = { text = "Walk to the 24-hour store", done = Game.flag("reached_store") }
      end
    end
  end
  if st.stage == 3 then
    list[#list + 1] = { text = "Buy something to eat", done = Game.flag("bought_food") }
    if Game.flag("tried_staff_door") then
      list[#list + 1] = { text = "Get into the staff room", done = Game.flag("entered_staff") }
    end
    if Game.flag("saw_running_car") then
      list[#list + 1] = { text = "Check on the woman in the headlights", done = Game.flag("met_red") }
    end
  end
  return list
end

function Game.checkQuest()
  local st = G.state
  if st.stage == 1 and Game.stage1Done() then
    st.stage = 2
    if G.ui then
      G.ui.objectiveUpdated("Objective complete")
      Script.run(function()
        Script.wait(0.6)
        Script.waitUntil(function() return not G.ui.blocking() end)
        if Game.has("phone") and Game.count("coin") < 3 then
          Game.say({ "My phone. The store takes tap-to-pay... if this thing still has battery." })
        else
          Game.say({ "Three coins. Enough for bread. Maybe something with meat in it." })
        end
        Game.say({ "Okay. Get dressed, get out, get food." })
      end)
    end
  elseif st.stage == 2 and Game.flag("reached_store") then
    st.stage = 3
    if G.ui then G.ui.objectiveUpdated("Objective complete") end
  end
end

-- ---------------------------------------------------------------- clock / hunger
function Game.update(dt)
  local st = G.state
  st.playTime = st.playTime + dt
  st.clock = st.clock + dt / MINUTE_SECONDS
  if not Game.flag("faint_done") then
    if st.hunger < 84 then st.hunger = math.min(84, st.hunger + dt * 0.05) end
  else
    st.hunger = math.min(100, st.hunger + dt * 0.03)
  end
end

function Game.addHunger(v)
  G.state.hunger = math.max(0, math.min(100, G.state.hunger + v))
end

function Game.hungerLabel()
  local h = G.state.hunger
  if h >= 88 then return "STARVING" elseif h >= 70 then return "Famished" elseif h >= 45 then return "Hungry" end
  return "Peckish"
end

-- ---------------------------------------------------------------- helpers
function Game.say(lines, onDone)
  if G.ui then G.ui.say(lines, onDone) end
end

-- blocking version for scripts
function Game.sayWait(lines)
  Game.say(lines)
  Script.waitUntil(function() return not G.ui.dialogue.active end)
end

function Game.toggleFlashlight()
  local st = G.state
  if not Game.has("phone") then return end
  st.flashlight = not st.flashlight
  if G.audio then G.audio.play("click", 0.6) end
  if G.ui then G.ui.toast(st.flashlight and "Flashlight on" or "Flashlight off", "phone") end
end

Game.NEWSPAPER = {
  title = "HOLLOW CREEK GAZETTE",
  pages = {
    {
      head = "SECOND CHILD MISSING NEAR ALDER ST. ELEMENTARY",
      body = "Police have asked residents of the Alder Street area to keep their children indoors after dark. "
          .. "Eight-year-old Thomas Wren was last seen near the east gate of the elementary school on Tuesday evening. "
          .. "It is the second disappearance this month. The school will remain closed until further notice.",
      foot = "Continued on page 4...",
    },
    {
      head = "24/7 MART - ALWAYS OPEN. ALWAYS HERE.",
      body = "Bread. Milk. Hot food at any hour. Corner of Alder & Fifth.\n\n"
          .. "The ad is circled in red pen. Hard enough to tear the paper.\n"
          .. "I don't remember doing that.",
      foot = "Clipped - page 9",
    },
    {
      head = "LOCAL DEALERSHIP CLOSES ITS DOORS",
      body = "After forty years, Hollow Creek Motors will close at the end of the month. "
          .. "The owner declined to comment on the vandalism reported at the lot, or on the night watchman, "
          .. "who has not been seen since September.",
      foot = "Page 12",
    },
  },
}

function Game.readNewspaper()
  Game.setFlag("read_paper")
  if G.ui then G.ui.openDocument(Game.NEWSPAPER) end
end

return Game
