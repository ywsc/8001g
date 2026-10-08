-- DIALOGUEWRED1 - the red-haired woman lying in the headlights.
-- Only the opening (asking if she's okay) is written; the rest of this
-- conversation is still to be designed. Extend `nodes`/`topics` from "stirs".
local Game = require("src.game.game")

local function N(text) return { text, who = "narration" } end

local R = {
  id = "red",
  name = "???",
  startOpen = 10,
  leaveText = "(Step back.)",
}

function R.start(npc)
  if not npc.met then return "first" end
  return "again"
end

function R.face() return "red" end

R.nodes = {
  first = {
    say = { N("She's face down on the asphalt, right in the middle of the headlight beam."),
      N("Red hair, soaked through. A dark coat. One arm stretched out like she was reaching for something."),
      N("The engine idles behind you. Nobody's in the car.") },
    go = "hub",
  },
  again = { say = { N("She hasn't moved.") }, go = "hub" },
  hub = { hub = true, say = {} },

  ok = {
    say = { N("Nothing. Then, very slowly, her fingers curl against the asphalt.") },
    run = function(npc) npc.flags.asked = true end,
    go = "hub",
  },
  hear = {
    say = { N("Her shoulders rise and fall. She's breathing. Shallow, but breathing.") },
    run = function(npc) npc.flags.breathing = true end,
    go = "hub",
  },
  touch = {
    say = { N("You crouch and put a hand on her shoulder. The coat is ice cold, colder than the night."),
      N("She flinches. Not away from you. Toward the ground.") },
    run = function(npc) npc.flags.touched = true end,
    go = "stirs",
  },
  call = {
    say = { N("You pull out your phone. No signal. 5% battery."), N("You put it away.") },
    go = "hub",
  },
  -- TODO(design): DIALOGUEWRED1 continues from here.
  stirs = {
    say = { N("She says something into the asphalt. Too quiet to make out.") },
    run = function(npc) Game.setFlag("red_spoke") end,
    go = "hub",
  },
  leave = { say = { N("You step back into the dark, out of the light.") }, exit = true },
}

R.topics = {
  { id = "ok", text = "Hey. Hey, are you okay?", go = "ok" },
  { id = "hear", text = "Can you hear me?", go = "hear", when = function(npc) return npc.flags.asked end },
  { id = "touch", text = "(Touch her shoulder.)", go = "touch", when = function(npc) return npc.flags.asked end },
  { id = "call", text = "(Call for help.)", go = "call", when = function() return Game.has("phone") end },
}

function R.onExit(npc)
  Game.setFlag("met_red")
end

return R
