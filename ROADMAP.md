# DOOM Swift — Development Status & Roadmap

This document tracks where the project stands and what comes next. It is the
place to look before starting new work; update it when a milestone lands.

## Status snapshot

| Area | State |
|------|-------|
| Rendering | Complete. Metal 3 compute raycaster (walls, floor, ceiling, fog, torch light, sliding doors, animated exit portal) with a multi-core CPU fallback. Sprites, projectiles and the weapon overlay are composited on the CPU with z-buffer occlusion. |
| Player | Movement with wall sliding and unstick, sprint, view bob, armor absorption, berserk, keys, 4 weapons (fist, pistol, shotgun, chaingun) with switch/fire animations. |
| Enemies | 3 types (imp, soldier, demon). State machine: idle → patrol → chase → attack → hurt → dying → dead. Line-of-sight detection, projectile and melee attacks, tile-based pathfinding when out of sight, door opening, pain chance, wandering patrols. |
| World | 32×32 tile maps, 11 tile types, regular + colour-locked doors with auto-close, damage floors (nukage), exit portal, per-level difficulty scaling. |
| Campaign | 3 levels with briefings, data-driven mission objectives (item retrieval / extermination), level summary with rating, campaign summary, death restarts the current level. |
| UI / feedback | Title, briefing (typewriter), pause, death, level and campaign summary screens. HUD with 42-frame DOOM face, fog-of-war minimap (TAB), objective tracker, status messages, directional damage flash, hit marker, screen shake, muzzle flash, death camera. |
| Audio | Fully procedural: 14 sound effects and one looping BGM track per level, generated at runtime with AVAudioEngine. |
| Assets | None on disk. Every texture, sprite, face frame and sound is generated procedurally in Swift. |
| Tooling | `tools/validate_levels.py` statically checks every level (reachability, key gating, entity placement). No unit tests, no CI yet. |

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

## Known issues & open questions

- The player starts every level with a shotgun (`Player.weapons` default), which makes the
  shotgun pickups redundant. Probably a leftover from testing; decide whether to keep it.
- Level ratings: "NIGHTMARE" is awarded for 100% kills slower than 2 minutes and
  "ULTRA-VIOLENCE" for faster. Intentional?
- `MetalRenderer` has a Metal 4 path that is disabled until the shaders are ported to
  argument tables; the Metal 3 path is what ships.
- README requirements said macOS 14 but the project's deployment target is macOS 15.7.
- No automated build: the level validator runs in CI-less isolation. A GitHub Actions
  macOS job running `xcodebuild` and the validator would catch regressions.

## Milestone 2 — Content

- [ ] Level 4 finale ("E1M4") with an `exterminateAll` objective and its own BGM track.
- [ ] Fourth enemy type (e.g. a heavy boss for the finale) — sprite sheet generator, AI
      parameters, sounds.
- [ ] A projectile weapon for the player (rocket launcher or plasma) with splash damage.
- [ ] Secret areas and an items-collected percentage on the summary screens.
- [ ] Per-level par times used by the rating instead of a flat 2 minutes.

## Milestone 3 — Meta & UX

- [ ] Difficulty selection on the title screen (feeds the existing multipliers).
- [ ] Persist best time / kill % per level (UserDefaults) and show them on the summary.
- [ ] Settings: mouse sensitivity, master/SFX/music volume, minimap default.
- [ ] Pause menu with "quit to title"; keyboard navigation helper for menus.
- [ ] Game controller support (GCController).

## Milestone 4 — Engineering

- [ ] Unit-test target covering the Foundation-only engine files (`GameEngine`, `GameWorld`,
      `Enemy`, `Navigation`, `Player`, `Weapon`); the validator's reachability checks can
      move into it.
- [ ] GitHub Actions workflow: build on a macOS runner and run the level validator.
- [ ] Finish the Metal 4 path (argument tables) and move sprite compositing to the GPU.
- [ ] Explore an iOS/iPadOS target (touch input, `UIImage` frame path).

## How to work on levels

1. Edit the level's layout / spawn lists in `fpsgame1/GameWorld.swift`.
2. Run `python3 tools/validate_levels.py --verbose` — it prints an ASCII map with entities
   and fails on anything that would make the level unwinnable.
3. Set the level's `objective:` and briefing text; `GameWorld.maxLevel` controls the
   campaign length.
