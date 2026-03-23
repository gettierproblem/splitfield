# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
# Run natively
"/c/Users/Verit/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.6.1-stable_win64_console.exe" --path "C:/Users/Verit/barrack"

# Export for web
"/c/Users/Verit/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.6.1-stable_win64_console.exe" --headless --export-release "Web" "build/web/index.html" --path "C:/Users/Verit/barrack"

# Serve web build (requires Node.js)
node serve.js
# Opens at http://localhost:8080 with SharedArrayBuffer headers
```

No test framework is configured. Verify changes by building and running the game.

## Project Overview

Splitfield is a Godot 4.6 clone of Barrack, the 1996 Ambrosia Software game — a JezzBall/Qix-style arcade puzzle game. The player fires barrier beams across a field to fill space while bouncing balls try to destroy the beams. Fill 80%+ to advance.

## Architecture

**Autoload Singletons** (registered in project.godot):
- `GameManager` — game state, procedural level generation, kill/respawn tracking, ball/ammo carryover
- `ScoreManager` — FAQ-accurate scoring (level-scaled fill points, tiered over-achiever, level-bracket extra lives)
- `AudioManager` — SFX pool (12 players) + music player
- Accessed directly by autoload name in GDScript

**Grid System** (PlayingField): 200x184 cells, 4px each = 800x736 field. `CellState` enum: `Empty, Barrier, Filled, Growing`. Image-based rendering via `Image` + `Sprite2D` scaled 4x. BFS flood fill seeds from ball positions with 2-cell radius. Uses flat `PackedByteArray` grid with index-based BFS queue and dirty cell tracking for performance.

**Ball Movement** (BallBase): Sub-step collision using half-cell increments to prevent tunneling. Balls are `CharacterBody2D` subclasses that check grid cells directly — no physics bodies for barriers. 6 ball types inherit from `BallBase` (Pawn, Nuke, Orange, Ooze, Glass, Eyeball). Nuke balls bounce with gravity and detonate when trapped in small areas.

**Bosco the Shark** (Scripts/Bosco/): Separate entity from the ball system (Node2D, not BallBase). Managed by `BoscoManager` which handles spawn timing and host ball takeover. Primarily patrols the field perimeter but periodically dives through the interior. States: Patrolling, Diving, Gotcha, BallHit, Rampage (2x speed), Tired (half speed), Killed. Spawns at level 10+ by taking over a random ball. Only dies when caught in newly enclosed barrier area. Scoring: 800 (isolation), 2500 (glass shatter), 5000 (nuke), 10x during rampage.

**Loadout System** (CursorShip + GameScene): W/scroll-up loads a laser cartridge (consumes ammo, fires 4x speed beam). D/scroll-down loads a cluster magnet (places two wall magnets that attract balls for 5s). Middle click unloads. Tab toggles H/V orientation. Ammo persists between levels.

**Procedural Level System** (GameManager, see levels.md): No fixed level definitions. Kill/respawn tracking, wildcard slot allocation by difficulty tier, weighted random ball type resolution gated by level number. Surviving balls carry over between levels. Infinite progression.

**Signal-Based Communication**: PlayingField emits `FillPercentChanged`, `BarrierCompleted`, `BeamDestroyed`. ScoreManager emits `ScoreChanged`, `LivesChanged`, `MultiplierChanged`, `ExtraLifeEarned`. GameManager emits `LifeLost`. CursorShip emits `LoadLaserRequested`, `LoadMagnetRequested`, `UnloadRequested`, `OrientationChanged`.

**Scene Structure**: Two scenes — `Main.tscn` (menu with 5-page visual tutorial) and `GameScene.tscn` (gameplay). GameScene has PlayingField (with child containers for Balls, PowerUps, ActiveBeam) plus HUD, PauseMenu, GameOverScreen, LevelCompleteOverlay as CanvasLayers.

**Window**: 1024x768, stretch mode `canvas_items`. Playing field at offset (8,24), HUD panel at x:816-1024.

## Key Patterns

- Grid collision is O(1) cell lookups, not collision shapes
- PowerUps inherit from `PowerUpBase`, collected when enclosed by filled area
- PowerUps spawn every 5s, weighted random selection (Lightning most frequent, Score Multiplier second), only one active at a time (Score Multiplier doesn't block others; only one per level)
- Score Multiplier collected by barrier touch (not growing beam), applies to bonus at level end screen, resets to 1x
- Barrier charge persists between levels (stored on GameManager), lightning bolt adds 5%, life loss reduces 10%
- Ammo (laser cartridges + cluster magnets) persists between levels, +10 per pickup
- Completing a barrier awards rounded %contained x 10 as regular score
- Nuke balls bounce with gravity, detonate when region ≤800 cells, destroying all balls in same region
- Bosco only dies when caught in newly enclosed area (not existing filled areas)
- ClusterMagnet uses Bresenham line-of-sight + next-cell check to prevent pulling balls through barriers
- RollingDigitLabel extends Label for arcade-style counter animations on HUD numbers
- Psychedelic background is a GLSL shader (`psychedelic_bg.gdshader`), rendered on a separate Sprite2D at ZIndex -2
- Barrier merging: barriers surrounded by filled/barrier on all 8 neighbors render as fill gradient instead of cyan

## Reference Documents

- `plan.md` — full implementation plan and status
- `levels.md` — procedural level system spec (kill/respawn, wildcards, difficulty tiers, powerup weights)

## Implementation Status

Core gameplay is complete. Web export works. Audio has the manager but no sound files. Visual polish (particles, UI textures) and final tuning are still TODO. 5-page visual tutorial with rendered specimens is in the main menu. See `plan.md` for full status.
