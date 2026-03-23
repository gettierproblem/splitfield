# Splitfield — Godot 4.6 / GDScript Implementation Plan

## Original Game Reference

**Splitfield** (inspired by Barrack by Ambrosia Software, 1996) — a JezzBall/Qix-style arcade/puzzle game for Macintosh.

### Core Gameplay
- Player uses a cursor ship to fire barrier beams across the playing field
- Left click fires a horizontal beam; right click fires a vertical beam
- The beam grows outward from the click point in both directions simultaneously
- If a bouncing ball hits the beam before it reaches both walls, the beam is destroyed and you lose a life
- Successfully completed barriers divide the field, filling the enclosed area (if no balls are inside it)
- Goal: Fill at least 80% of the playing field to advance to the next level
- Overachiever bonus for filling beyond 80%
- Timed bonus counts down each level — if it reaches 0, game over

### Ball Types (8 types)
1. **Pawn balls** – Basic red enemy balls (speed: 200)
2. **Orange balls** – Absorb momentum from other balls (speed: 200)
3. **Nuke balls** – Bounce with gravity. Detonate when trapped in a small area (≤800 cells), destroying all balls in the same region. 500 pts per destroyed ball. Other balls bounce off normally. (speed: 160)
4. **Ooze balls** – Time bombs that split into Pawns (occasionally Nukes) if not trapped quickly (speed: 180)
5. **Glass balls** – Break/shatter after 3 hits (speed: 220)
6. **Sentry Eye (Eyeball)** – Actively hunts the barrier gun (speed: 180)
7. **Gravity balls** – Bouncing balls affected by gravity (speed: 200)
8. **Bosco** – Shark fin, separate from ball system, managed by BoscoManager. Primarily patrols perimeter but periodically dives through the field interior. Spawns at level 10+ by taking over a random ball. States: Patrolling, Diving, Gotcha, BallHit, Rampage (2x speed, 10x kill score), Tired (half speed). Only dies when caught in newly enclosed barrier area. Scoring: 800 (isolation), 2500 (glass shatter), 5000 (nuke detonation). Cigar ash trail as visual tell.

### Power-ups & Pickups
1. **Lightning Bolt** – Recharges barrier speed by 5%. Charge persists between levels, reduced by 10% on life loss.
2. **Ammo Tin** – Gives +10 laser cartridge charges
3. **Cluster Magnet Pickup** – Gives +10 cluster magnet charges
4. **Life Key** – Gives 1-5 extra lives
5. **Explosives** – Destroys random balls on pickup
6. **Score Multiplier** – Cycles through 0.5x/2x/3x/4x values. Collected value applies as bonus multiplier at level end screen, then resets. Only one spawns per level.
7. **Super Quick Laser** – 3x beam speed for 15 seconds

Power-ups spawn every 5 seconds at random positions in empty field space, selected randomly with weighted probabilities (Lightning Bolt most frequent, Score Multiplier second). All power-ups are available from level 1. A new power-up will not spawn until the previous one is collected or expires (Score Multiplier does not block other spawns). Collected when enclosed by a filled area. Score Multiplier is also collected when a completed barrier touches it.

### Loadout System
- **Laser Cartridges**: Limited ammo. W or scroll up to load. Next barrier fires at 4x speed, then returns to normal.
- **Cluster Magnets**: Limited ammo. D or scroll down to load. Click places two magnets on opposite walls along aim axis. Magnets attract all balls (line-of-sight) for 5s, pull strength 1600. Placed at nearest barrier/edge, never behind barriers.
- **Middle click**: Unloads current loadout, returns ammo.

### Controls
- **Left click**: Fire horizontal (sticky)
- **Right click**: Fire vertical (sticky)
- **Tab**: Toggle orientation
- **W**: Load laser cartridge (charged fast shot, consumes ammo)
- **D**: Load cluster magnet (places wall magnets, consumes ammo)
- **Scroll up**: Load laser cartridge
- **Scroll down**: Load cluster magnet
- **Middle click**: Unload current loadout (returns ammo)
- **ESC**: Pause
- Cursor ship follows mouse, shows firing direction with nozzles and aiming lines
- Ship glows yellow when laser cartridge charged, shows magnet icon when magnet loaded
- Default cursor hidden over field, restored on pause/level complete/game over

### Visual & Audio Style
- Smooth animated psychedelic plasma backdrop (GLSL shader, no quantization)
- Right-side HUD panel with score, lives, level, fill %, timed bonus, controls
- Balls rendered with 3D gradient effect (shadow, specular highlight, dark outline)
- Filled areas use diagonal gradient (blue-purple to teal) with subtle crosshatch texture
- Internal barriers between filled areas merge into fill gradient (only boundary barriers visible)
- Opaque dialog panels with dark background, subtle border, rounded corners

---

## Project Structure

```
C:\Users\Verit\barrack\
├── project.godot                    # Godot project config
├── export_presets.cfg               # Web export preset (thread support enabled)
├── run.bat                          # Launch game
├── serve.js                         # Node.js server for web build (COOP/COEP headers)
├── serve_web.bat                    # Launch web server
├── export_web.bat                   # Build web export
├── Scenes/
│   ├── Main.tscn                    # Main menu with tutorial, high scores
│   └── Game/
│       └── GameScene.tscn           # Primary gameplay (all UI embedded)
│   (*.tscn.csharp / *.tscn.gdscript backups for version switching)
├── Scripts/                         # Each .cs has a matching .gd port
│   ├── Core/
│   │   ├── GameManager.cs/.gd       # Global state, procedural levels, ammo/charge carryover
│   │   ├── LevelData.cs/.gd         # Custom Resource for level config
│   │   ├── ScoreManager.cs/.gd      # Score, multiplier, lives, extra lives
│   │   └── AudioManager.cs/.gd      # SFX pool (12 players) + music player
│   ├── Field/
│   │   ├── PlayingField.cs/.gd      # Grid state (200x184), flood fill, rendering
│   │   ├── BarrierBeam.cs/.gd       # Growing barrier logic with speed multiplier
│   │   ├── ClusterMagnet.cs/.gd     # Wall magnet that attracts balls
│   │   └── CursorShip.cs/.gd        # Mouse-following ship with directional nozzles
│   ├── Balls/
│   │   ├── BallBase.cs/.gd          # Abstract base: sub-step movement, grid collision
│   │   ├── PawnBall.cs/.gd          # Basic bouncing ball
│   │   ├── NukeBall.cs/.gd          # Gravity bounce, area detonation
│   │   ├── OrangeBall.cs/.gd        # Momentum absorption
│   │   ├── OozeBall.cs/.gd          # Time bomb, splits into pawns
│   │   ├── GlassBall.cs/.gd         # Shatters after 3 hits
│   │   ├── Eyeball.cs/.gd           # Hunts cursor
│   │   ├── StandardBall.cs/.gd      # Standard ball
│   │   └── GravityBall.cs/.gd       # Gravity-affected ball
│   ├── Bosco/
│   │   ├── Bosco.cs/.gd             # Shark entity: perimeter patrol + field dives
│   │   └── BoscoManager.cs/.gd      # Spawn timing, host ball takeover
│   ├── PowerUps/
│   │   ├── PowerUpBase.cs/.gd       # Base class: bounce, lifetime, collection
│   │   ├── LightningBolt.cs/.gd     # +5% barrier charge
│   │   ├── ScoreMultiplier.cs/.gd   # Cycling bonus multiplier
│   │   ├── ClusterMagnetPickup.cs/.gd # +10 magnet charges
│   │   ├── AmmoTin.cs/.gd           # +10 laser charges
│   │   ├── LifeKey.cs/.gd           # +1-5 extra lives
│   │   ├── YummieCake.cs/.gd        # Detonates into child powerups
│   │   ├── Explosives.cs/.gd        # Destroys random balls
│   │   ├── SuperQuickLaser.cs/.gd   # 3x beam speed
│   │   └── Magnet.cs/.gd            # Magnet effect
│   └── UI/
│       ├── GameScene.cs/.gd         # Main game controller, powerup spawning
│       ├── MainMenu.cs/.gd          # Menu with 5-page visual tutorial
│       ├── HUD.cs/.gd               # Right-side panel: score, lives, fill, bonus
│       ├── PauseMenu.cs/.gd         # Resume, Restart, Quit to Menu
│       ├── LevelCompleteOverlay.cs/.gd # Bonus + multiplier display
│       ├── GameOverScreen.cs/.gd    # Play Again, Main Menu
│       ├── RollingDigitLabel.cs/.gd # Arcade-style counter animations
│       └── BoscoSpecimen.gd         # Static fin drawing for tutorial (GDScript only)
├── Assets/
│   └── Shaders/
│       └── psychedelic_bg.gdshader  # Smooth 5-layer plasma shader
├── build/
│   └── web/                         # Web export output (index.html, .wasm, .pck)
└── icon.svg
```

## Scene Hierarchy (GameScene)

```
GameScene (Node2D)  [GameScene.cs]
├── PlayingField (Node2D @ 8,24)  [PlayingField.cs]
│   ├── PsychedelicBG (Sprite2D, shader material, ZIndex -2)  — created in code
│   ├── FieldSprite (Sprite2D, ZIndex -1)                      — grid image, created in code
│   ├── ActiveBeam (Node2D)        [BarrierBeam.cs instances]
│   ├── Barriers (Node2D)
│   ├── FilledAreas (Node2D)
│   ├── Balls (Node2D)             — ball instances
│   ├── PowerUps (Node2D)
│   └── CursorShip (Node2D)        [CursorShip.cs] — created in code
├── HUD (CanvasLayer)              — right-side panel (x: 816-1024)
├── PauseMenu (CanvasLayer, hidden)
├── GameOverScreen (CanvasLayer, hidden, with DimOverlay)
└── LevelCompleteOverlay (CanvasLayer, hidden)
```

## Core Architecture Decisions

1. **Grid-based field** (200x184 cells, each 4x4 pixels = 800x736 field) — not polygon clipping. Makes flood fill trivial and collision O(1).
2. **`CharacterBody2D` for balls** with manual grid collision and sub-step movement (half-cell increments) to prevent tunneling at high speeds.
3. **No physics bodies for grid barriers** — grid cell lookups are far cheaper than thousands of collision shapes.
4. **BFS flood fill** (not recursive DFS) — avoids stack overflow on large grids. Seeds from ball positions with 2-cell radius for robustness.
5. **Autoload singletons** for GameManager, ScoreManager, AudioManager.
6. **Custom Resources** (`LevelData`) for level definitions — auto-generated for 30 levels.
7. **Signal-based communication** between systems to avoid tight coupling.
8. **Image-based field rendering** — 200x184 pixel Image scaled 4x via Sprite2D with nearest-neighbor filtering. Psychedelic BG is a separate Sprite2D with shader (no Control nodes to eat input).
9. **Balls detect Growing cells** during sub-step movement and destroy the beam directly, rather than relying on beam's `_Process` overlap check.

## Key Systems Detail

### Playing Field Grid

```csharp
public const int GridWidth = 200;
public const int GridHeight = 184;
public const int CellSize = 4;
// Field position: (8, 24), size: 800x736

public enum CellState : byte { Empty, Barrier, Filled, Growing }
private CellState[,] _grid;
public float FillPercentage => (float)_filledCells / _totalCells * 100f;
public int CompletedBeamCount;  // tracks barrier lines placed
public int IsolatedBallCount;   // balls alone in their own region
```

- Empty: unclaimed space where balls can move (transparent — shows psychedelic BG)
- Barrier: permanent wall segment (cyan, only visible if bordering empty space)
- Filled: conquered territory (diagonal gradient with crosshatch texture)
- Growing: part of the currently-growing beam (bright yellow)
- Internal barriers (all 8 neighbors are barrier/filled) render as filled gradient

### Barrier Beam Mechanic

1. Left/right click → determine grid cell under cursor
2. Left click = horizontal, right click = vertical (sticky toggle)
3. Two growth heads advance in opposite directions each frame
4. Each head marks cells as `Growing`, stops at `Barrier`/`Filled`/border
5. If any ball hits a `Growing` cell → beam node destroyed + freed, Growing cells reverted, lose life
6. Both heads stopped → convert `Growing` → `Barrier` → trigger flood fill
7. Base speed 90 cells/sec; Super Quick Laser multiplies by 3x
8. Cursor ship (Node2D) follows mouse with directional nozzles showing fire direction

### Ball Movement & Collision

```csharp
// Sub-step movement to prevent tunneling (half-cell per step)
float stepSize = CellSize * 0.5f;
int steps = Max(1, CeilToInt(totalDist / stepSize));

// Per step: check X then Y separately
// If next cell is Blocking (Barrier/Filled) → bounce
// If next cell is Growing → destroy beam, lose life, return
// Also check center cell for Growing
```

### Flood Fill (after barrier completion)

- Seeds BFS from every ball position with 2-cell radius (handles balls on barrier lines)
- BFS floods through Empty cells only
- All unreachable Empty cells become Filled

### Isolation Detection

```csharp
// BFS assigns each ball a region ID based on connected empty space
// Balls that are the sole ball in their region are "isolated"
// Each isolated ball = 500 bonus points at level end
```

### Ball Types

| Type | Speed | Key Behavior |
|------|-------|-------------|
| **Pawn** | 200 | Basic red enemy ball |
| **Orange** | 200 | Absorbs momentum from nearby balls |
| **Nuke** | 160 | Detonates when trapped in small area, destroys nearby balls |
| **Ooze** | 180 | Time bomb (15-25s fuse); splits into 2-3 Pawns (10% Nuke) if not trapped |
| **Glass** | 220 | Has durability (3 hits); shatters with sound |
| **Sentry Eye** | 180 | Actively hunts the barrier gun (steers toward cursor) |
| **Gravity** | 200 | Downward acceleration added to movement |
| **Bosco** | 140 | Shark fin; moves through everything (barriers, filled areas); only dies when isolated |

All ball types inherit from `BallBase` (abstract `CharacterBody2D`) which provides:
- Sub-step grid-based wall/barrier collision and reflection
- Growing beam collision detection (destroys beam on contact)
- 3D gradient visual rendering (shadow, specular highlight, dark outline)

### Power-ups

| Power-Up | Effect | Duration |
|----------|--------|----------|
| **Super Quick Laser** | 3x beam growth speed | 15s |
| **Magnet** | Attracts Pawn Balls toward cursor | 10s |
| **Explosives** | Destroys random balls on pickup | Instant |
| **Score Multiplier** | 2x score | 12s |

Power-ups spawn every 5 seconds at random positions in empty field space, selected randomly with weighted probabilities (Lightning Bolt most frequent, Score Multiplier second). All power-ups are available from level 1. A new power-up will not spawn until the previous one is collected or expires. Collected when enclosed by a filled area or hit by a growing beam.

### Scoring & Bonuses (per FAQ)

```
Regular Points:
- Fill score: percentageFilled * pointsPerPercent (10 at L1-4, 20 at L5-9, +10/5 levels)
- Barrier completion: %contained * 10 points
- Nuke detonation: 500 points per destroyed ball

Bonus Points (multiplied by Score Multiplier at level end):
- Time bonus: starts at 3000, +100 per level
- Over-achiever: 100/% over 80, 1000/% over 90, 2500/% over 95, 20000 for 100%
- Isolation: 100 per ball isolated
- Bosco kill: 800 (regular), 2500 (glass), 5000 (nuke)
- Bosco kill during rampage: 10x multiplier
- Score Multiplier powerup: applies collected value (0.5x/2x/3x/4x) to total bonus at level end, then resets

Extra lives by level bracket:
- L1-4: every 5000, L5-9: 6000, L10-14: 7000, L15-19: 8500
- L20-24: 10000, L25-29: 12500, L30+: 15000

Game over conditions:
- Timed bonus reaches 0 (instant game over)
- Lives reach 0 (game over, shows "Out of lives!")
```

### Timed Bonus

```csharp
TimedBonusStart = 3000 + (level - 1) * 100;  // Per FAQ
TimedBonusDecayPerSecond = 10 + (level - 1) * 1;
// HUD color: green → yellow → red as bonus decreases
// Reaching 0 = immediate game over
```

### Level Data (Custom Resource)

```csharp
[GlobalClass]
public partial class LevelData : Resource
{
    [Export] public int LevelNumber;
    [Export] public int StandardBallCount;    // 3 + level
    [Export] public int GravityBallCount;     // from level 3
    [Export] public int EyeballCount;         // from level 5
    [Export] public int NukeBallCount;        // from level 8
    [Export] public int OrangeBallCount;      // from level 6
    [Export] public int GlassBallCount;       // from level 4
    [Export] public int PawnBallCount;        // from level 7
    [Export] public bool HasBosco;            // level 10, 15, 20, 25, 30
    [Export] public bool HasShark;            // from level 15
    [Export] public float BallSpeedMultiplier = 1f;  // +5% per level
    [Export] public float RequiredFillPercent = 80f;
    [Export] public float PowerUpSpawnChance = 0.1f;
    [Export] public int TimedBonusStart = 4000;
    [Export] public int TimedBonusDecayPerSecond = 10;
}
```

## UI Screens

- **Main Menu**: New Game, High Scores (numbered list with Back button), Quit — psychedelic background shader (slower, dimmer)
- **HUD**: Right-side vertical panel (816-1024px) — "SPLITFIELD" title, Score, Lives, Level, Fill % (green), "Need 80%", Timed Bonus (color-coded), Multiplier (when active), Controls
- **Pause Menu**: Resume, Restart Level, Quit to Menu — on ESC key, ProcessMode.Always
- **Level Complete**: LEVEL N COMPLETE (gold), Bonus Achieved, Isolation x count, Overachiever % (purple, hidden if exactly 80%), Total Bonus (yellow), Total Score, Next Level button — opaque dark panel with StyleBoxFlat
- **Game Over**: GAME OVER (red), Final Score (gold), Level Reached, Lives Remaining, reason text ("Out of lives!" or "Time bonus expired!"), Play Again, Main Menu — dimmed overlay + opaque panel
- **High Scores**: Persisted to `user://highscores.json` — top 10, numbered list, parsed from JSON array

## Visual Details

- **Psychedelic background**: GLSL shader with 5-layer plasma, smooth color cycling, brightness modulation for depth, no quantization banding
- **Ball rendering**: Drop shadow, base color fill, 4-ring inner gradient, white specular highlight (two-layer), thick dark outline + outer shadow ring
- **Filled areas**: Diagonal gradient (deep blue-purple to dark teal), subtle sine-wave crosshatch pattern, 85% opacity
- **Barrier merging**: Barriers check all 8 neighbors — if none are Empty/Growing, render as filled gradient instead of cyan line
- **Cursor ship**: Diamond body, directional nozzles (cyan), dashed aiming lines, ProcessMode.Always, hides when game inactive
- **Screen shake**: Tween-based position oscillation on life loss

---

## Implementation Status

### Phase 1: Foundation — DONE
- [x] Godot 4.6 project with C# solution (Godot.NET.Sdk/4.6.1, .NET 8)
- [x] Configure project.godot: window 1024x768, stretch canvas_items
- [x] PlayingField.cs: 200x184 grid, CellState enum, coordinate conversion
- [x] Image-based field rendering with Sprite2D
- [x] GameScene.tscn with PlayingField, HUD, overlays

### Phase 2: Barrier Beam — DONE
- [x] BarrierBeam.cs: click to fire, grows both directions
- [x] Left click = horizontal, right click = vertical (sticky toggle)
- [x] Visual rendering via grid image (yellow Growing cells)
- [x] Barrier completion: Growing → Barrier → flood fill
- [x] Speed multiplier support for Super Quick Laser

### Phase 3: Balls + Collision — DONE
- [x] BallBase.cs with sub-step grid-based collision (half-cell increments)
- [x] All 9 ball types implemented with distinct behaviors
- [x] Ball-to-growing-beam collision: beam destroyed + freed, life lost
- [x] 3D gradient ball rendering with shadow and highlight
- [x] Multiple balls spawning from level data

### Phase 4: Flood Fill + Win Condition — DONE
- [x] BFS flood fill with ball-position seeding (2-cell radius)
- [x] Fill percentage tracking and HUD display
- [x] Level complete at >= 80%
- [x] Filled area gradient rendering with crosshatch texture
- [x] Internal barrier merging (8-neighbor check)
- [x] Isolation detection (balls alone in their region)

### Phase 5: Scoring + Lives + Timed Bonus — DONE
- [x] ScoreManager: FAQ-accurate scoring (fill points scale by level bracket)
- [x] Over-achiever bonus: tiered (100/% >80, 1000/% >90, 2500/% >95, 20000 for 100%)
- [x] Isolation bonus: 100 per isolated ball
- [x] Nuke kills: 500 per nuked ball
- [x] Extra life thresholds scale by level (5000-15000)
- [x] "+1 LIFE!" HUD indicator with fade animation
- [x] Timed bonus: 3000 + 100/level, countdown per level (game over at 0)
- [x] HUD: right-side panel with rolling digit displays (arcade-style counters)
- [x] Game over: reason-aware (lives vs time expired)
- [x] Level transition: scene reload with ball carryover
- [x] Level complete: bonus achieved, isolation, overachiever, total

### Phase 6: All Ball Types — DONE
- [x] PawnBall — basic red enemy ball
- [x] OrangeBall — momentum absorption
- [x] NukeBall — detonates when trapped, destroys nearby balls
- [x] OozeBall — time bomb, splits into Pawns/Nukes if not trapped
- [x] GlassBall — durability (3 hits) and shattering
- [x] Eyeball (Sentry Eye) — cursor-tracking, hunts barrier gun
- [x] GravityBall — downward acceleration
- [x] Bosco — shark fin, moves through everything, dies when isolated (800 pts)

### Phase 7: Power-Up & Loadout System — DONE
- [x] Power-up spawning framework (15-30s random interval)
- [x] Lightning Bolt (temporary barrier speed boost, 15s)
- [x] Ammo Tin (gives 2-5 laser cartridges)
- [x] Cluster Magnet Pickup (gives 1-3 cluster magnets)
- [x] Life Key (gives 1-5 extra lives)
- [x] Explosives (destroys random balls)
- [x] Score Multiplier (2x, 12s)
- [x] Super Quick Laser (3x beam speed, 15s)
- [x] Collection when area filled
- [x] Loadout system: W/scroll-up loads laser (charged fast shot), D/scroll-down loads magnet
- [x] Cluster magnets: wall-mounted, line-of-sight, 5s duration, 1600 pull strength
- [x] Middle click to unload, HUD loadout section (charge bar, ammo, magnets)

### Phase 8: UI + Menus — DONE
- [x] Main Menu with psychedelic BG, New Game, High Scores, Quit
- [x] High Scores: parsed JSON, numbered list, Back button
- [x] Pause menu (ESC) with Resume, Restart, Quit
- [x] Level Complete overlay with full bonus breakdown
- [x] Game Over screen with dim overlay, reason text, Play Again, Main Menu
- [x] Opaque dialog panels (StyleBoxFlat)
- [x] Cursor ship with directional nozzles (yellow glow when charged, magnet icon when loaded)
- [x] Rolling digit displays for score, lives, fill%, bonus
- [x] HUD loadout section: laser charge bar, ammo count, magnet count

### Phase 9: Audio — PARTIAL
- [x] AudioManager autoload singleton with SFX pool
- [ ] Audio bus setup (Master → Music, SFX, Voice)
- [ ] Actual SFX audio files
- [ ] Looping industrial music
- [ ] Voice-over clips

### Phase 10: Visual Polish — PARTIAL
- [x] Psychedelic background shader (smooth 5-layer plasma)
- [x] Ball 3D gradient rendering
- [x] Filled area gradient + crosshatch texture
- [x] Barrier merging in filled regions
- [x] Screen shake on life loss
- [x] Cursor ship with aiming lines
- [x] Bosco shark fin with water ripples
- [ ] Rusted metal UI theme textures
- [ ] Particle effects (shatter, explosion, flash, sweep)
- [ ] Barrier glow shader
- [ ] Level transition animations

### Phase 11: Procedural Level System — DONE
- [x] Kill/respawn tracking (aggressive clearing = more respawns)
- [x] Ball carryover between levels (survivors persist)
- [x] Wildcard slot allocation by difficulty tier (L1:2, L2-9:1, L10-19:2, L20-29:3, etc.)
- [x] Weighted random wildcard resolution (Bosco at L5/10/18, Ooze at L11+, etc.)
- [x] Difficulty tiers affect ball speed multiplier
- [x] Timed bonus scaling (3000+100/level start, 10+1/level decay)
- [x] Infinite level progression (no fixed cap)
- [ ] Play-testing and balance tuning

### Phase 12: Final Polish — TODO
- [ ] Windows export configuration
- [ ] Resolution handling and UI scaling
- [ ] Edge case handling (stuck balls, beam at edges)
- [ ] Performance profiling
- [ ] Bug fixing pass
- [ ] Build and test final Windows executable
