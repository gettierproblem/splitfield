# Splitfield Level System

Splitfield does not use fixed level definitions. Levels are procedurally generated through three interacting systems: kill/respawn tracking, wildcard slot allocation, and weighted random type resolution. This means no two playthroughs are exactly alike after the first few levels.

## Ball Types

| ID | Type | Behavior |
|----|------|----------|
| 2 | Pawn | Basic red enemy ball |
| 3 | Nuke | Detonates when trapped in a small area, clearing it and destroying nearby balls |
| 4 | Orange | Absorbs momentum from other balls |
| 5 | Ooze | Time bomb that splits into Pawns if not trapped quickly |
| 6 | Glass | Shatters after 3 hits; if two damaged glass balls collide, both shatter and clear the area |
| 7 | Sentry Eye | Actively hunts your barrier gun |

Bosco the shark is NOT a ball type. He is a separate entity with his own spawning system (see Bosco section below).

## Level Record Format

Each level record is 12 bytes: six int16 fields describing a single ball to add:

| Field | Offset | Purpose | If -1 |
|-------|--------|---------|-------|
| 0 | +0 | Ball type (2-7) | Resolved by cascade |
| 1 | +2 | Velocity X | Random within range |
| 2 | +4 | Velocity Y | Random within range |
| 3 | +6 | Position X | Random 1-7 with random sign |
| 4 | +8 | Position Y | Random 1-7 with random sign |
| 5 | +10 | Timer/behavior | Special handling for Sentry |

Each record spawns exactly one ball. A value of -1 means "resolve randomly at spawn time." Surviving balls from previous levels always carry over.

## How Levels Are Built

### Step 1: Kill/Respawn

When you destroy balls during a level, the game tracks what types you killed. At the start of the next level, for each type you killed, the game spawns `random(0, kill_count)` balls of that type.

This creates an adaptive difficulty loop: aggressively clearing nukes means more nukes come back. Leaving dangerous balls alive means fewer replacements but a more crowded field.

Kill counter memory map:
- A5+0x86A0 = Pawn (type 2) kills
- A5+0x869E = Nuke (type 3) kills
- A5+0x869C = Orange (type 4) kills
- A5+0x869A = Sentry (type 7) kills
- A5+0x8698 = Ooze (type 5) kills
- A5+0x8696 = Glass (type 6) kills

### Step 2: Wildcard Slot Allocation

The game adds a number of "wildcard" level records (all six fields set to -1) based on a difficulty tier system:

| Level | Wildcard Slots | Notes |
|-------|---------------|-------|
| 1 | 2 | Tutorial-like opening |
| 2-9 | 1 | Slow ramp |
| 10 | Special | Nuke + Bosco introduction (hardcoded record: field 0 = 3 (Nuke), rest = -1) |
| 10-19 | 2 | Mid-game |
| 20-29 | 3 | Late-game |
| 30-39 | 4 | Endurance |
| 40+ | level/10 - 2 | Scales indefinitely |

### Step 3: Wildcard Resolution

Each record where field[0] == -1 is resolved to a concrete ball type using weighted random selection gated by the level number. The resolver checks conditions in priority order:

| Priority | Condition | Result | Probability |
|----------|-----------|--------|-------------|
| 1 | Level < 10, Level == 5 | Nuke (3) | Guaranteed (first appearance) |
| 1 | Level < 10, Level != 5 | Pawn (2) | Guaranteed |
| 2 | Random 1-in-3 | Ooze (5) | ~33%, gated by total balls > 2 and ooze kills < 7 |
| 3 | Level == 10 or 18 | Nuke (3) | Guaranteed |
| 4 | Level >= 20 and first slot | Sentry Eye (7) | Guaranteed on level 20; random after |
| 5 | Level >= 15 | Glass (6) | 1 in 10 chance |
| 6 | Level >= 20 | Sentry Eye (7) | Guaranteed on 20; 1 in 8 after |
| 7 | Level >= 16 | Orange (4) | 1 in 10 chance |
| 8 | Fallback | Pawn (2) | Always |

Note: Rule 2 (Ooze) has **no level gate** — Ooze balls can theoretically appear from level 1 onward if conditions are met (total active balls > 2 and ooze kill counter < 7).

Fields 1-5 (velocity, position, behavior) are resolved independently: if -1, they are randomized using `Random(range) + base` patterns. If not -1, they are used directly as physics parameters for the spawned ball.

## Ball Type Introduction Schedule

| Level | New Type Available |
|-------|--------------------|
| 1 | Pawn |
| 1+ | Ooze (random, ~33% per slot, no level gate) |
| 5 | Nuke (guaranteed, 1 per level) |
| 10 | Nuke (hardcoded boss record) + Bosco the shark |
| 15 | Glass (random, ~10% per slot) |
| 16 | Orange (random, ~10% per slot) |
| 18 | Nuke (guaranteed via cascade) + Bosco |
| 20 | Sentry Eye |

## Bosco the Shark

Bosco is a special entity, separate from the ball type system. He has his own sprites (PICTs 1102-1126), sounds (IDs 1500-1506), and behavior code.

### Bosco Spawning (68K at CODE+0x15AAE, 0x1595C, 0x159DC)

Bosco does not exist as a ball type. He is a separate parasitic system that **attaches to existing ball entities** in the entity table.

#### Initialization at Level Start (`0x159DC`)

Called unconditionally at every level start (from the level init function at `0x9880`):
1. Plays shark patrolling sound (ID 1500)
2. Gets `_TickCount` and computes a timer, stores at `A5+0xAF6A`
3. Sets `A5+0x68CC = -1` and `A5+0x68CE = -1` (Bosco inactive)

This runs on **every** level, not just level 10+. The level-gating happens in the tick handler.

#### Per-Tick Spawn Check (`0x15AAE`)

Each game tick, the Bosco tick handler runs:
1. Call `0x144C6` with param 700 — searches the entity table for a suitable host ball. Returns entity index in D3, or -1 if none found.
2. **If no host found** (D3 == -1): play patrol sound, reset timer using `_TickCount + sound_duration`, keep `A5+0x68CC = -1` (inactive). Bosco is "circling" but not yet visible.
3. **If host found**: Bosco attaches to the ball:
   - Read `A5+0x86C8` + 450 (`0x1C2`), store as timer at `A5+0xAF6A`
   - Index into entity table: `A5+0x8278 + D3*26` to get the host ball
   - Link Bosco data structure (`A5+0xAEE6`) to the host ball entity via `0x2B8C`
   - Call perimeter direction mapper (`0x13A18`) and rendering setup (`0x3118`)
   - Set `A5+0x68CC = 1` (Bosco active), `A5+0x68CE = -1`

#### Host Ball Takeover

When Bosco attaches to a ball entity, the ball's type field (entity+0x34) appears to be changed to **9**. The main ball collision handler (`0x6BDA`) checks for type 9 at `0x7986` and `0x7C44` — when encountered, it calls the shark update function (`0x15A12`) instead of normal ball processing. This effectively transforms the host ball into Bosco.

The Bosco data structure lives at `A5+0xAEE6` (separate from the entity table). State flags at `A5+0x68CC` (1=active, -1=inactive) and `A5+0x68CE` control his lifecycle. The spawn eligibility check at `0x1595C` compares entity+0x84 against `A5+0x86C8` — Bosco only spawns when this threshold condition is met.

#### Spawn Timing Summary

| Step | What Happens |
|------|-------------|
| Level start | `0x159DC` plays patrol sound, sets timer, resets Bosco to inactive |
| Each tick | `0x15AAE` searches for a host ball via `0x144C6` |
| No host found | Patrol sound replays, timer resets — Bosco lurks invisibly |
| Host found | Bosco attaches to ball, sets type to 9, becomes active |
| Ball collision loop | Type 9 check at `0x7986`/`0x7C4E` routes to shark handler `0x15A12` |

His sprite animation system (25 frames showing approach/attack sequences) and sound table (Patrolling, Gotcha, Ball Hit, Killed, Rampage, Tired) are stored separately from the ball entity system.

### Bosco Movement

Bosco's per-tick behavior runs through the shark update function at `CODE+0x15A12`, which is called both from the ball collision handler (for type 9 entities) and from the main game loop (via the Bosco data structure at `A5+0xAEE6`).

Once active, Bosco's movement is handled by the shark update function at `0x15A12`, which processes his position along the playfield perimeter. The perimeter direction mapper at `0x13A18` converts position to sprite facing direction.

#### Perimeter Direction Mapping (`0x13A18`)

Bosco's position maps to a facing direction via threshold ranges, selecting which sprite frame / fin orientation to display:

| Position Range | Direction (D3, D4) | Interpretation |
|---------------|-------------------|----------------|
| ≤ -1 (special) | (128, 128) | Default / spawning |
| 0–58 | (128, 0) | Top edge, facing right |
| 59–117 | (128, 32) | Top-right corner |
| 118–177 | (128, 64) | Right edge |
| 178–206 | (128, 128) | Bottom-right corner |
| 207–265 | (64, 128) | Bottom edge |
| 266–324 | (32, 128) | Bottom-left corner |
| ≥ 325 | (0, 128) | Left edge |

#### States

| Sound ID | State | Trigger |
|----------|-------|---------|
| 1500 | Patrolling | Normal edge movement |
| 1501 | Gotcha | Collision with player's barrier/shooter |
| 1502 | Ball Hit | Hit by a ball |
| 1503 | Killed | Destroyed |
| 1504 | Rampage | "I keel you!" — triggered at `0xAE0C` with call to `0x6820` param 6 |
| 1506 | Tired | Post-rampage cooldown |

#### Collision Behavior

- Touching Bosco's fin with your shooter costs a life
- Bosco's fin hitting your barrier before it completes costs a life
- When the collision handler encounters a type 9 entity (Bosco's host ball), it routes to the shark handler at `0x15A12` instead of normal ball collision processing
- Cigar ash trail follows him as a visual tell of his position

### Bosco Scoring

| Kill Method | Points | Notes |
|-------------|--------|-------|
| Regular isolation | 800 | Trap Bosco in area with no enemy balls |
| Glass shatter | 2,500 | Trap Bosco in area cleared by shattering glass |
| Nuke detonation | 5,000 | Detonate a nuke while Bosco swims through |
| During rampage | 10x | Multiplied by kill method (e.g., nuke + rampage = 50,000) |

## Difficulty Tiers

A separate difficulty tier affects ball behavior (likely speed and aggression):

| Level Range | Tier |
|-------------|------|
| 1 | 2 (special case) |
| 2-9 | 1 |
| 10-19 | 2 |
| 20-29 | 3 |
| 30-39 | 4 |
| 40+ | Computed from level number |

## Scoring Per Level Range

Points earned per percentage of screen cleared:

| Level Range | Points per % | Extra Life Every |
|-------------|-------------|-----------------|
| 1-4 | 10 | 5,000 pts |
| 5-9 | 20 | 6,000 pts |
| 10-14 | 30 | 7,000 pts |
| 15-19 | 40 | 8,500 pts |
| 20-24 | 50 | 10,000 pts |
| 25-29 | 60 | 12,500 pts |
| 30+ | 70+ | 15,000 pts |

### Over-Achiever Bonus (above 80% clearance)

| Clearance | Bonus |
|-----------|-------|
| Each % over 80% | 100 pts |
| Each % over 90% | 1,000 pts |
| Each % over 95% | 2,500 pts |
| 100% perfect | 20,000 pts |

### Other Bonuses

- Barrier completion: rounded %contained × 10 pts (regular score)
- Nuke detonation: 500 pts per destroyed ball
- Ball isolation: 100 pts per ball
- Time bonus: starts at 3,000, +100 per level
- Bosco kill: 800 pts (regular), 2,500 pts (glass), 5,000 pts (nuke)
- Bosco kill during rampage: 10x multiplier
- Score Multiplier powerup: collected value (0.5x/2x/3x/4x) applies to total bonus at level end, then resets to 1x. Only one spawns per level.

### Power-Up Spawning

Power-ups spawn every 5 seconds, selected randomly with weighted probabilities. All types available from level 1:

| Power-Up | Weight | Effect |
|----------|--------|--------|
| Lightning Bolt | 40 | +5% barrier charge (persists between levels; -10% on life loss) |
| Score Multiplier | 20 | Cycles 0.5x/2x/3x/4x; applied to bonus at level end. One per level. Does not block other spawns. |
| Cluster Magnet Pickup | 8 | +10 cluster magnet charges |
| Ammo Tin | 8 | +10 laser cartridge charges |
| Yummie Cake | 6 | Detonates on barrier hit, spawns child yummies |
| Life Key | 5 | +1-5 extra lives |

A new power-up will not spawn until the previous one is collected or expires (Score Multiplier excluded from this check). Score Multiplier is collected when a completed barrier touches it (not by growing beam). Ammo (laser + magnets) persists between levels.

## Visual Themes

10 foreground/background pattern pairs cycle every 10 levels. Each pair uses a distinct 256-color palette stored as `ppat` and `clut` resources in the original Barrack Titles file.

## Implementation Details

- Level table base address: A5+0x68E8
- Level record counter: A5+0x68E2
- Level play index: A5+0x68E0
- **Level number: A5+0x811E** (low word of 32-bit value at A5+0x811C)
  - Initialized to 1 via `MOVEQ #1, D0; MOVE.L D0, (A5+0x811C)` at 68K offset 0x10776
  - Cleared via `CLR.L (A5+0x811C)` at 68K offset 0x9648 (game reset, separate function from level start)
  - No direct increment in 68K CODE — managed through PPC counter widget system
  - PPC equivalent: offset 128 within counter object at RTOC-388 (read at PPC offset 0xCC10)
  - Used as parameter to level builder (pushed at 0x98F4, received as D3 in 0x833E)
  - Used as D5 in wildcard resolver cascade (0x8018-0x810E)
- Store function (68K): CODE offset 0x8308
- Level builder (68K): CODE offset 0x833E
- Wildcard resolver (68K): CODE offset 0x7F9C (setup at 0x7FA0)
- Kill/respawn recorder (68K): CODE offset 0x89A0
- Record size: 12 bytes (6 x int16, big-endian)
- Sentinel value: -1 (0xFFFF) = resolve at spawn time
- Level 10 boss record: written directly to level table using indexed addressing `(d8, A0, D3.L)` at 68K offsets 0x8400-0x841E

### Level Record Field Resolution (68K 0x8116-0x82FE)

After the cascade resolves field[0] to a ball type:
1. Entity creation (0x8118): creates ball object, stores pointer in A2
2. Type dispatch (0x8132): jump table selects sprite/behavior data by type
3. Entity setup (0x8168-0x81EE): initializes physics, animation, and rendering
4. Field[1] velocity X (0x81F0): if -1, `Random(max-min) + min`
5. Field[2] velocity Y (0x8212): same pattern
6. Fields[3-4] position (0x8242): if -1, `Random(6)+1` with random sign; stored to entity offsets 0x30/0x32
7. Sentry special (0x82BA): if type == 7, computes pursuit timer from Random(2500) + kill_counter + 1000
8. Finalization (0x82EC-0x82FE): clears entity flags, registers entity

### PPC Counter Widget System

The game uses a reusable UI counter framework for on-screen numeric displays (score, lives, level, etc.). Each counter is a ~140-byte object with value at offset 128, display target at offset 132, visibility flag at offset 136, and digit format at offset 124.

Three operations:
- **SET** (0x06684): `counter[128] = val; counter[132] = val; render_digits()`
- **SUB** (0x066AC): `counter[128] = max(0, counter[128] - val); render_digits()`
- **ADD** (0x066EC): `counter[128] += val; render_digits()` (with null guard)

Display update functions (0x06720, 0x06864) convert the integer to digit sprites using magic-number division (multiply-by-reciprocal pattern) and render them on screen.

Counter instances: r2-532 (score), **r2-388 (level)**, r2-244 (unknown), r2-100 (time bonus), r2+44 (lives), r2+188 (ammo/charges).

The level counter (r2-388) is only SET, never ADD'd — it is written to the correct level number at each level start, not incrementally bumped.
