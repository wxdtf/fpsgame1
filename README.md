# DOOM Swift

A retro DOOM-style first-person shooter built entirely with **SwiftUI** and **Metal** on macOS.

[![CI](https://github.com/wxdtf/fpsgame1/actions/workflows/ci.yml/badge.svg)](https://github.com/wxdtf/fpsgame1/actions/workflows/ci.yml)
![macOS](https://img.shields.io/badge/platform-macOS-blue)
![Swift](https://img.shields.io/badge/Swift-6.0-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **Raycasting Engine** — Classic DOOM-style rendering with textured walls, floors, and ceilings
- **Metal Accelerated** — GPU-powered rendering for smooth performance
- **Multiple Weapons** — Fist, Pistol, Shotgun, Chaingun, and a Rocket Launcher with splash damage
- **Enemy AI** — Enemies wander, chase and attack with line-of-sight detection, hunt you through corridors and open doors using a tile navigation field, and flinch by pain chance
- **Multi-Level Campaign** — Progressive levels with mission briefings, data-driven objectives, increasing difficulty and an end-of-campaign summary
- **Interactive Doors** — Regular and color-keyed doors (Red, Blue, Yellow) requiring key pickups
- **Item Pickups** — Health packs, armor, ammo, and weapon pickups scattered across levels
- **DOOM-Style HUD** — Health, armor, ammo display with an expressive face indicator
- **Nukage & Torches** — Toxic floors that deal periodic damage and flickering torch lighting
- **Fog of War Minimap** — Tactical minimap that reveals explored areas
- **Level Ratings** — Performance-based ratings from "I'M TOO YOUNG TO DIE" to "ULTRA-VIOLENCE"

## Controls

| Key | Action |
|-----|--------|
| `W A S D` | Move |
| `Mouse / Trackpad` | Look around |
| `Space / Click` | Shoot |
| `E` | Open doors |
| `1 2 3 4 5` | Switch weapons |
| `Shift` | Sprint |
| `Tab` | Toggle minimap |
| `ESC` | Pause |

## Requirements

- macOS 15.7+ (the project's deployment target)
- Xcode 16.0+

## Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/wxdtf/fpsgame1.git
   ```
2. Open `fpsgame1.xcodeproj` in Xcode
3. Build and Run (`⌘R`)

## Tech Stack

- **SwiftUI** — UI framework and game state management
- **Metal** — GPU-accelerated raycasting shader
- **AppKit** — Low-level input capture for keyboard and mouse

## Architecture

```
fpsgame1/
├── fpsgame1App.swift      # App entry point
├── ContentView.swift      # Main view with game state routing
├── GameEngine.swift       # Core game loop and raycasting
├── GameViewModel.swift    # Game state management
├── GameWorld.swift        # Level data, maps, and door logic
├── Renderer.swift         # Software raycaster
├── MetalRenderer.swift    # Metal GPU rendering pipeline
├── Raycaster.metal        # Metal shader for raycasting
├── Player.swift           # Player state and movement
├── Enemy.swift            # Enemy AI and behavior
├── Navigation.swift       # BFS distance field used by enemies to hunt the player
├── Weapon.swift           # Weapon definitions and state
├── Sprites.swift          # Sprite rendering (enemies, items, weapons)
├── Textures.swift         # Procedural texture generation
├── HUD.swift              # Heads-up display overlay
├── DoomFace.swift         # Expressive face indicator
├── AudioManager.swift     # Sound effects system
├── InputManager.swift     # Keyboard and mouse input
├── MenuViews.swift        # Title, death, victory, briefing screens
├── Item.swift             # Pickup item definitions
├── PixelBuffer.swift      # Pixel buffer for software rendering
├── Constants.swift        # Game configuration values
└── GameView.swift         # Game rendering view
tools/
└── validate_levels.py     # Static checker for level data (reachability, keys, placement)
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

### Continuous integration

`.github/workflows/ci.yml` runs on every push to `main` and on every pull request:

- **Validate level data** (Ubuntu): runs `tools/validate_levels.py`.
- **Build macOS app** (macOS runner): selects the newest installed Xcode (the Metal 4
  code path needs the macOS 26 SDK) and builds the `fpsgame1` target unsigned.

### Roadmap

See [ROADMAP.md](ROADMAP.md) for the current status, known issues and planned milestones.
