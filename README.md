# DOOM Swift

A retro DOOM-style first-person shooter built entirely with **SwiftUI** and **Metal** on macOS.

![macOS](https://img.shields.io/badge/platform-macOS-blue)
![Swift](https://img.shields.io/badge/Swift-6.0-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **Raycasting Engine** — Classic DOOM-style rendering with textured walls, floors, and ceilings
- **Metal Accelerated** — GPU-powered rendering for smooth performance
- **Multiple Weapons** — Fist, Pistol, Shotgun, and Chaingun with unique fire rates and spread patterns
- **Enemy AI** — Enemies that patrol, chase, and attack with line-of-sight detection
- **Multi-Level Campaign** — Progressive levels with mission briefings and increasing difficulty
- **Interactive Doors** — Regular and color-keyed doors (Red, Blue, Yellow) requiring key pickups
- **Item Pickups** — Health packs, armor, ammo, and weapon pickups scattered across levels
- **DOOM-Style HUD** — Health, armor, ammo display with an expressive face indicator
- **Damage Floors & Torches** — Environmental hazards and atmospheric lighting effects
- **Fog of War Minimap** — Tactical minimap that reveals explored areas
- **Level Ratings** — Performance-based ratings from "I'M TOO YOUNG TO DIE" to "ULTRA-VIOLENCE"

## Controls

| Key | Action |
|-----|--------|
| `W A S D` | Move |
| `Mouse / Trackpad` | Look around |
| `Space / Click` | Shoot |
| `E` | Open doors |
| `1 2 3 4` | Switch weapons |
| `Shift` | Sprint |
| `ESC` | Pause |

## Requirements

- macOS 14.0+
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
```
