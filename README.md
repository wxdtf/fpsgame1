# DOOM Swift

A retro DOOM-style first-person shooter built entirely with **SwiftUI** and **Metal** for macOS, with the same code running on iOS / iPadOS (on-screen controls, controllers and hardware keyboards).

[![CI](https://github.com/wxdtf/fpsgame1/actions/workflows/ci.yml/badge.svg)](https://github.com/wxdtf/fpsgame1/actions/workflows/ci.yml)
![Platforms](https://img.shields.io/badge/platform-macOS%20%7C%20iOS%20%7C%20iPadOS-blue)
![Swift](https://img.shields.io/badge/Swift-6.0-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **Raycasting Engine** — Classic DOOM-style rendering with textured walls, floors, and ceilings
- **Metal Accelerated** — GPU-powered rendering for smooth performance
- **Three Playable Marines** — Sarge, Viper and Grimm, each with their own portrait, armor, speed and starting weapon
- **Multiple Weapons** — Fist, Pistol, Shotgun, Chaingun, and a Rocket Launcher with splash damage
- **Enemy AI** — Enemies wander, chase and attack with line-of-sight detection, are drawn from five rotations depending on where they face, hunt you through corridors and open doors using a tile navigation field, and flinch by pain chance
- **Multi-Level Campaign** — Progressive levels with mission briefings, data-driven objectives, increasing difficulty and an end-of-campaign summary
- **Interactive Doors** — Regular and color-keyed doors (Red, Blue, Yellow) requiring key pickups
- **Item Pickups** — Health packs, armor, ammo, and weapon pickups scattered across levels
- **DOOM-Style HUD** — Health, armor, ammo display with an expressive face indicator
- **Nukage & Torches** — Toxic floors that deal periodic damage and flickering torch lighting
- **Fog of War Minimap** — Tactical minimap that reveals explored areas
- **Secrets & Ratings** — Sliding secret doors hidden in the walls with rewards behind them, an items/secrets tally on every summary, and performance ratings against per-level par times

## Controls

| Keyboard / mouse | Controller | Touch (iOS / iPadOS) | Action |
|-----|-----|-----|--------|
| `W A S D` | Left stick | Drag on the left half (floating stick) | Move |
| `Mouse / Trackpad` | Right stick | Drag on the right half | Look around |
| `Space / Click` | `RT` / `A` | `FIRE` (hold) or tap the right half | Shoot |
| `E` | `X` / `B` | `USE` | Open doors |
| `1 2 3 4 5` | `LB` / `RB` | `◀` `▶` | Switch weapons |
| `Shift` | `L3` / `LT` | `RUN` (toggle) | Sprint |
| `Tab` | Options | `MAP` | Toggle minimap |
| `ESC` | Menu | `II` | Pause menu (resume, settings, quit to title) |

On the title screen `← →` pick the skill level (four DOOM difficulties, remembered between
launches) and `S` opens the settings: mouse sensitivity, master / effects / music volume and
whether the minimap starts visible. Menus take the keyboard, the mouse or a controller
(`A` confirm, `B` back, d-pad or left stick to move). The level summary shows your best time
and kill percentage for that level and skill.

## Requirements

- macOS 15.7+ or iOS / iPadOS 18+ (the project's deployment targets)
- Xcode 26 (the project uses synchronized groups)

## Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/wxdtf/fpsgame1.git
   ```
2. Open `fpsgame1.xcodeproj` in Xcode
3. Pick **My Mac** or an iPhone / iPad (simulator or device) as the run destination
4. Build and Run (`⌘R`), or run the unit tests (`⌘U`)

The one `fpsgame1` target builds for macOS, iOS and iPadOS; iOS runs landscape only. On a
touch screen the game shows on-screen controls (see the table above); a paired controller
or a hardware keyboard works exactly like on the Mac.

## Tech Stack

- **SwiftUI** — UI framework and game state management
- **Metal** — GPU-accelerated raycasting shader
- **AppKit / UIKit** — Low-level input capture: keyboard and mouse on the Mac, hardware keyboards on iPad; touch controls are SwiftUI

## Architecture

```
fpsgame1/
├── fpsgame1App.swift      # App entry point
├── ContentView.swift      # Main view with game state routing
├── GameEngine.swift       # Core game loop and raycasting
├── GameViewModel.swift    # Game state management
├── GameWorld.swift        # Level data, maps, and door logic
├── Renderer.swift         # Software raycaster
├── MetalRenderer.swift    # Metal GPU pipeline: four compute passes into an MTKView
├── Raycaster.metal        # Compute kernels: floor/ceiling, walls, sprites, post effects
├── SpriteAtlas.swift      # Every sprite frame packed into one GPU buffer
├── PostEffects.swift      # Screen tints, damage/death effects, hit marker, fades
├── Player.swift           # Player state and movement
├── Character.swift        # Playable marines: portraits, loadouts, stats
├── Enemy.swift            # Enemy AI and behavior
├── Navigation.swift       # BFS distance field used by enemies to hunt the player
├── Weapon.swift           # Weapon definitions and state
├── Sprites.swift          # Sprite sheets: baked pixel art + procedural projectiles/explosions
├── BakedSpriteData.swift  # Baked enemy, weapon, item and effect pixel art (generated by tools/sprite_art)
├── Textures.swift         # Procedural texture generation
├── HUD.swift              # Heads-up display overlay
├── DoomFace.swift         # Expressive face indicator
├── AudioManager.swift     # Sound effects system
├── Settings.swift         # Difficulty, options menu persistence, per-level records
├── SettingsViews.swift    # Settings screen and pause menu
├── InputManager.swift     # Keyboard, mouse, game controller and touch input
├── TouchControls.swift    # On-screen controls for iOS / iPadOS
├── MenuViews.swift        # Title (skill select), death, victory, briefing screens
├── Item.swift             # Pickup item definitions
├── PixelBuffer.swift      # Pixel buffer for software rendering
├── Constants.swift        # Game configuration values
└── GameView.swift         # Game rendering view (AppKit and UIKit hosts)
tools/
├── validate_levels.py     # Static checker for level data (reachability, keys, placement)
└── verify_local.sh        # Post-merge verification on a Mac: sync, validate, build, launch
```

## Development

### Validating levels

Levels are hand-typed tile arrays in `GameWorld.swift`, so a misplaced number can put an
enemy inside a wall or seal off the exit. Run the validator after every level edit:

```bash
python3 tools/validate_levels.py --verbose
```

It prints an ASCII map per level and fails (non-zero exit) if the exit, the objective, a
key card or any enemy/item is unreachable from the start, honouring locked doors.

### Post-merge verification on your Mac

CI only compiles. To play-test what was just merged, run the verification script. From
inside a clone:

```bash
tools/verify_local.sh
```

Without a clone yet, or from a folder that only contains one (Xcode keeps the repository
inside the project folder it creates, so `--dir` may point at the folder above it):

```bash
curl -fsSL https://raw.githubusercontent.com/wxdtf/fpsgame1/main/tools/verify_local.sh \
    | bash -s -- --dir ~/wxdtf/FPS
```

The script finds or creates the clone: `--dir` may be an existing clone, a folder that
contains one, an empty or missing folder (it is cloned), or a non-git copy of the project
(moved to `<dir>.backup-<timestamp>` first). Any other folder is left alone. It then makes
the clone identical to `origin/main` (uncommitted changes go into a stash and unpushed
commits onto a `backup/local-<timestamp>` branch), validates the levels, builds with the
newest installed Xcode (a newer Xcode-beta wins), and opens the app with a play-test
checklist. Since Xcode 26 the Metal compiler is a separate download, so an Xcode that
already has it is preferred over a newer one without; if none has it, the script downloads
it (the same as Xcode > Settings > Components > Metal Toolchain). `--no-launch` runs an 8-second start-up smoke test instead of opening the app,
`--no-sync` keeps your working tree, `XCODE_APP=/Applications/Xcode-beta.app` forces a
specific Xcode, and `REPO_URL=git@github.com:wxdtf/fpsgame1.git` clones over SSH.

### Continuous integration

`.github/workflows/ci.yml` runs on every push to `main` and on every pull request:

- **Validate level data** (Ubuntu): runs `tools/validate_levels.py`.
- **Build and test macOS app** (macOS runner): selects the newest installed Xcode, runs
  the `fpsgame1Tests` unit tests in Debug and then builds a Release configuration, all
  unsigned.

### Roadmap

See [ROADMAP.md](ROADMAP.md) for the current status, known issues and planned milestones.
