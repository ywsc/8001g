-- HOLLOW HOURS - a 2D narrative horror game for LOVE 11.
local G = require("src.g")
local R = require("src.core.renderer")
local Input = require("src.core.input")
local Audio = require("src.core.audio")
local SM = require("src.core.scenes")
local UI = require("src.ui.ui")
local Game = require("src.game.game")

local args = {}
local debugOverlay = false

local function parseArgs(list)
  local i = 1
  while i <= #list do
    local a = list[i]
    if a:sub(1, 2) == "--" then
      local key = a:sub(3)
      local nxt = list[i + 1]
      if nxt and nxt:sub(1, 2) ~= "--" then
        args[key] = nxt
        i = i + 1
      else
        args[key] = true
      end
    end
    i = i + 1
  end
end

function G.toggleFullscreen()
  love.window.setFullscreen(not love.window.getFullscreen(), "desktop")
  R.resize(love.graphics.getDimensions())
end

function G.showControls()
  UI.say({
    { text = "Move: WASD / Arrow keys / Left stick.   Run: Shift.", style = "system" },
    { text = "Interact / Continue: E, Space or Enter.   Inventory: Tab or I.", style = "system" },
    { text = "Phone flashlight: F (once you have the phone).   Pause: Esc.   Fullscreen: F11.", style = "system" },
  })
end

function love.load(arglist)
  parseArgs(arglist or {})
  love.graphics.setDefaultFilter("nearest", "nearest")
  love.mouse.setVisible(false)
  R.init()
  Input.init()
  Audio.init()
  UI.init()
  G.renderer, G.input, G.audio, G.ui, G.scenes = R, Input, Audio, UI, SM
  Game.reset()

  G.sceneList = {
    title = require("src.scenes.title")(),
    apartment = require("src.scenes.apartment")(),
    neighborhood = require("src.scenes.neighborhood")(),
    mart = require("src.scenes.mart")(),
    scene4 = require("src.scenes.scene4")(),
  }

  if args.test then
    require("tests.run").start(args)
    return
  end
  if args.bot then
    require("tests.bot").start(args)
    return
  end
  local start = args.scene or "title"
  if start ~= "title" then
    Game.reset()
    if args.stage then G.state.stage = tonumber(args.stage) end
  end
  SM.switch(G.sceneList[start], { skipIntro = args["skip-intro"], cell = args.cell,
    spawn = args.cell and (args.cell == "store" and "from_street" or "from_store") or nil })
  if args.talk == "vincent" then G.sceneList.mart:talkVincent() elseif args.talk == "red" then G.sceneList.mart:talkRed() end
  R.debugView = args.view
  R.debugPrint = args.lightdump
  R.onlyLight = tonumber(args.onlylight)
  if args.shot then SM.fade = 0 end
  if args.shot then
    G.shot = { path = args.shot, frames = tonumber(args.frames or 60) }
  end
end

local frame = 0
function love.update(dt)
  dt = math.min(dt, 1 / 20)
  if args.fixeddt then dt = 1 / 60 end
  frame = frame + 1
  if G.hook then G.hook(dt) end   -- the test bot presses keys before input is sampled
  Input.update()
  if Input.pressed("fullscreen") then G.toggleFullscreen() end
  if Input.pressed("debug") then debugOverlay = not debugOverlay end
  SM.update(dt)
  Audio.update(dt)
end

function G.capture(path, cb)
  love.graphics.captureScreenshot(function(img)
    local data = img:encode("png")
    local f = io.open(path, "wb")
    if f then
      f:write(data:getString())
      f:close()
    end
    if cb then cb() end
  end)
end

function love.draw()
  -- the test bot only renders the frames it captures (software GL is slow)
  if G.renderOnDemand and not G.renderNext then return end
  G.renderNext = false
  SM.draw()
  R.beginUI()
  if SM.current and SM.current.drawUI then SM.current:drawUI() else UI.draw() end
  SM.drawOverlay()
  if debugOverlay then
    love.graphics.setFont(require("src.ui.theme").fLabel)
    love.graphics.setColor(0, 1, 0, 1)
    local pl = G.world and G.world.player
    love.graphics.print(string.format("FPS %d  lights %d  pos %s", love.timer.getFPS(), R.lightCount or 0,
      pl and string.format("%d,%d", pl.x, pl.y) or "-"), 10, 520)
    love.graphics.setColor(1, 1, 1, 1)
  end
  R.endUI()
  R.present()
  if G.shot then
    G.shot.frames = G.shot.frames - 1
    if G.shot.frames == 0 then
      G.capture(G.shot.path, function() love.event.quit() end)
    end
  end
end

function love.resize(w, h)
  R.resize(w, h)
end

function love.joystickadded(j)
  if Input.player then Input.player.config.joystick = j end
end
