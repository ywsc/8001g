# Hollow Hours

A 2D top-down (3/4 view) **narrative horror / survival** game for **LÖVE 11.5**.
It's 2 AM on Alder Street. You wake up starving in a filthy apartment and need
to get to the 24-hour store. This is not an action game: you explore, pick
things up, read, and remember. Combat comes later in the game.

This repository contains **Part I — Empty**: two scenes, playable from the
title screen to the chapter ending.

## Running

```bash
love .                      # play
love . --scene apartment    # jump to a scene (apartment | neighborhood), add --skip-intro
tools/run_tests.sh          # headless logic tests
tools/run_tests.sh --bot    # + scripted full playthrough, screenshots in tests/out/
```

## Controls

| Action | Keyboard | Gamepad |
|---|---|---|
| Move | WASD / arrow keys | left stick / d-pad |
| Run | Shift | RB / RT |
| Interact / continue | E, Space, Enter | A |
| Inventory | Tab / I | Y |
| Phone flashlight | F (once you have the phone) | X |
| Take all (containers) | R | LB |
| Pause / back | Esc | Start / B |
| Fullscreen | F11 | |

## The two scenes

**Scene 1: Apartment 4B, 02:03 AM.** Bedroom, bathroom, kitchen and living room,
all filthy. You wake up hungry. The fridge has water, a flat coke, raw meat and a
knife. There's a coin on the bathroom floor. In the bedroom: a backpack full of old
newspapers (you can read them), the building key, your cellphone, and two coins on
the bed.
* **Stage 1:** find **3 coins** *or* your **cellphone**.
* **Stage 2:** leave the apartment (the deadbolt needs the key) and reach the store.

**Scene 2: Alder Street.** The street is a crossroads.
* **North:** the locked gate of the elementary school. It brings back a childhood
  memory. A broken padlock lies on the ground nearby.
* **East:** the 24/7 MART, which is the goal.
* **South:** a closed car dealership.
* **West:** more apartment blocks.

At the crossroads, hunger hits you hard and you nearly faint (blur, desaturation,
heartbeat, tinnitus). After that you hurry to the store, and reaching it ends
Part I.

## Tech overview

* **Deferred 2D lighting** (`src/core/renderer.lua`). Sprites are drawn into four
  canvases at once (albedo, normal, emissive, height) using multiple render targets.
  A full-screen shader then adds up to 32 point and spot lights. Each light uses
  normal mapping, flicker, a glow around the bulb, and **soft shadows**: rays are
  marched across the height buffer, so anything tall casts a shadow (the player,
  furniture, buildings, trees). After that comes a filmic roll-off and a post chain
  through `moonshine`: bloom on emissive pixels, desaturation and blur for the
  faint, chromatic split, vignette and film grain. Last, a sharp-bilinear upscale
  takes the 480×270 internal resolution to any window size.
* **World** (`src/world`): bump.lua collisions, y-sorted props and entities,
  interactables, triggers, animated lights, roaches, item glints, steam, cat eyes,
  a figure that vanishes when you get close, pennants and power lines.
* **UI** (`src/ui`): typewriter monologue box, an objective tracker with alternative
  objectives, the clock and hunger HUD, toasts, interaction prompts, the inventory
  (use / equip / read), the fridge container, a newspaper reader and the pause menu.
* **Cutscenes**: a coroutine script runner (`src/core/script.lua`).

### Libraries (from awesome-love2d, all MIT)
[classic](https://github.com/rxi/classic), [flux](https://github.com/rxi/flux),
[lume](https://github.com/rxi/lume), [bump.lua](https://github.com/kikito/bump.lua),
[anim8](https://github.com/kikito/anim8), [baton](https://github.com/tesselode/baton),
[moonshine](https://github.com/vrld/moonshine). These are vendored in `lib/`.

### Art and audio pipeline

The brief asked for AI-generated art. This build environment's network policy
blocked every image-generation service I tried (pollinations, Hugging Face,
Replicate, Stability, AI Horde, Ludo, PixelLab, SpriteFusion; see
`docs/DESIGN.md`). So all art comes from a deterministic **procedural pixel-art
generator** written for this project:

```bash
python3 tools/gen_assets.py   # -> assets/gfx  (needs numpy, scipy, pillow)
python3 tools/gen_audio.py    # -> assets/sfx  (needs numpy, scipy, ffmpeg)
```

It builds every sprite as albedo, normal, height and emissive maps. It uses
hue-shifted material ramps with ordered dithering and 3/4 box modelling, so the
engine can relight everything at runtime. Any albedo PNG can later be swapped for
an externally generated image while keeping the same file name.

Fonts: VT323, Silkscreen and Pixelify Sans (SIL Open Font License, see `assets/fonts/`).

## Layout

```
main.lua, conf.lua      entry point (+ --test / --bot / --scene / --shot flags)
src/core/               renderer, input, audio, camera, scenes, script, assets
src/game/               rules: inventory, quests, clock, hunger, items
src/world/              world, player, entities
src/ui/                 theme + all interface widgets
src/scenes/             title, apartment, neighborhood, ending
maps/                   tile layouts shared by the generator and the game
tools/                  asset/audio generators, test runner
tests/                  logic tests and the playthrough bot
docs/DESIGN.md          research, proposal and plan
```
