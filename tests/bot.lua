-- Scripted playthrough: starts at the title screen, plays both scenes to the
-- end through virtual input, and captures screenshots along the way.
--   love . --bot [--out tests/out] [--fixeddt]
local G = require("src.g")
local Input = require("src.core.input")
local Game = require("src.game.game")

local Bot = {}
local co, out, shots, failures = nil, "tests/out", {}, {}
local frame = 0
local waitFrames = 0

local function y() coroutine.yield() end
local function frames(n) for _ = 1, n do y() end end
local function sec(s) frames(math.floor(s * 60)) end

local function shot(name)
  local path = out .. "/" .. string.format("%02d_%s.png", #shots + 1, name)
  shots[#shots + 1] = path
  G.renderNext = true
  G.capture(path)
  y()
end

local function fail(msg)
  failures[#failures + 1] = msg
  print("BOT FAIL: " .. msg)
end

local function tap(a)
  Input.press(a); y(); Input.release(a); y()
end

local function scene() return G.scenes.current end
local function player() return G.world and G.world.player end

-- wait while dialogue/cutscenes run, tapping through text
local function mash(maxSec, keepGoing)
  local t = 0
  local sc = scene()
  while t < (maxSec or 30) do
    local busy = G.ui.dialogue.active or (sc and sc.cutscene) or G.scenes.fadeTarget ~= 0
    if not busy and not keepGoing then break end
    if G.ui.dialogue.active and G.ui.dialogue.shown >= G.ui.dialogue.len then
      tap("interact")
    else
      y()
    end
    t = t + 1 / 60 * 2
    if scene() ~= sc then break end
  end
end

-- steer toward a point with the movement keys
local function goto(x, yy, timeout)
  local pl = player()
  local t = 0
  while true do
    local dx, dy = x - pl.x, yy - pl.y
    if math.abs(dx) < 2 and math.abs(dy) < 2 then break end
    Input.releaseAll()
    if dx > 1.5 then Input.press("right") elseif dx < -1.5 then Input.press("left") end
    if dy > 1.5 then Input.press("down") elseif dy < -1.5 then Input.press("up") end
    y()
    t = t + 1 / 60
    if t > (timeout or 8) then
      fail(string.format("could not reach %d,%d (stuck at %.0f,%.0f)", x, yy, pl.x, pl.y))
      break
    end
    if G.ui.blocking() then Input.releaseAll(); mash(20) end
  end
  Input.releaseAll()
  y()
end

local function route(points)
  for _, p in ipairs(points) do goto(p[1], p[2]) end
end

local function face(dir)
  player().facing = dir
  y(); y()
end

local function use(expectLabel)
  y()
  local f = scene().focus
  if expectLabel and (not f or f.label ~= expectLabel) then
    fail("expected focus '" .. expectLabel .. "', got '" .. tostring(f and f.label) .. "'")
  end
  tap("interact")
end

local function plan()
  sec(1.5)
  shot("title")
  tap("interact")                        -- New Game
  sec(2.5)
  shot("intro_card")
  sec(5.5)
  shot("intro_wakeup")
  mash(60)
  sec(0.5)
  shot("apartment_start")

  -- bedroom: phone, coins, key, backpack
  goto(66, 78); face("up"); use("Cellphone")
  sec(0.6); shot("phone_message")
  mash(20)
  tap("flashlight"); sec(0.3)
  goto(63, 78); face("left"); use("Coin"); mash(10)
  goto(63, 92); face("left"); use("Coin"); mash(10)
  route({ { 100, 110 }, { 100, 76 }, { 140, 76 } }); face("up"); use("Keys"); mash(10)
  route({ { 160, 76 }, { 172, 92 } }); face("up"); use("Backpack"); mash(10)
  shot("bedroom_flashlight")
  tap("inventory"); sec(0.4)
  shot("inventory")
  -- read the newspapers (backpack is the 4th item picked up... find it)
  local ids = G.state.invOrder
  for i, id in ipairs(ids) do
    if id == "backpack" then G.ui.modal.sel = i end
  end
  tap("interact"); sec(0.4)
  shot("newspaper")
  tap("right"); sec(0.3)
  shot("newspaper_ad")
  tap("cancel"); y()
  if G.ui.modal then tap("cancel") end

  -- bathroom coin + mirror
  route({ { 112, 150 }, { 112, 246 }, { 304, 246 }, { 304, 160 } })
  goto(296, 152); face("left"); use("Coin"); mash(10)
  goto(297, 72); face("up"); use("Mirror"); sec(0.3)
  shot("bathroom_mirror")
  mash(20)

  -- kitchen fridge
  route({ { 304, 160 }, { 304, 246 }, { 464, 246 }, { 464, 160 }, { 500, 160 }, { 500, 86 } })
  face("up"); use("Fridge"); sec(0.4)
  shot("fridge")
  tap("takeall"); sec(0.2)
  tap("cancel"); mash(20)
  shot("kitchen")

  -- living room + door
  route({ { 500, 160 }, { 464, 160 }, { 464, 246 }, { 272, 246 }, { 272, 334 } })
  shot("living_room")
  face("down"); use("Front door")
  mash(30)
  if scene() ~= G.sceneList.neighborhood then
    sec(3)
  end
  if scene() ~= G.sceneList.neighborhood then fail("did not reach the neighbourhood") return end

  -- ===== outside =====
  sec(2.6); shot("outside_card")
  mash(30)
  shot("outside_start")
  route({ { 440, 470 }, { 560, 470 } })
  shot("street_west")
  goto(566, 470)
  Input.press("right"); sec(0.3); Input.releaseAll()   -- step onto the crossroads
  sec(1.8); shot("faint")
  sec(1.0); shot("faint_dialogue")
  mash(60)
  shot("after_faint")
  route({ { 600, 400 }, { 600, 200 }, { 620, 162 } })
  face("up"); use("School gate"); sec(0.5)
  shot("school_gate")
  mash(60)
  goto(688, 162); face("right"); use("Something on the ground"); mash(15)
  -- a look at the dealership to the south
  route({ { 600, 200 }, { 600, 470 }, { 650, 600 }, { 650, 780 } })
  sec(0.5); shot("dealership")
  route({ { 650, 600 }, { 720, 600 }, { 760, 620 } })
  mash(15)
  route({ { 760, 600 }, { 800, 580 }, { 1000, 580 }, { 1096, 470 } })
  shot("store_approach")
  goto(1096, 440)
  sec(1.0); shot("store_door")
  mash(60)
  sec(4)
  if scene() ~= G.sceneList.mart then fail("mart not reached") return end
  if not Game.flag("reached_store") then fail("reached_store flag missing") end
  for _, id in ipairs({ "phone", "key", "coin", "backpack", "water", "coke", "meat", "knife", "lock" }) do
    if not Game.has(id) then fail("missing item " .. id) end
  end

  -- ===== scene 3: the mart =====
  sec(2.6); shot("mart_card")
  mash(30)
  shot("mart_store")
  goto(454, 70); face("up"); use("Staff room"); mash(10)
  route({ { 440, 140 }, { 400, 254 } }); face("up")
  use("Talk to the clerk"); sec(1.2)
  shot("vincent_greeting")
  local function conv() return G.ui.conv end
  local function toChoices()
    for _ = 1, 600 do
      local c = conv()
      if not c or not c:active() then return false end
      if c.conv:line() then
        if c.shown >= #c.conv:line().text then tap("interact") else y() end
      elseif c.conv.choices then return true
      else y() end
    end
    return false
  end
  local function say(prefix, snap)
    if not toChoices() then fail("no choices for '" .. prefix .. "'") return end
    local c = conv()
    for i, ch in ipairs(c.conv.choices) do
      if ch.text:sub(1, #prefix) == prefix then
        c.sel = i
        if snap then sec(0.3); shot(snap) end
        tap("interact")
        return
      end
    end
    fail("choice not offered: " .. prefix)
  end
  say("Why not the hot dogs?")
  say("I want to buy something", "vincent_topics")
  say("Bread and a can of soup.")
  say("You look tired."); say("Not like you")
  say("How long have you worked here?"); say("Four years of nights")
  say("Is it always this dead"); say("Who else comes in"); say("You should ask him")
  say("The missing kid"); say("Did you know him?")
  say("What do you do when your shift"); say("That sounds lonely.")
  say("Vincent. Are you actually okay?"); say("I don't. That's why you can tell me.")
  sec(1.5); y()
  for _ = 1, 3 do tap("interact"); sec(0.3) end
  sec(1.5); shot("vincent_secret")
  say("I'd notice."); say("It's on your tag")
  say("That's all."); mash(10)
  if Game.flag("vincent_secret") ~= "out" then fail("secret flag not out") end
  use("Talk to the clerk"); sec(0.5)
  say("Can I get into the staff room?")
  say("That's all."); mash(10)
  if not Game.has("staff_key") then fail("no staff key") end

  -- the lot and the woman in the headlights
  route({ { 400, 270 } }); face("down"); use("Go outside"); sec(1.2)
  mash(10)
  shot("lot")
  route({ { 330, 250 }, { 330, 300 }, { 352, 300 } })
  shot("headlights")
  face("right"); use("The woman"); sec(1.5)
  shot("red_face")
  say("Hey. Hey, are you okay?"); say("(Touch her shoulder.)")
  sec(0.5); shot("red_touch")
  say("(Step back.)"); mash(10)

  -- the staff room and the note
  route({ { 330, 250 }, { 400, 116 } }); face("up"); use("Back inside"); sec(1.2)
  goto(454, 70); face("up"); use("Staff room"); sec(1.2)
  shot("staff_room")
  route({ { 128, 120 }, { 100, 74 } }); face("up"); use("Laptop")
  goto(40, 66); face("up"); use("Laptop"); sec(0.4)
  shot("laptop")
  tap("cancel"); y()
  route({ { 100, 74 } }); face("up"); use("Note on the wall")
  mash(5); sec(2.6)
  shot("note")
  tap("interact"); sec(5)
  if scene() ~= G.sceneList.scene4 then fail("scene 4 not reached") end
  sec(4); shot("scene4")
  sec(3)
  tap("interact"); sec(2.5)
  if scene() ~= G.sceneList.title then fail("did not return to the title") end
end

function Bot.start(args)
  out = type(args.out) == "string" and args.out or "tests/out"
  os.execute("mkdir -p " .. out)
  Input.setVirtual(true)
  G.renderOnDemand = not args.render
  pcall(love.window.setVSync, 0)
  G.scenes.switch(G.sceneList.title, {})
  co = coroutine.create(plan)
  G.hook = function()
    frame = frame + 1
    if coroutine.status(co) == "dead" then
      if not Bot.done then
        Bot.done = true
        print(string.format("BOT finished: %d screenshots, %d failures, %.1fs played", #shots, #failures, G.state.playTime))
        waitFrames = 20
      end
      waitFrames = waitFrames - 1
      if waitFrames <= 0 then love.event.quit(#failures == 0 and 0 or 1) end
      return
    end
    local ok, err = coroutine.resume(co)
    if not ok then
      fail("bot error: " .. tostring(err) .. "\n" .. debug.traceback(co))
      Bot.done = true
      waitFrames = 20
    end
  end
end

return Bot
