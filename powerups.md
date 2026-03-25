# Barrack Powerup System

Powerups in Barrack are called "yummies." They appear on the playing field during gameplay and can be collected by hitting them with a barrier or enclosing them in a cleared area.

## Yummy Types

| Type ID | Name | Effect |
|---------|------|--------|
| 2 | Lightning Bolt | Recharges barrier speed to 80 (max) |
| 3 | Cluster Magnets | Grants magnet ammo (+100 charges) |
| 4 | Laser Cartridges | Grants laser ammo (+100 charges, 200-increment steps) |
| 5 | Key (Extra Lives) | Grants 1-5 extra lives instantly |
| 6 | Score Multiplier | 2x score multiplier on bonus points |
| 7 | Yummie Cake | Explodes into 4-7 child yummies |

**Type IDs 2-7 are shared between balls and yummies.** The same entity allocation function (CreateEntity at 0x7808) and the same type cascade (0x8018-0x8114) are used for both. A type 2 entity can be either a Pawn ball or a Lightning Bolt yummy — the distinction is made by subsequent setup code, not the type ID itself. See the "Shared Entity System" section below for details.

## On-Screen Behavior

Most yummies bounce around the playing field after spawning, bouncing off barriers and the edges of cleared areas like balls do. The per-entity tick callback at 0x74EE routes yummies to `yummy_tick` (0x2884), which is a sprite animation updater with **no despawn timer**. Regular bouncing yummies (Lightning Bolt, Magnets, Laser, Key, Cake) persist on the field indefinitely until collected.

The **Score Multiplier** is the exception — it has its own dedicated spawn/despawn system with a limited on-screen lifetime (~7-19 seconds). See the Score Multiplier section below for details.

The **Yummie Cake** also behaves differently — it drops onto the field and detonates on impact, immediately spawning 4-7 child yummies. If it lands in an already-cleared area, it sinks and is wasted.

## How to Collect Yummies

- **Barrier hit**: fire a barrier that intercepts a bouncing yummy mid-flight
- **Capture**: enclose the yummy inside a newly cleared area (works for both bouncing yummies and the stationary multiplier)
- **Cake warning**: if a Yummie Cake lands in already-cleared area, it sinks and is lost

## Spawn Systems

Yummies come from three independent systems.

### 1. Main Entity Spawner (shared with balls)

The primary spawn system (68K @ 0x7F9C) processes records from the level table at A5+0x68E8. This is the **same function** documented in levels.md as the ball wildcard resolver — it creates ALL game entities (both balls and yummies) through a single pipeline. There is no conditional branch splitting ball vs yummy creation; every entity goes through the same allocation, type cascade, sprite loading, and registration steps.

When a record has type == -1 (wildcard), the cascade at 0x8018-0x8114 resolves it to a concrete type based on level number and random rolls. The cascade determines the mix of entity types available at each level — this applies to both balls and yummies equally.

#### Type Cascade (0x8018-0x8114)

Each wildcard record is resolved by checking conditions in priority order. The first match wins.

| Priority | Condition | Type | Probability | Notes |
|----------|-----------|------|-------------|-------|
| 1a | Level < 10, Level == 5 | 3 (Nuke/Magnets) | 100% | First appearance |
| 1b | Level < 10, Level != 5 | 2 (Pawn/Lightning) | 100% | Only basic type |
| 2 | Random(3)==0, total entities > 2, type5 counter < 7 | 5 (Ooze/Key) | ~33% | No level gate |
| 3a | Level == 10 or 18 | 3 (Nuke/Magnets) | 100% | Guaranteed |
| 3b | Level > 20, Random(4)==0, + counter thresholds | 3 (Nuke/Magnets) | ~25% | Complex gating on type3 counter vs total entities |
| 4 | Level > 14, Random(10)==1 | 6 (Glass/Multiplier) | 10% | |
| 5a | Level == 20 | 7 (Sentry/Cake) | 100% | First appearance |
| 5b | Level > 20, Random(8)==0 | 7 (Sentry/Cake) | 12.5% | |
| 6 | Level > 15, Random(10)==0 | 4 (Orange/Laser) | 10% | |
| 7 | Fallback | 2 (Pawn/Lightning) | 100% | Default |

Note: Rule 2 (Ooze/Key) has **no level gate** — it can trigger from level 1 onward if total active entities > 2 and the type 5 counter is below 7.

The "total entities" check (D7) and counter thresholds use the per-type counters at A5+0x8696-0x86A0. These counters are shared between balls and yummies (incremented by CreateEntity at 0x7808, decremented by the death handler at 0x86A4).

#### Spawn Frequency

The function processes one record per call. It is invoked per-tick from the entity tick callback at 0x74EE (via 0x7512) and from level init (0x995C).

Scoring events temporarily suppress spawning via a cooldown timer. Each scoring event calls 0xF29E which adds ticks to the cooldown:

| Level Range | Ticks Added Per Score Event |
|-------------|---------------------------|
| 1-29 | 3 |
| 30+ | 6 |

A clamp prevents the countdown from exceeding 25 (~0.42 seconds at 60Hz). Spawns resume when the countdown drains to 0.

### 2. Cake Detonation Spawns

When a Yummie Cake is collected, it detonates (68K @ 0x07A1C) and spawns child yummies.

- **Count**: `Random(4) + 4` = **4 to 7 yummies** per cake
- **Per child yummy**: `Random(20)` determines type
  - Result == 5 (5% chance): **Cluster Magnets** (type 3)
  - Any other result (95% chance): **Lightning Bolt** (type 2)

Cake children are created via CreateEntity (0x7808) + yummy_setup (0x13F22), which is the full yummy initialization path. This is the ONLY caller of 0x13F22 in the entire codebase.

### 3. Level Transition Bonus Spawns

When a level is completed, the level-advance handler at 0x16074 calls the bonus yummy spawner at 0x16178. This creates floating bonus yummies with special type IDs (separate from the main 2-7 range):

| Type ID | Probability | Speed | Notes |
|---------|------------|-------|-------|
| 19 | Default | 50 | Standard bonus yummy |
| 20 | 1 in 5 | -1 (permanent?) | Rare bonus |
| 21 | 1 in 7 | -1 (permanent?) | Rare bonus |
| 22 | 1 in 8 | 80 | Rare bonus |

These use a separate callback (0x15B6C) and entity list (A5-0x1D28) from the main gameplay entities.

### Cheat Codes

Typing cheat codes during gameplay adds records to the level table via the store function at 0x8308 (68K @ 0x08CB6-0x08EE0). Each cheat code creates a record with a **concrete type** (not wildcard), so the cascade is skipped and the entity is created with the specified type:

| Cheat Code | Type ID | Entity Type |
|------------|---------|-------------|
| RIDE | 3 | Nuke / Cluster Magnets |
| ONYACK | 5 | Ooze / Key |
| LAND | 2 | Pawn / Lightning Bolt |
| ICENINE | 7 | Sentry / Yummie Cake |
| MANA | 6 | Glass / Score Multiplier |
| CIRCLES | 4 | Orange / Laser Cartridges |

Note: Because type IDs are shared between balls and yummies, and cheat code records go through the same entity creation pipeline as everything else, the resulting entity may behave as either a ball or yummy depending on runtime context.

## Ball vs Yummy Distinction

Balls and yummies share the same type IDs (2-7), the same entity allocation function (CreateEntity at 0x7808), the same per-type counters (A5+0x8696-0x86A0), the same type cascade (0x8018-0x8114), and the same record processing function (0x7F9C).

Every entity created by 0x7F9C goes through: allocate → type cascade → sprite loading → find_free_slot(1500) at 0x144C6 → set slot/bounds at 0x13F78 → position/velocity setup → register with entity list.

### The Discriminator: sprite[$1E]

The ball-vs-yummy decision happens in the **per-entity tick callback at 0x74EE**:

```
A0 = entity[$04]         ; sprite/resource pointer
TST.L ($1E, A0)          ; test sprite[$1E]
BNE   yummy_path         ; nonzero → yummy
```

- **`sprite[$1E] == 0`** → ball behavior: calls `ball_move_bounce` (0x8470) + `ball_collision_check` (0x7F9A)
- **`sprite[$1E] != 0`** → yummy behavior: calls `yummy_tick` (0x2884)

The per-type sprite pointers loaded at 0x8146-0x8164 (from A5 globals: A5-0x1E5C for type 2, A5-0x1E60 for type 3, etc.) each point to sprite resource structures. The value at offset $1E in that sprite data is what determines behavior. This is **baked into the sprite resource data** — not computed from the type ID at runtime.

### find_free_slot (0x144C6)

Called with parameter 1500 (minimum area threshold). Scans the type_info table (26-byte records at A5+0x8278) for the first slot where:
1. `record[24]` (in_use byte) is zero (slot is free)
2. The spawn bounding rect has area/10 >= 1500 (area >= 15,000 pixels)

Returns the slot index in D0 (or -1 if none found). The slot index is stored at entity[$80] and determines the entity's spawn bounding rect, not its ball/yummy behavior.

## Barrier Speed

The barrier gun has a speed/charge meter shown as a yellow bar in the UI.

- Lightning Bolt powerup restores charge to **80** (maximum)
- Charge **dissipates slightly with each life lost**
- Higher charge = faster barrier travel = safer shots and more time to clear area
- Starting charge is small and grows as you collect Lightning Bolts

## Weapons

Three fire modes use the barrier gun:

| Weapon | Sound | Ammo Source |
|--------|-------|-------------|
| Regular Barrier | Barrier Gun Fire Regular (1005) | Unlimited |
| Laser | Barrier Gun Fire Laser (1006) | Laser Cartridges (200-increment steps at A5+27358) |
| Cluster Magnets | Barrier Gun Fire Magnet (1007) | Magnet charges |

Magnets are fired two-at-a-time onto opposite walls. They pull Pawn balls out of the way and can confuse Sentry Eye vision. Fire the barrier in the opposite direction to the magnets for best effect.

## Score Multiplier

The Score Multiplier appears as a round button that cycles through values: **1/2, 2, 3, 4**. The displayed number constantly rotates, and the value shown at the moment you capture it determines your multiplier for the level.

To collect it, you must enclose it within a gated (cleared) area — the multiplier is applied to your bonus score for the rest of the level. Timing your capture to land on x4 vs x2 or the dreaded 1/2 is a key skill element.

| Captured Value | Effect | Sound |
|----------------|--------|-------|
| 4 | 4x bonus multiplier | Multiplier Got (1321) |
| 3 | 3x bonus multiplier | Multiplier Got (1321) |
| 2 | 2x bonus multiplier | Multiplier Got (1321) |
| 1/2 | 0.5x bonus multiplier (penalty) | Multiplier Got Half (1322) |

The multiplier applies to the time bonus and over-achiever bonus tallied at level end. Capturing at 1/2 effectively halves your bonus — the "Multiplier Got Half" sound plays as a warning that you mistimed it.

### Dedicated Timer-Based Spawn System

The Score Multiplier has its own spawn system separate from the type cascade. It can appear multiple times per level — if missed (despawns), it respawns after a delay. If collected, the captured value is locked in and it does not reappear.

#### Appearance Delay (0x11800, called from level init at 0x9932)

At the start of each level, a spawn timer is written to A5+0x68C2:

| Level Range | Timer Formula | Delay |
|-------------|---------------|-------|
| 1-10 | Random(3000) + 7000 | **~1m57s to ~2m47s** |
| 11+ (10% chance) | Random(250) + 250 | **~4s to ~8s** |
| 11+ (90% chance) | Random(3000) + 1000 | **~17s to ~67s** |

(All times at 60 Hz: 1 tick ≈ 16.6ms)

#### Per-Tick Check (0x8F00)

Every game tick, the handler at 0x8F00 checks:
1. Is the multiplier state == 2 (pre-appear)? If yes and `tick > A5+0x68C2`, call placement at 0x118DA.
2. Is `A5+0x68CC == -1` (not active) AND `A5+0x68CE == -1` (not collected) AND `tick > A5+0xAF6A` (respawn timer expired) AND `A5+0x6CC7 != 0` (enabled)? If all true, call spawn at 0x15AAE.

The first path handles initial appearance. The second handles respawn after a missed multiplier.

#### On-Screen Lifetime

Once placed, the multiplier stays on screen for a limited time:

| Path | Lifetime |
|------|----------|
| Primary | Random(750) + 400 ticks = **~6.7s to ~19.2s** |
| Alternate | Random(500) + 200 ticks = **~3.3s to ~11.7s** |

The lifetime target is stored at A5+0xE376. Each tick, the multiplier's update function at 0x11A98 compares the current tick against this target. When expired, the multiplier despawns (sound 1495 plays), and a respawn timer is set.

#### Respawn After Despawn

If the multiplier expires without being collected:
- Both flags reset: A5+0x68CC = -1, A5+0x68CE = -1
- Respawn timer: `Random(1500) + 500` ticks stored at A5+0xAF6A = **~8s to ~33s** until next appearance
- The per-tick check at 0x8F62 detects both flags are -1 and tick > respawn timer, spawning it again

This means the multiplier keeps reappearing throughout the level until collected.

#### Collection

When captured, A5+0x68CE is set to the captured value (not -1), which permanently blocks the respawn check at 0x8F6A for the rest of the level.

#### Value Cycling

The multiplier display oscillates through 1/2, 2, 3, 4 using an animation position at A5+0xE380:
- Position bounces between 0 and ~360 with velocity 8-16 pixels/tick
- Displayed frame = `position / 10`, giving frame indices 0-35 mapped to the 4 values
- Each cycle step takes `Random(55) + 20` ticks = **~0.33s to ~1.23s** (average ~0.78s)
- The value shown at the exact moment of capture is applied

#### State Machine (A5+0xE38B)

| State | Meaning |
|-------|---------|
| 0 | Off / inactive |
| 2 | Pre-appear (waiting for initial timer) |
| 3 | Entering screen (bounce-in animation) |
| 4 | On-screen, cycling values |
| 7 | Alternate cycling state |

#### Enable Flag (A5+0x6CC7)

- Set to 1 during game setup (0x95D4)
- Conditionally enabled at 0x9E68 when score exceeds 5,000 points
- Cleared on level completion

**Note:** The timer addresses (A5+0x68CC, 0x68CE, 0xAF6A) overlap with Bosco-related addresses documented in levels.md. The multiplier and Bosco systems may share infrastructure — both use the same "spawn via timer, guard with flags" pattern.

## Sound Effects Reference

| Sound ID | Name | Trigger |
|----------|------|---------|
| 1490 | Yummy Bounce | Yummy bouncing around the field |
| 1491 | Got Yummy | Successfully collected a yummy |
| 1492 | Cake Detonate | Yummie Cake explodes into child yummies |
| 1493 | Cake Appear | Yummie Cake materializes on field |
| 1494 | Cake Denied | Cake landed in already-cleared area (wasted) |
| 1495 | Missed Yummy | Yummy escaped or expired |
| 1496 | Yummy Storm | Multiple yummies spawning simultaneously |
| 1320 | Multiplier Appears | Score Multiplier spawned on field |
| 1321 | Multiplier Got | Full multiplier collected |
| 1322 | Multiplier Got Half | Partial multiplier collected |
| 1200 | Key Clink | Key powerup collected |
| 1201 | Key Turn | Key activation |
| 5000 | Laser Charge | Laser cartridge loading |
| 5002 | Laser Discharge | Laser cartridge spent |
| 5003 | Magnet Loaded | Magnet ammo collected |
| 10000 | New Life | Extra life gained |

## Implementation Details

| Component | 68K Offset | Notes |
|-----------|-----------|-------|
| Main entity spawner (balls + yummies) | 0x07F9C | Shared — same as ball wildcard resolver in levels.md |
| Type cascade | 0x08018-0x08114 | Shared — resolves wildcard records for all entity types |
| CreateEntity | 0x07808 | Shared allocator, increments per-type counters |
| Entity tick callback | 0x074EE | Ball/yummy branch via sprite[$1E] test |
| Ball move/bounce | 0x08470 | Called from tick callback when sprite[$1E] == 0 |
| Yummy tick handler | 0x02884 | Called from tick callback when sprite[$1E] != 0 |
| Cake detonation | 0x07A1C | Only caller of yummy_setup (0x13F22) |
| Yummy setup (full init) | 0x13F22 | Called only from cake detonation |
| Set slot/bounds | 0x13F78 | Stores slot index + bounding rect (not type-specific) |
| find_free_slot | 0x144C6 | Scans type_info table for free slot with area >= 15000 |
| Level transition bonus spawner | 0x16178 | Creates bonus yummies (types 19-22) |
| Multiplier timer setup | 0x11800 | Called from level init at 0x9932 |
| Multiplier per-tick check | 0x08F00 | Triggers placement when timer expires |
| Multiplier placement | — | Plays sound 1320, sets active flag |
| Cheat code handler | 0x08CB6-0x08EE0 | Adds records to level table (0x8308) |
| Spawn timing / cooldown | 0x0F29E | Levels 1-29: +3 ticks, levels 30+: +6 ticks per score event |
| Per-type counters | A5+0x8696-0x86A0 | Shared between balls and yummies |
| Entity death handler | 0x086A4 | Decrements per-type counters |
| Type info table | A5+0x8278 | 26-byte records: 8-byte spawn rect, 8-byte collision rect, data, in_use flag |
| Multiplier timer | A5+0x68C2 | Spawn delay (ticks) |
| Multiplier active flag | A5+0x68CC | 1=active, -1=inactive |
| Multiplier collected flag | A5+0x68CE | -1=not collected, else=captured value |
| Multiplier enable | A5+0x6CC7 | Master on/off flag |
| Cooldown timer | A5+0x8688 | |
| Burst modifier | A5+0x868A | |
| Laser charge counter | A5+27358 | |
