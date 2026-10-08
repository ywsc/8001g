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
  goto(600, 470)                         -- the crossroads: hunger attack
  sec(1.6); shot("faint")
  mash(60)
  shot("after_faint")
  route({ { 596, 400 }, { 596, 200 }, { 620, 162 } })
  face("up"); use("School gate"); sec(0.5)
  shot("school_gate")
  mash(60)
  goto(688, 162); face("right"); use("Something on the ground"); mash(15)
  -- a look at the dealership to the south
  route({ { 596, 200 }, { 596, 470 }, { 650, 600 }, { 650, 780 } })
  sec(0.5); shot("dealership")
  route({ { 650, 600 }, { 720, 600 }, { 760, 620 } })
  mash(15)
  route({ { 760, 600 }, { 800, 580 }, { 1000, 580 }, { 1096, 470 } })
  shot("store_approach")
  goto(1096, 440)
  sec(1.0); shot("store_door")
  mash(60)
  sec(4)
  if scene() ~= G.sceneList.ending then fail("ending not reached") end
  sec(6); shot("ending")
  if not Game.flag("reached_store") then fail("reached_store flag missing") end
  if G.state.stage ~= 3 then fail("stage is " .. G.state.stage) end
  for _, id in ipairs({ "phone", "key", "coin", "backpack", "water", "coke", "meat", "knife", "lock" }) do
    if not Game.has(id) then fail("missing item " .. id) end
  end
  sec(4)
  tap("interact"); sec(2.5)
  if scene() ~= G.sceneList.title then fail("did not return to the title") end
end

function Bot.start(args)
  out = type(args.out) == "string" and args.out or "tests/out"
  os.execute("mkdir -p " .. out)
  Input.setVirtual(true)
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
