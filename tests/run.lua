-- Headless logic tests. Run with:  love . --test   (see tools/run_tests.sh)
-- Scenes are stepped manually with a fixed dt and virtual input, so the
-- tests exercise the same code paths as real play.
local G = require("src.g")
local Input = require("src.core.input")
local Script = require("src.core.script")
local Game = require("src.game.game")
local U = require("src.core.util")

local T = { passed = 0, failed = 0, log = {} }
local DT = 1 / 60

local function check(cond, msg)
  if cond then
    T.passed = T.passed + 1
  else
    T.failed = T.failed + 1
    print("  FAIL: " .. msg)
  end
end

local function eq(a, b, msg) check(a == b, string.format("%s (expected %s, got %s)", msg, tostring(b), tostring(a))) end

-- step the active scene N seconds; optionally keep tapping "interact"
local function step(sec, mash)
  local frames = math.floor(sec / DT + 0.5)
  for f = 1, frames do
    if mash then
      if f % 6 == 0 then Input.press("interact") else Input.release("interact") end
    end
    Input.update()
    G.scenes.update(DT)
  end
  Input.release("interact")
end

local function tap(action)
  Input.press(action); Input.update(); G.scenes.update(DT)
  Input.release(action); Input.update(); G.scenes.update(DT)
end

local function untilIdle(maxSec)
  local t = 0
  local sc = G.scenes.current
  while t < (maxSec or 30) and G.scenes.current == sc and (G.ui.dialogue.active or sc.cutscene or G.scenes.fadeTarget ~= 0 or Script.busy()) do
    step(0.1, true)
    t = t + 0.1
  end
  return t < (maxSec or 30)
end

local function startScene(name, args)
  G.scenes.current = nil
  G.scenes.pending = nil
  G.scenes.switch(G.sceneList[name], args or {}, { instant = true })
  G.scenes.fade, G.scenes.fadeTarget = 0, 0
  step(0.05)
end

local tests = {}

tests[#tests + 1] = { "util", function()
  eq(U.clamp(5, 0, 3), 3, "clamp high")
  eq(U.clamp(-1, 0, 3), 0, "clamp low")
  local hm, suf = U.formatClock(2 * 60 + 3)
  eq(hm .. " " .. suf, "02:03 AM", "clock format")
  eq(U.distToRect(5, 5, 0, 0, 10, 10), 0, "point inside rect")
end }

tests[#tests + 1] = { "inventory + stage 1 via coins", function()
  Game.reset()
  eq(G.state.stage, 1, "starts at stage 1")
  Game.give("coin", 1, true)
  Game.give("coin", 1, true)
  eq(G.state.stage, 1, "two coins are not enough")
  Game.give("coin", 1, true)
  eq(Game.count("coin"), 3, "three coins counted")
  eq(G.state.stage, 2, "three coins complete stage 1")
  Game.take("coin", 3)
  check(not Game.has("coin"), "coins removed")
  eq(#G.state.invOrder, 0, "inventory order cleaned up")
end }

tests[#tests + 1] = { "stage 1 via cellphone + flashlight", function()
  Game.reset()
  Game.give("phone", 1, true)
  eq(G.state.stage, 2, "phone completes stage 1")
  Game.useItem("phone")
  check(G.state.flashlight, "phone toggles flashlight on")
  Game.useItem("phone")
  check(not G.state.flashlight, "and off again")
  Game.give("phone", 0, true)
end }

tests[#tests + 1] = { "items: drink, equip, inedible meat", function()
  Game.reset()
  G.ui.reset()
  Game.give("coke", 1, true)
  local h = G.state.hunger
  Game.useItem("coke")
  check(G.state.hunger < h, "coke lowers hunger")
  check(not Game.has("coke"), "coke consumed")
  Game.give("meat", 1, true)
  Game.useItem("meat")
  check(Game.has("meat"), "raw meat is not eaten")
  Game.give("knife", 1, true)
  Game.useItem("knife")
  eq(G.state.equipped, "knife", "knife equipped")
  Game.useItem("knife")
  eq(G.state.equipped, nil, "knife unequipped")
  G.ui.reset()
end }

tests[#tests + 1] = { "objectives text", function()
  Game.reset()
  local o = Game.objectives()
  eq(#o, 3, "stage 1 shows coins / or / phone")
  check(o[1].text:find("0/3") ~= nil, "coin counter shown")
  Game.give("phone", 1, true)
  o = Game.objectives()
  eq(o[1].text, "Leave the apartment", "stage 2 first objective")
  Game.setFlag("door_needs_key")
  o = Game.objectives()
  eq(o[1].text, "Find the building key", "key hint appears after trying the door")
end }

tests[#tests + 1] = { "apartment: walls block the player", function()
  Game.reset()
  startScene("apartment", { skipIntro = true })
  local pl = G.world.player
  eq(pl.x, 66, "spawn x")
  Input.press("up")
  step(3)
  Input.release("up")
  check(pl.y >= 72, "player stopped by the nightstand / wall (y=" .. pl.y .. ")")
  Input.press("left")
  step(3)
  Input.release("left")
  check(pl.x >= 56, "player stopped by the bed (x=" .. pl.x .. ")")
end }

tests[#tests + 1] = { "apartment: interact finds the fridge and gives all items", function()
  Game.reset()
  startScene("apartment", { skipIntro = true })
  local pl = G.world.player
  pl:teleport(490, 86, "up")
  step(0.1)
  local sc = G.scenes.current
  check(sc.focus and sc.focus.label == "Fridge", "fridge is focused (" .. tostring(sc.focus and sc.focus.label) .. ")")
  tap("interact")
  check(G.ui.modal and G.ui.modal.kind == "container", "fridge container opens")
  check(sc.fridgeLight.on, "fridge light on while open")
  tap("takeall")
  for _, id in ipairs({ "water", "coke", "meat", "knife" }) do check(Game.has(id), "got " .. id) end
  tap("cancel")
  check(G.ui.modal == nil, "container closed")
  check(not sc.fridgeLight.on, "fridge light off when closed")
  untilIdle()
end }

tests[#tests + 1] = { "apartment: front door gating", function()
  Game.reset()
  startScene("apartment", { skipIntro = true })
  local sc = G.scenes.current
  local pl = G.world.player
  pl:teleport(272, 334, "down")
  step(0.1)
  eq(sc.focus and sc.focus.label, "Front door", "door focused")
  tap("interact")
  check(G.ui.dialogue.active, "refuses with empty pockets")
  untilIdle()
  eq(G.scenes.current, sc, "still in the apartment")
  Game.give("coin", 3, true)
  untilIdle()
  tap("interact")
  untilIdle()
  check(Game.flag("door_needs_key"), "locked without the key")
  eq(G.scenes.current, sc, "still inside without key")
  Game.give("key", 1, true)
  tap("interact")
  untilIdle(20)
  eq(G.scenes.current, G.sceneList.neighborhood, "door leads outside")
  check(Game.flag("left_apartment"), "left_apartment flag set")
end }

tests[#tests + 1] = { "neighborhood: faint event + store ends the chapter", function()
  Game.reset()
  Game.give("phone", 1, true)
  Game.give("key", 1, true)
  Game.setFlag("left_apartment")
  startScene("neighborhood", { skipIntro = true })
  local pl = G.world.player
  pl:teleport(640, 500, "right")
  step(0.2)
  check(Game.flag("faint_started"), "crossroads triggers the hunger attack")
  untilIdle(40)
  check(Game.flag("faint_done"), "faint sequence completes")
  check(G.state.hunger >= 88, "player is starving afterwards")
  eq(pl.state, "free", "player can move again")
  pl:teleport(1096, 440, "up")
  step(0.2)
  untilIdle(40)
  check(Game.flag("reached_store"), "store reached")
  eq(G.state.stage, 3, "chapter complete")
  step(3)
  eq(G.scenes.current, G.sceneList.ending, "ending scene shown")
end }

tests[#tests + 1] = { "neighborhood: gate memory + broken lock", function()
  Game.reset()
  Game.give("phone", 1, true)
  Game.setFlag("faint_done"); Game.setFlag("faint_started")
  startScene("neighborhood", { skipIntro = true })
  local pl = G.world.player
  pl:teleport(640, 160, "up")
  step(0.1)
  eq(G.scenes.current.focus and G.scenes.current.focus.label, "School gate", "gate focused")
  tap("interact")
  untilIdle(60)
  check(Game.flag("gate_memory"), "gate memory played")
  pl:teleport(688, 162, "right")
  step(0.1)
  tap("interact")
  untilIdle()
  check(Game.has("lock"), "broken lock picked up")
end }

function T.start(args)
  Input.setVirtual(true)
  print("Running " .. #tests .. " test groups")
  for _, t in ipairs(tests) do
    local before = T.failed
    local ok, err = pcall(t[2])
    if not ok then
      T.failed = T.failed + 1
      print("  ERROR in '" .. t[1] .. "': " .. tostring(err))
    end
    print(string.format("[%s] %s", (ok and T.failed == before) and " ok " or "FAIL", t[1]))
  end
  print(string.format("\n%d checks passed, %d failed", T.passed, T.failed))
  love.event.quit(T.failed == 0 and 0 or 1)
end

return T
