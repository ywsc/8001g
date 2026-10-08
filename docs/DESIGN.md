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
