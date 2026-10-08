-- Input wrapper around baton (keyboard + gamepad from one table).
-- A "virtual" source lets the test bot drive the game through the same API.
local baton = require("lib.baton")

local I = {}

local controls = {
  left = { "key:left", "key:a", "axis:leftx-", "button:dpleft" },
  right = { "key:right", "key:d", "axis:leftx+", "button:dpright" },
  up = { "key:up", "key:w", "axis:lefty-", "button:dpup" },
  down = { "key:down", "key:s", "axis:lefty+", "button:dpdown" },
  run = { "key:lshift", "key:rshift", "button:rightshoulder", "axis:triggerright+" },
  interact = { "key:e", "key:space", "key:return", "key:kpenter", "button:a" },
  cancel = { "key:escape", "key:backspace", "button:b" },
  inventory = { "key:tab", "key:i", "button:y" },
  flashlight = { "key:f", "button:x" },
  pause = { "key:escape", "button:start" },
  takeall = { "key:r", "button:leftshoulder" },
  fullscreen = { "key:f11" },
  debug = { "key:f3" },
}

function I.init()
  I.player = baton.new({
    controls = controls,
    pairs = { move = { "left", "right", "up", "down" } },
    joystick = love.joystick and love.joystick.getJoysticks()[1] or nil,
    deadzone = 0.3,
  })
  I.virtual = nil
  I.consumed = {}
end

function I.update()
  I.player:update()
  I.consumed = {}
  if I.virtual then
    local v = I.virtual
    v.prev = v.prevDown or {}
    v.prevDown = {}
    for k, on in pairs(v.down) do v.prevDown[k] = on end
  end
end

-- bot API ---------------------------------------------------------------
function I.setVirtual(on)
  if on then
    I.virtual = { down = {}, prev = {}, prevDown = {} }
  else
    I.virtual = nil
  end
end

function I.press(action) -- held until release()
  if I.virtual then I.virtual.down[action] = true end
end

function I.release(action)
  if I.virtual then I.virtual.down[action] = nil end
end

function I.releaseAll()
  if I.virtual then I.virtual.down = {} end
end

-- queries ---------------------------------------------------------------
function I.down(a)
  if I.virtual then return I.virtual.down[a] == true end
  return I.player:down(a)
end

function I.pressed(a)
  if I.consumed[a] then return false end
  if I.virtual then
    return I.virtual.down[a] == true and not I.virtual.prev[a]
  end
  return I.player:pressed(a)
end

-- mark a press as handled so nothing else reacts to it this frame
function I.consume(a)
  I.consumed[a] = true
end

function I.move()
  if I.virtual then
    local x = (I.down("right") and 1 or 0) - (I.down("left") and 1 or 0)
    local y = (I.down("down") and 1 or 0) - (I.down("up") and 1 or 0)
    return x, y
  end
  return I.player:get("move")
end

function I.usingGamepad()
  return I.player and I.player:getActiveDevice() == "joy"
end

return I
