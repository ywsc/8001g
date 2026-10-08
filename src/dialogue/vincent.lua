-- DIALOGUEWVINCENT1 - Vincent, night clerk at the 24/7 MART.
-- Secret: he hates the job and is lonely and desperate, every day.
-- He only gives up the staff room key in a later conversation, after he
-- has told you (flag vincent_secret = "out") and only if you ask.
local G = require("src.g")
local Game = require("src.game.game")

local function N(text) return { text, who = "narration" } end
local function Y(text) return { text, who = "you" } end

local V = {
  id = "vincent",
  name = "Vincent",
  startOpen = 20,
  leaveText = "That's all.",
}

function V.start(npc)
  if not npc.met then return "greet" end
  if npc.open <= 0 then
    npc.open = 12
    return "again_cold"
  end
  if npc.secret then return "again_after" end
  return "again"
end

function V.face(npc)
  if npc.open < 35 or npc.flags.raw then return "vincent_low" end
  return "vincent"
end

V.nodes = {
  -- ------------------------------------------------------------ openings
  greet = {
    say = { N("He doesn't look up from his phone right away."), "Hey.", "Hot food's by the coffee. I wouldn't get the hot dogs." },
    choices = {
      { text = "Why not the hot dogs?", open = 5, go = "hotdogs" },
      { text = "Rough night?", go = "rough" },
      { text = "I just need something to eat.", go = "food_where" },
    },
  },
  hotdogs = { say = { "They've been on the roller since nine.", "That's five hours of turning. Your call." }, go = "hub" },
  rough = { say = { "It's a night.", N("He puts the phone face down on the counter.") }, go = "hub" },
  food_where = { say = { "Bread and noodles are aisle two. Everything's aisle two, kind of.", "I can ring you up when you're ready." }, go = "hub" },

  again = {
    say = function(npc)
      if npc.open >= 55 then return { "Hey. You find everything?" } end
      return { "Back again." }
    end,
    go = "hub",
  },
  again_cold = { say = { N("He sighs before you get to the counter."), "...What." }, go = "hub" },
  again_after = {
    say = { N("He looks up when you come over. That's new."), "Hey. You're still here." },
    go = "hub",
  },

  -- ------------------------------------------------------------ hub
  hub = {
    hub = true,
    -- no extra line: the last thing he said stays on screen while you choose
    say = {},
  },

  -- ------------------------------------------------------------ "you look tired"
  tired = {
    say = { "It's two in the morning. Everybody looks tired." },
    choices = {
      { text = "Not like you, though.", open = 8, go = "tired_real" },
      { text = "Fair enough.", go = "hub" },
      { text = "You look like hell, man.", open = -12, go = "tired_rude" },
    },
  },
  tired_real = {
    say = { N("He rubs his eyes with the heel of his hand."), "Yeah. I don't sleep much.", "Days are too loud. Nights I'm here." },
    go = "hub",
  },
  tired_rude = { say = { "Thanks.", "You buying something, or just reviewing me?" }, go = "hub" },

  -- ------------------------------------------------------------ "how long"
  howlong = {
    say = { "Four years in March. Nights, the whole time." },
    choices = {
      { text = "Four years of nights. That's a lot.", open = 8, go = "howlong_a" },
      { text = "Do you like it?", need = 50, fail = "like_early", go = "like_late" },
      { text = "Huh.", go = "hub" },
    },
  },
  howlong_a = {
    say = { "You stop noticing after a while.", "Days, nights. It's all just the shift.", "I start counting things. Cans. Cars going past. Hours." },
    run = function(npc) npc.flags.counting = true end,
    go = "hub",
  },
  like_early = { say = { "It's a job." }, go = "hub" },
  like_late = { say = { N("He takes a long time to answer."), "...It pays the rent. Mostly." }, go = "hub" },

  -- ------------------------------------------------------------ "always this quiet"
  quiet = {
    say = { "After one it's me, the fridges, and whoever can't sleep.", "Tonight that's you." },
    choices = {
      { text = "Who else comes in this late?", open = 6, go = "regulars" },
      { text = "Must be peaceful.", open = -4, go = "peaceful" },
    },
  },
  regulars = {
    say = { "Cab drivers. Nurses coming off a shift.", "One guy buys a single egg every night. One egg. Four years.", "I've never asked him why." },
    choices = {
      { text = "You should ask him.", open = 4, go = "egg_ask" },
      { text = "That's weird.", go = "egg_weird" },
    },
  },
  egg_ask = { say = { "Then I'd have nothing left to wonder about." }, go = "hub" },
  egg_weird = { say = { "Everyone's weird at three in the morning.", "You're probably weird too." }, go = "hub" },
  peaceful = { say = { "Sure. Peaceful." }, go = "hub" },

  -- ------------------------------------------------------------ the missing boy (clue from the newspaper / flyer)
  kid = {
    say = { N("He glances at the poster taped by the door."),
      "His mom put that up herself. Came in, asked if she could. I said yeah.",
      "Then she just stood by the door for a while. Didn't buy anything." },
    choices = {
      { text = "Did you know him?", open = 7, go = "kid_knew" },
      { text = "He probably ran away.", open = -10, go = "kid_ran" },
    },
  },
  kid_knew = {
    say = { "He came in with his dad for slushies. Blue ones. Turned his whole mouth blue.",
      "I see that poster every shift. Eight hours a night." },
    go = "hub",
  },
  kid_ran = { say = { "He's eight." }, go = "hub" },

  -- ------------------------------------------------------------ after the shift
  after = {
    say = { "Go home. Sleep till three. Eat something out of the microwave.", "Laptop. Come back." },
    choices = {
      { text = "That sounds lonely.", need = 40, fail = "lonely_early", open = 12, go = "lonely" },
      { text = "Anyone waiting for you at home?", need = 45, fail = "home_early", open = 8, go = "plant" },
      { text = "Sounds peaceful.", open = -5, go = "peaceful2" },
    },
  },
  lonely_early = { say = { "I didn't ask for a review." }, go = "hub" },
  lonely = {
    say = { N("He straightens a stack of lighters that was already straight."), "It's fine.", "...It's fine. I'm used to it." },
    run = function(npc) npc.flags.lonely = true end,
    go = "hub",
  },
  home_early = { say = { "That's kind of a personal question, man." }, go = "hub" },
  plant = {
    say = { "A plant.", "It's mostly dead. I keep watering it anyway." },
    run = function(npc) npc.flags.lonely = true end,
    go = "hub",
  },
  peaceful2 = { say = { "Yeah. Everybody keeps saying that." }, go = "hub" },

  -- ------------------------------------------------------------ the approach
  okay = {
    say = function(npc)
      if npc.open < 60 then return { "I'm fine. Do you want something or not?" } end
      return { N("He stops moving."), "...", "Why do you care? You don't know me." }
    end,
    choices = function(npc)
      if npc.open < 60 then return {} end
      return {
        { text = "I don't. That's why you can tell me.", open = 10, go = "secret" },
        { text = "Forget it. Sorry.", go = "okay_drop" },
        { text = "Come on. Just say it.", open = -15, go = "okay_push" },
      }
    end,
    run = function(npc, conv)
      if npc.open < 60 then
        conv:changeOpen(-5)
        npc.done.okay = nil -- he can be asked again later
      end
    end,
  },
  okay_drop = { say = { "Yeah." }, run = function(npc) npc.done.okay = nil end, go = "hub" },
  okay_push = { say = { "There's nothing to say. Sorry." }, run = function(npc) npc.done.okay = nil end, go = "hub" },

  secret = {
    face = "vincent_low",
    run = function(npc, conv)
      npc.flags.raw = true
      conv:revealSecret()
    end,
    say = { N("He looks at the counter for a long time."),
      "I hate this job.",
      "I hate it so much I can feel it in my teeth. I come in at ten and count the hours until six. Then I go home and count the hours until ten.",
      "Nobody talks to me. People look right through me. Like I'm part of the counter.",
      "Some nights I think if I just didn't show up, it'd take them a week to notice. Maybe longer.",
      N("He laughs, but not really."),
      "...Sorry. I don't know why I told you that." },
    choices = {
      { text = "I'd notice.", open = 10, go = "secret_notice" },
      { text = "Thanks for telling me.", open = 5, go = "secret_thanks" },
    },
  },
  secret_notice = { say = { "You don't even know my name." }, choices = { { text = "It's on your tag. Vincent.", open = 5, go = "secret_name" } } },
  secret_name = { say = { N("He looks down at the tag like he forgot it was there."), "...Yeah. Okay." }, go = "hub" },
  secret_thanks = { say = { "Don't make it weird." }, go = "hub" },

  -- ------------------------------------------------------------ the staff room
  staff_no = { say = { "Staff only. Sorry.", "There's a bathroom at the gas station on Fifth." }, run = function(npc) npc.done.staff = nil end, go = "hub" },
  staff_yes = {
    say = { N("He thinks about it. Then he digs in his pocket."),
      "It's not really a staff room. It's more like... where I go.",
      "Here. Don't touch my pasta.",
      N("He slides a key across the counter.") },
    run = function(npc)
      Game.give("staff_key")
      npc.flags.gaveKey = true
    end,
    go = "hub",
  },

  -- ------------------------------------------------------------ buying food
  buy = {
    say = { "Bread, noodles, a can of soup. The hot dogs, if you hate yourself." },
    choices = function(npc)
      local c = {}
      local canPay = Game.count("coin") >= 3 or Game.has("phone")
      if canPay then
        c[#c + 1] = { text = "Bread and a can of soup.", go = "buy_done", once = false }
      else
        c[#c + 1] = { text = "Bread and a can of soup.", go = "buy_broke", once = false }
      end
      c[#c + 1] = { text = "Never mind.", go = "hub", once = false }
      return c
    end,
    run = function(npc) npc.done.buy = nil end,
  },
  buy_broke = { say = { "That's three-fifty.", N("You don't have it.") }, go = "hub" },
  buy_done = {
    run = function(npc, conv)
      local paid
      if Game.count("coin") >= 3 then
        Game.take("coin", 3); paid = "coins"
      else
        paid = "phone"
      end
      npc.flags.paid = paid
      npc.done.buy = true
      Game.setFlag("bought_food")
      Game.addHunger(-55)
      G.audio.play("register", 0.7)
    end,
    say = function(npc)
      if npc.flags.paid == "coins" then
        return { N("You put the three sticky coins on the counter. He doesn't comment."), "Microwave's by the coffee. For the soup.",
          N("You eat the bread right there, standing up. Half the loaf. It's the best thing you've ever eaten.") }
      end
      return { N("You tap the phone. 6% battery. The reader thinks about it."), "...It went through.",
        N("You eat the bread right there, standing up. Half the loaf. It's the best thing you've ever eaten.") }
    end,
    go = "hub",
  },

  -- ------------------------------------------------------------ showing things
  show_paper = { go = "kid", run = function(npc) npc.done.kid = true end },
  show_lock = { run = function(npc, conv) conv:changeOpen(-4) end, say = { N("He looks at the padlock, then at you."), "Where'd you get that?", "...The school. Don't bring that in here, man. People already talk." }, go = "hub" },
  show_knife = { run = function(npc, conv) conv:changeOpen(-25) end, say = { N("He steps back from the counter."), "Put that away. I'm serious." }, go = "hub" },
  show_phone = { say = { "I'm not charging your phone. Policy." }, go = "hub" },
  show_meat = { run = function(npc, conv) conv:changeOpen(3) end, say = { "Did you... bring your own meat? To a store?" }, go = "hub" },
  show_default = { say = { "What am I supposed to do with that?" }, go = "hub" },

  -- ------------------------------------------------------------ endings
  shutdown = {
    say = { "Look, I've got restocking to do.", N("He walks off toward the back aisle and doesn't come back for a while.") },
    exit = true,
  },
  leave = {
    say = function(npc)
      if npc.secret then return { "See you around. Probably." } end
      if npc.open < 30 then return { "Okay." } end
      return { "Take care." }
    end,
    exit = true,
  },
}

V.topics = {
  { id = "buy", text = "I want to buy something to eat.", go = "buy", once = true, when = function(npc) return not Game.flag("bought_food") end },
  { id = "tired", text = "You look tired.", go = "tired" },
  { id = "howlong", text = "How long have you worked here?", go = "howlong" },
  { id = "quiet", text = "Is it always this dead in here?", go = "quiet" },
  { id = "kid", text = "The missing kid on the poster. Thomas.", go = "kid",
    when = function() return Game.flag("read_paper") or Game.flag("saw_flyer") end },
  { id = "after", text = "What do you do when your shift's over?", go = "after",
    when = function(npc) return npc.done.howlong or npc.open >= 35 end },
  { id = "okay", text = "Vincent. Are you actually okay?", go = "okay",
    when = function(npc) return npc.flags.lonely and not npc.secret end },
  { id = "staff", text = "Can I get into the staff room?",
    when = function(npc) return Game.flag("tried_staff_door") and not npc.flags.gaveKey end,
    -- he only hands it over in a later conversation, after he told you and you left
    go = function(npc)
      if npc.secret and Game.flag("vincent_secret") == "out" then return "staff_yes" end
      return "staff_no"
    end },
}

V.present = {
  backpack = "show_paper",
  lock = "show_lock",
  knife = "show_knife",
  phone = "show_phone",
  meat = "show_meat",
  default = "show_default",
}

-- the secret counts as "out" once you leave the conversation in which he told it
function V.onExit(npc)
  if npc.secret then Game.setFlag("vincent_secret", "out") end
end

return V
