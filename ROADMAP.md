# DOOM Swift — Development Status & Roadmap

This document tracks where the project stands and what comes next. It is the
place to look before starting new work; update it when a milestone lands.

## Status snapshot

| Area | State |
|------|-------|
| Rendering | Complete. Four Metal compute passes per frame at 960×600 (floor/ceiling with torch light, DDA walls + z-buffer, z-tested sprites + weapon overlay, screen effects + sharp-bilinear pixel-art upscale) presented straight into an `MTKView` with three frames in flight and no CPU readback; the view's display link drives the game loop. A multi-core CPU raycaster with CPU sprite compositing remains as the fallback when Metal is unavailable. |
| Player | Three playable marines (Sarge, Viper, Grimm) with distinct portraits, starting weapon, armor and speed. Movement with wall sliding and unstick, sprint, view bob, armor absorption, berserk, keys, 5 weapons (fist, pistol, shotgun, chaingun, rocket launcher with splash damage) with switch/fire animations. |
| Enemies | 4 types (imp, WWII German infantryman, demon, and the Baron of Hell boss). State machine: idle → patrol → chase → attack → hurt → dying → dead. Line-of-sight detection, projectile and melee attacks, tile-based pathfinding when out of sight, door opening, pain chance, wandering patrols. Bosses claw up close, throw plasma at range, keep advancing between attacks and show a HUD health bar. |
| World | 32×32 tile maps, 11 tile types, regular + colour-locked doors with auto-close, damage floors (nukage), exit portal, per-level difficulty scaling. |
| Campaign | 4 levels with briefings, data-driven mission objectives (item retrieval / extermination), level summary with rating, campaign summary, death restarts the current level. |
| UI / feedback | Title with skill select, settings menu, briefing (typewriter), pause menu, death, level and campaign summary screens (with per-level records, secrets and items tallies). HUD with 42-frame DOOM face, fog-of-war minimap (TAB), objective tracker, status messages, directional damage flash, hit marker, blood spurts on hits, screen shake, muzzle flash, death camera. |
| Platforms | macOS (keyboard, mouse, controller) and iOS / iPadOS (touch controls, controller, hardware keyboard) from one target; landscape only on iOS. |
| Audio | Fully procedural: 14 sound effects and one looping BGM track per level (4 tracks), generated at runtime with AVAudioEngine. |
| Assets | Only the app icon on disk (generated pixel art). Wall/floor textures, face frames, projectiles, explosions and sounds are generated procedurally in Swift; the exit portal is procedural too, designed in `tools/sprite_art/portal.py` and ported line for line. The four enemy sheets, the five first-person weapons (240×150) and the 14 pickups (32×32) are pixel art authored in `tools/sprite_art/*.py` on a turntable rig (a 3D part layout projected to the front, 3/4, side, back-3/4 and back views, with automatic cel shading, contact shadows and outlines; 41 frames each at 64×96 / 96×96 / 96×120, with a six-frame death sequence choreographed per enemy) and baked into `BakedSpriteData.swift` as run-length strings by `tools/sprite_art/build.py`. Enemies show the rotation that matches their facing relative to the player, mirrored for the other side, with 6° of hysteresis so a facing on a sector boundary does not flicker. |
| Tooling | `tools/validate_levels.py` statically checks every level (reachability, key gating, entity placement). GitHub Actions builds the app on a macOS runner, builds and tests it for the iOS Simulator, and runs the validator on every push and PR. `tools/verify_local.sh` syncs a Mac clone to `main`, validates, builds with the newest Xcode and launches the app for a play-test. `fpsgame1Tests` (XCTest, hosted by the app) covers the Foundation-only engine: world/door solidity, navigation field, player movement and camera, weapons, enemy state machine, level flow and shipped level data. CI runs the tests in Debug and then builds Release. |

## Milestone 1 — Correctness & campaign completeness (done on this branch)

Found by reviewing the code and by running the new level validator:

- [x] **Level validator** (`tools/validate_levels.py`): parses the level arrays out of
      `GameWorld.swift` and checks enclosure, entity placement, reachability of the exit,
      objective, keys, enemies and items, door geometry, sealed rooms and key gating.
- [x] **Level data defects fixed**: 6 enemies/items sat inside wall or door tiles across the
      three levels, level 2 had a sealed room with a soldier in it (100% kills impossible),
      and the level 1 intel item sat in the start room instead of the command center.
- [x] **Key gating made real**: the red key in level 2 and both keys in level 3 could be
      bypassed entirely. Level 2's exit chamber is now sealed by three red doors; level 3
      enforces courtyard (red key) → vault → red door → mid-section (blue key) → blue door
      → lower levels and exit.
- [x] **Damage floors work**: damage was computed as `Int(5.0 * deltaTime)`, which is 0 at
      any normal frame rate. Nukage now ticks for 5 damage every 0.5 s and level 3 finally
      uses it (vault moat, lower-passage pool, arena strip, shells by the exit).
- [x] **Latent crash**: `Enemy.canSeePlayer` built a `1..<steps` range that traps when an
      enemy is within 0.25 tiles of the player.
- [x] **Mission objectives are data**: `LevelData.objective` (`MissionObjective`) replaces
      the `switch currentLevel` blocks in the engine; adding a level no longer touches
      engine code.
- [x] **Campaign flow**: dying restarts the current level instead of the whole campaign;
      finishing the last level shows a campaign summary (per-level kills/time, totals,
      rating) instead of silently looping to level 1.
- [x] **Enemy AI**: BFS distance field from the player (`Navigation.swift`) lets enemies
      hunt around corners and through doors when they lose sight of you; enemies open
      unlocked doors; doors no longer close on enemies; idle enemies wander; a per-type
      pain chance replaces the guaranteed flinch that let the chaingun stun-lock anything.
- [x] Interaction ray no longer stops at nukage tiles, so doors behind a puddle open.
- [x] **Pistol start**: the shotgun (and its shells) left the default loadout, so the shotgun
      pickup in every level matters and a death restart is a real pistol start. Weapons
      found still carry over between levels.

## Known issues & open questions

- Level ratings: "NIGHTMARE" is awarded for 100% kills slower than 2 minutes and
  "ULTRA-VIOLENCE" for faster. Intentional?
- README requirements said macOS 14 but the project's deployment target is macOS 15.7.

## Milestone 2 — Content

- [x] Level 4 finale ("E1M4: Anomaly Core"): the UAC base wrapped around a hell core, all
      three key colours in sequence (the yellow key finally gets used), an `exterminateAll`
      objective, its own difficulty tier and a galloping finale BGM track.
- [x] Fourth enemy type: the Baron of Hell boss in the E1M4 arena — 64×80 sprite sheet,
      claw and green plasma attacks, keeps closing in between throws, boss roar, HUD health
      bar, drawn 25% taller than regular enemies.
- [x] Rocket launcher: slot 5, 100 direct + 80 blast damage falling off over 1.8 tiles (never
      through walls, half strength on the player), explosion sprites and sounds, pickups in
      the E1M3 arena and the E1M4 armory, rocket boxes in E1M3 and E1M4.
- [x] Character select: three marines with their own status-bar portrait (hair, skin, eyes,
      headband, scar, stubble), starting weapon, armor and speed; chosen on a new screen
      between the title and the first briefing and remembered between launches.
- [x] Secret areas: sliding secret doors textured as the wall around them (tiles 11-13),
      two per level with a reward behind each, "A SECRET IS REVEALED!" with a chime, and a
      SECRETS x/y and ITEMS % tally on the level and campaign summaries.
- [x] Per-level par times (`LevelData.parTime`) used by the rating and shown next to the time.

## Milestone 3 — Meta & UX

- [x] Difficulty selection on the title screen (← →): four DOOM skills scaling enemy health,
      enemy projectile speed and damage taken, on top of the per-level ramp; remembered.
- [x] Persist best time / kill % per level and skill (UserDefaults, `RecordStore`) and show
      them on the level summary with a NEW RECORD flag.
- [x] Settings menu (S on the title, or from the pause menu): mouse sensitivity, master/SFX/
      music volume, minimap default; keyboard, mouse and controller driven.
- [x] Pause menu: RESUME / SETTINGS / QUIT TO TITLE, ↑↓ Enter, Esc resumes.
- [x] Game controller support (GCController): left stick move, right stick look, RT/A shoot,
      X/B use, LB/RB cycle weapons, L3/LT sprint, Menu pause, Options minimap; A/B/d-pad
      drive every menu screen.

## Milestone 4 — Engineering

- [x] Unit-test target (`fpsgame1Tests`, shared scheme `fpsgame1`) covering `GameEngine`,
      `GameWorld`, `Enemy`, `Navigation`, `Player`, `Weapon` and the shipped level data.
      Run with `xcodebuild test -scheme fpsgame1 -destination 'platform=macOS'` or ⌘U.
- [x] The validator's playability checks also run in the test target
      (`LevelValidationTests`: enclosed border, key-gated reachability of the exit,
      objective and every entity, every colour gates the exit, no sealed-off floor, doors
      set into walls, secret doors match their wall, nukage never the only route). The
      Python script stays for the quick Ubuntu job and its ASCII maps.
- [x] GitHub Actions workflow: level validator, unit tests (Debug) and a Release build on a
      macOS runner (`.github/workflows/ci.yml`).
- [x] Local post-merge verification (`tools/verify_local.sh`): sync to `origin/main` with
      backups, validate, build with the newest Xcode, launch or smoke-test.
- [x] Present through an `MTKView` instead of reading the GPU frame back into an `NSImage`,
      and composite sprites, the weapon overlay and the screen effects on the GPU
      (`spriteKernel`, `postKernel`); the unused Metal 4 scaffolding was removed.
- [x] iOS / iPadOS: the one app target builds for macOS, iOS and iPadOS (`SDKROOT = auto`,
      landscape only, iOS 18+). `GameView` and `KeyPressHandler` have UIKit twins (the
      MTKView host, a hardware-keyboard reader that maps HID usages to the mac key codes),
      the CPU fallback hands SwiftUI a `CGImage` on both platforms, and
      `TouchControls.swift` lays on-screen controls over the game: a floating stick on the
      left, drag-to-look and tap-to-fire on the right, FIRE / USE / RUN / weapon ◀ ▶ /
      MAP / PAUSE buttons that feed `InputManager` next to the keyboard, mouse and
      controller. Menus are tappable and word their hints for touch. CI builds the app
      for the iOS Simulator and runs the unit tests on it (`build-ios` job).
- [x] iOS follow-ups: every screen is laid out for the 960×600 window and shrinks to fit
      smaller hosts (`fitDesignSize()`: an iPhone in landscape, a Mac window below the
      design size), letterboxed on black like the game render; the HUD fits the same 16:10
      box the renderer draws into. The app icon (the imp over a red backdrop, every mac
      and iOS size) is pixel art generated by `tools/sprite_art/icon.py`.
- [x] Enemy rotation hysteresis: an enemy on a 45° sector boundary (or the player
      strafing across one) used to flip between two views every frame. The engine now
      settles each enemy's view once per tick (`Enemy.updateSpriteView`): the sector on
      screen stays until the facing is 6° past its edge, and both renderers draw that.
- [ ] iOS device play-test: the touch layout, look sensitivity and button sizes have only
      been checked by reasoning and the simulator build; tune them on a phone and an iPad.

## How to work on sprite art

1. Edit the module in `tools/sprite_art/`: enemies (`imp.py`, `demon.py`, `soldier.py`, `baron.py`),
   first-person weapons (`weapons.py`), pickups (`items.py`), hit effects (`effects.py`) or the portal
   design (`portal.py`).
   Standing frames are built on a `Rig`: parts are placed in a small 3D space (x lateral,
   y down, z toward the viewer) as limbs, blobs and custom closures, and the rig projects
   them for each turn angle (0/45/90/135/180°) and draws them far to near. `Canvas.part`
   cel-shades each part from a top-left light and drops a contact shadow onto whatever is
   underneath; `Canvas.outline` adds the 1px outline at the end. Views are drawn facing
   screen-left; the engine mirrors them for the other side. Death frames are front-only and
   hand-posed per enemy (`death_frames()` in each module): six frames from the killing hit to the
   corpse, timed by `EnemyType.deathFrameDurations`.
2. `python3 tools/sprite_art/build.py --preview` writes `build/sprite_art/<sheet>.png` sheets
   (front frames, each rotation, then the six death frames) to look at.
3. `python3 tools/sprite_art/build.py` regenerates `fpsgame1/BakedSpriteData.swift`. Commit both.
   `python3 tools/sprite_art/icon.py` regenerates the app icon PNGs in `Assets.xcassets`
   (the imp's front frame over a backdrop drawn in `icon.py`).
   Weapon frame counts must match `WeaponDefinition.animationFrames`; item order follows `Item.spriteIndex`.
   Sheet layout is fixed: front frames 0 idle, 1–3 walk, 4–5 attack, 6 hurt, 7–12 death (hit,
   two staggers/collapses, impact, corpse); then frames 0–6 again for each of the four other
   rotations (`Enemy.spriteFrame`).

## How to work on levels

1. Edit the level's layout / spawn lists in `fpsgame1/GameWorld.swift`.
2. Run `python3 tools/validate_levels.py --verbose` — it prints an ASCII map with entities
   and fails on anything that would make the level unwinnable.
3. Set the level's `objective:` and briefing text; `GameWorld.maxLevel` controls the
   campaign length.
4. Secrets: place a secret door (11 brick / 12 metal / 13 tech, matching the wall it sits
   in) and list the tile just inside it under `secrets:`; the validator checks both. Set
   `parTime:` to a time a good run should beat.
