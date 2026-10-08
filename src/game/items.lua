-- Item definitions. `use(game)` returns true when the item was consumed.
local G = require("src.g")

local Items = {}

Items.order = { "phone", "key", "coin", "knife", "water", "coke", "meat", "backpack", "lock", "staff_key" }

Items.defs = {
  coin = {
    name = "Coin",
    icon = "coin",
    stack = true,
    desc = "A dull, sticky coin. Every one counts tonight.",
  },
  water = {
    name = "Bottle of Water",
    icon = "water",
    desc = "Half-empty. The cap was already loose when I found it.",
    useLabel = "Drink",
    use = function(game)
      game.say({ "I drink it all in one go.", "It tastes like the pipes. My stomach just gets angrier." })
      game.addHunger(-4)
      return true
    end,
  },
  coke = {
    name = "Can of Coke",
    icon = "coke",
    desc = "Warm. Probably flat. Sugar is sugar.",
    useLabel = "Drink",
    use = function(game)
      G.audio.play("can_open", 0.8)
      game.say({ "Tssk. Flat and warm.", "My hands stop shaking. A little." })
      game.addHunger(-10)
      return true
    end,
  },
  meat = {
    name = "Raw Meat",
    icon = "meat",
    desc = "Grey at the edges, sweating through the plastic. The smell gets into my teeth.",
    useLabel = "Eat",
    use = function(game)
      game.say({ "...", "No. Not raw. I'm not that far gone.", "Not yet." })
      return false
    end,
  },
  knife = {
    name = "Kitchen Knife",
    icon = "knife",
    desc = "Dull blade, sticky handle. Better than nothing.",
    useLabel = "Equip",
    use = function(game)
      local st = G.state
      if st.equipped == "knife" then
        st.equipped = nil
        game.say({ "I put the knife away." })
      else
        st.equipped = "knife"
        game.say({ "I tuck the knife into my waistband.", "Just in case. It's 2AM, after all." })
      end
      return false
    end,
  },
  backpack = {
    name = "Backpack",
    icon = "backpack",
    desc = "Stuffed full of old newspapers. Rubbish... so why do I keep them?",
    useLabel = "Read",
    use = function(game)
      game.readNewspaper()
      return false
    end,
  },
  key = {
    name = "Building Key",
    icon = "key",
    desc = "Opens the front door of the building. The tag says 4B in my handwriting.",
  },
  phone = {
    name = "Cellphone",
    icon = "phone",
    desc = "Cracked screen. 9% battery. No signal, as usual. One unread message.",
    useLabel = "Flashlight",
    use = function(game)
      game.toggleFlashlight()
      return false
    end,
  },
  staff_key = {
    name = "Staff Room Key",
    icon = "key",
    desc = "Vincent's key. A rubber band around it, and a little plastic tag that says DON'T.",
  },
  lock = {
    name = "Broken Padlock",
    icon = "lock",
    desc = "Rusted through. The shackle was snapped, not picked. Someone wanted in.\nOr out.",
  },
}

function Items.get(id)
  return Items.defs[id]
end

return Items
