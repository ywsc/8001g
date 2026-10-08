# HOLLOW HOURS — Research, Proposal & Plan (Scenes 1–2)

A 2D top-down (3/4 view) narrative horror / survival game for LÖVE 11.5.
This document records the **Research → Propose → Plan** phases that preceded
implementation of the first two scenes.

---

## 1. Research

### 1.1 Library survey (awesome-love2d, magictools)

| Need | Candidates looked at | Chosen | Why |
|---|---|---|---|
| OOP | classic, middleclass, 30log, hump.class | **classic** (rxi) | 1 KB, no magic, MIT |
| Tweening | flux, tween.lua, hump.timer | **flux** (rxi) | tiny, chainable, groups |
| Utilities | lume, batteries | **lume** (rxi) | lerp/clamp/distance/weighted choice |
| Collision | bump.lua, slick, HC, breezefield | **bump.lua** (kikito) | AABB "slide" response is exactly what a top-down walker needs |
| Sprite animation | anim8, lovanim | **anim8** (kikito) | grid/quad based, works with any sheet |
| Input | baton, tactile, input | **baton** (tesselode) | keyboard + gamepad from one binding table, injectable for tests |
| Post-processing | moonshine, ShaderScan | **moonshine** (vrld) | glow, vignette, film grain, chroma-sep, blur, desaturate chain |
| Lighting | light_world, lighter, Shädows, bitumbra | **custom deferred shader** | none support normal-mapped *and* height-field shadowing for a 3/4 view; a ~150-line shader gives full control |
| Camera / scenes / dialogue | gamera, hump.camera, SceneMan, Love-Dialogue | custom (small) | they are a few dozen lines each; tight integration with lighting + cutscene scripting |
| Fonts | Google Fonts (OFL) | **VT323**, **Silkscreen**, **Pixelify Sans** | pixel fonts that read well when scaled; OFL licensed |

### 1.2 Art pipeline research

The brief prefers AI‑generated art from external tools. The services listed in
magictools and the usual image APIs were probed from the build environment:
`image.pollinations.ai`, `api.openai.com`, `huggingface.co` (+inference/router),
`api.replicate.com`, `stablehorde.net`/`aihorde.net`, `api.stability.ai`,
`api.ludo.ai`, `api.pixellab.ai`, `spritefusion.com`, `opengameart.org`,
`itch.io`, `kenney.nl` — **all rejected (HTTP 403) by the environment's egress
policy.** Model weights (Hugging Face) are blocked as well, so a local diffusion
model was not an option either.

**Fallback (chosen):** all art is *machine-generated* by a deterministic
procedural pixel-art generator written for this project (`tools/gen_assets.py`).
It is designed around how pixel artists work, not around noise:

* hue-shifted material **ramps** (cool shadows → warm highlights), posterised
  with ordered (Bayer) dithering so surfaces read as hand-placed pixels;
* 3/4 **box modelling** (top face + front face) so every object has real form;
* every sprite is emitted as four maps: **albedo**, **normal**, **height** and
  **emissive** — the engine relights the scene every frame (point lights,
  flicker, a phone flashlight cone, and soft height-field shadows).

The generator is re-runnable; if the network policy later allows an AI image
service, any `assets/gfx/*.png` albedo can be replaced 1:1 while keeping the
normal/height maps (or regenerating them from the new albedo).

Audio follows the same rule: `tools/gen_audio.py` synthesises ambience and
SFX (numpy/scipy → ogg).

---

## 2. Proposal

* **View:** top-down 3/4 (not a side scroller). Internal resolution
  480×270 upscaled with integer nearest-neighbour scaling.
* **Look:** dim, desaturated, realistic textures; a near-black ambient so the
  player depends on practical lights (bedside lamp, flickering fluorescent,
  fridge light, TV static, street lamps, store neon) and the phone flashlight.
  Post: bloom on emissive pixels, vignette, film grain, faint chromatic split.
* **Tone:** inner monologue in a typewriter text box; no jump-scare spam —
  slow dread (the clock, the hunger, things that are not quite right).
* **Systems:** inventory with use/examine, container UI (fridge), quest
  tracker with stages and alternatives, in-game clock (starts 02:03), hunger
  status, interaction prompts, toasts, pause menu, fullscreen toggle, gamepad.

### Scene 1 — The Apartment (02:03 AM)
Bedroom, bathroom, kitchen, living room / front door, all filthy.
Items: fridge → water, coke, raw meat, knife; bathroom floor → 1 coin;
bedroom → backpack (old newspapers), building key, cellphone, 2 coins on the bed.
* **Stage 1:** find 3 coins **or** the cellphone.
* **Stage 2:** go out (front door needs the key) and reach the store.

### Scene 2 — The Neighbourhood
Crossroads with four directions: **N** locked school gate (childhood memory,
broken lock on the ground), **E** the 24-hour store (goal), **S** car
dealership, **W** more apartment blocks. On reaching the crossroads the
character is hit by a wave of hunger and nearly faints (blur, desaturate,
heartbeat, monologue) and decides to hurry to the store.

---

## 3. Plan

1. Skeleton: `conf.lua`, `main.lua`, vendored libs, fonts + licences.
2. Asset generator → `assets/gfx` (backgrounds from `maps/*.txt`, props,
   player sheet, item icons).
3. Audio generator → `assets/sfx`.
4. Engine: renderer (G-buffer MRT → lighting shader → moonshine post →
   scaler), camera, input, audio, scene manager, cutscene scripting.
5. Game layer: state (inventory, quests, flags, clock, hunger), items, world
   (grid walls, props, y-sorted entities, interactables, triggers, lights),
   player.
6. UI: dialogue, HUD, inventory, container, prompts, toasts, menus.
7. Scenes: title → apartment → neighbourhood → chapter end.
8. Tests: headless logic tests + a scripted bot playthrough that completes
   both scenes and captures screenshots for visual QA (`tools/run_tests.sh`).

---

## 4. Interrogation mode (Scene 3 onward)

The game now has two phases:

* **Exploration** (top-down, as before): walk around, read things, pick up
  items. Items and flags gathered here are **clues**.
* **Face-to-face** (first person): talking to an NPC switches the screen to a
  painted view of them across from you. The world disappears; it's just their
  face, the light and what you say.

### Secrets

Every NPC has a **secret**. It's reached by talking, not by picking the right
option once:

* Each NPC has a hidden **openness** (0–100) that persists between
  conversations. The header shows a mood word (*shut off, guarded, wary,
  listening, open*) and a one-line cue when it moves.
* Kind, attentive replies raise it. Pushing, rudeness and showing the wrong
  item lower it. At 0 the NPC ends the conversation. They thaw a little when
  you come back.
* Some topics only appear after other topics, after something you saw while
  exploring (e.g. reading the newspaper unlocks *"The missing kid"*), or past
  an openness threshold.
* **Show something...** lets you present any inventory item as a clue.
* The secret needs the right approach at the right openness. Once told:
  `npc.secret = true`, the header shows *SECRET LEARNED*, and story
  consequences unlock: flags, new topics, items.

### Scene 3 – the 24/7 MART

Three cells with fade transitions: the **shop floor**, the **staff room**
(locked) and the **parking lot**.

* **DIALOGUEWVINCENT1** (`src/dialogue/vincent.lua`): greeting → *you look
  tired* → *how long have you worked here* → regulars, the missing boy (clue),
  what he does after his shift → *are you actually okay?* → secret (he hates
  the job; lonely and desperate every day). Leaving the conversation after
  that sets `vincent_secret = "out"`. In a **later** conversation, if you ask
  about the staff room, he gives you the key. You can also buy food from him
  here, which finally deals with the hunger.
* **Staff room**: Vincent's laptop (messages, tabs, a spreadsheet counting
  days), leftover pasta (you can eat it), a 2009 pin-up calendar, his cot and
  lockers. The note on the wall says **"wake up"**. Reading it teleports you to
  **Scene 4**, which is a placeholder until it's designed.
* **Parking lot**: a car idling with its headlights on and the driver's door
  open. Following the beam leads to a red-haired woman lying face down.
  Interacting starts **DIALOGUEWRED1** (`src/dialogue/red.lua`). Only the
  opening is written so far; the file marks where it continues.

### Art for face-to-face scenes

Painted with an AI image model (pollinations.ai, free), cached in
`assets/ai_src/`, then pixelated to 480×270 with a limited palette by
`tools/ai_art.py`. The model can't make isolated game sprites, so the top-down
cells still use the procedural generator.

### Writing a new NPC

Copy `src/dialogue/red.lua`. Each node is `{ say = lines, choices = {...} }`,
and a line can be plain text (the NPC speaks), `{text, who="narration"}` or
`{text, who="you"}`. Choices take `open = ±n`, `need = minimum openness`,
`when = fn`, `go = node | fn`. Topics show in the hub menu. `present` maps item
ids to reaction nodes. Call `conv:revealSecret()` in the secret node.
