# Splitfield Powerup System

Powerups in Splitfield are called "yummies." They appear on the playing field during gameplay and can be collected by hitting them with a barrier or enclosing them in a cleared area.

## Yummy Types

| Type ID | Name | Effect |
|---------|------|--------|
| 2 | Lightning Bolt | Recharges barrier speed to 80 (max) |
| 3 | Cluster Magnets | Grants magnet ammo (+100 charges) |
| 4 | Laser Cartridges | Grants laser ammo (+100 charges, 200-increment steps) |
| 5 | Key (Extra Lives) | Grants 1-5 extra lives instantly |
| 6 | Score Multiplier | 2x score multiplier on bonus points |
| 7 | Yummie Cake | Explodes into 4-7 child yummies |

## On-Screen Behavior

Most yummies bounce around the playing field after spawning, bouncing off barriers and the edges of cleared areas like balls do. They must be collected before they expire or leave the field.

The **Score Multiplier** is the exception — it appears at a fixed position and stays stationary, cycling through its values (1/2, 2, 3, 4) until captured or it expires.

The **Yummie Cake** also behaves differently — it drops onto the field and detonates on impact, immediately spawning 4-7 child yummies. If it lands in an already-cleared area, it sinks and is wasted.

## How to Collect Yummies

- **Barrier hit**: fire a barrier that intercepts a bouncing yummy mid-flight
- **Capture**: enclose the yummy inside a newly cleared area (works for both bouncing yummies and the stationary multiplier)
- **Cake warning**: if a Yummie Cake lands in already-cleared area, it sinks and is lost

## Three Spawn Systems

Yummies come from three independent systems running in parallel.

### 1. Regular Field Spawns

The primary spawn system (68K @ 0x07F9C). Runs every tick, subject to a cooldown timer. Selects yummy type based on current level with weighted random rolls.

#### Type Selection by Level

Each empty spawn slot is resolved by checking conditions in priority order. The first match wins; if nothing matches, the slot becomes a Lightning Bolt.

| Priority | Levels | Type | Probability | Condition |
|----------|--------|------|-------------|-----------|
| — | 1-4 | Lightning Bolt | 100% | Always, no other types possible |
| — | 5 | Cluster Magnets | 100% | Guaranteed introduction |
| — | 6-9 | Lightning Bolt | 100% | No other types in normal play |
| 1 | 10+ | Key (Extra Lives) | 33% | Random(3)==0, requires cheat charges > 2 and MANA counter < 7 |
| 2 | 10, 18 | Cluster Magnets | 100% | Guaranteed on these levels |
| 3 | 21+ | Cluster Magnets | 25% | Random(4)==0, gated by ONYACK counter thresholds |
| 4 | 15+ | Score Multiplier | 10% | Random(10)==1 |
| 5 | 20 | Yummie Cake | 100% | Guaranteed introduction |
| 5 | 21+ | Yummie Cake | 12.5% | Random(8)==0 |
| 6 | 16+ | Laser Cartridges | 10% | Random(10)==0 |
| Default | Any | Lightning Bolt | 100% | Fallback if nothing else matched |

Levels 5, 10, 18, and 20 guarantee specific types as introductions to new powerups.

**Note on Keys:** Key (Extra Lives) yummies only spawn from the field system if the player has used cheat codes (total cheat charges > 2, MANA specifically < 7). In normal cheat-free play, Keys only come from the pattern/sequence spawn system. Similarly, Cluster Magnets at level 21+ are gated by the ONYACK cheat counter.

#### Spawn Frequency

The game loop runs at ~60 Hz (Mac VBL rate), so one tick = ~16.6ms. Two linked counters control spawn timing:

| Variable | Game Start | Each New Level | Min | Role |
|----------|-----------|----------------|-----|------|
| Countdown (A5-31096) | 5 | Reset to 0 | — | Active countdown. Decrements by 1 each idle frame. Spawn triggers when it hits 0. |
| Cooldown (A5-31094) | 45 | Reset to 50 | 25 | Grows by 1 each idle frame. Reset to 50 after a spawn. |

Each frame, if countdown > 0: countdown decrements by 1 and cooldown increments by 1. When countdown reaches 0, a yummy spawns and cooldown resets to 50.

**Scoring delays spawns.** Every time points are scored (barrier completion, ball nuke, etc.), the function at 0xF29E **adds ticks to the current countdown** while reducing the cooldown for future intervals. This means active play (completing barriers, scoring points) continuously pushes the next spawn further away. The spawn only actually fires during lulls when the player stops scoring long enough for the countdown to drain to zero.

This creates a natural rhythm: yummies appear **between actions**, not during them. While you're actively drawing barriers and scoring, the countdown keeps getting extended. When you pause to plan your next shot, the countdown drains and a yummy appears.

| Scenario | Approximate Timing |
|----------|-------------------|
| First spawn of a new game | ~0.08 sec (countdown starts at 5) |
| Base interval (no scoring) | ~0.83 sec (50 ticks) |
| During active play | Several seconds between spawns (scoring keeps extending countdown) |
| Minimum interval (clamped) | ~0.42 sec (25 ticks, after heavy scoring reduces cooldown to minimum) |

The minimum clamp of 25 ticks (~0.42 sec) applies to both the countdown and cooldown — if scoring would push either below 25, they're set to 25 instead.

### 2. Cake Detonation Spawns

When a Yummie Cake is collected, it detonates (68K @ 0x07A1C) and spawns child yummies.

- **Count**: `Random(4) + 4` = **4 to 7 yummies** per cake
- **Per child yummy**: `Random(20)` determines type
  - Result == 5 (5% chance): **Cluster Magnets** (type 3)
  - Any other result (95% chance): **Lightning Bolt** (type 2)

Cakes only produce Lightning Bolts and Cluster Magnets. No other types. If you see a Laser or Multiplier appear at the same time as a cake detonation, it came from the regular field spawn system firing on the same frame.

### 3. Pattern/Sequence Spawns

A hidden combo system (68K @ 0x08CE0) monitors yummy collection patterns. Six secret sequences each trigger a specific yummy type when completed:

| Pattern | Reward Type |
|---------|-------------|
| Sequence 1 | Cluster Magnets |
| Sequence 2 | Key (Extra Lives) |
| Sequence 3 | Lightning Bolt |
| Sequence 4 | Yummie Cake |
| Sequence 5 | Score Multiplier |
| Sequence 6 | Laser Cartridges |

The patterns are enqueued into the same spawn queue used by the field spawn system.

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

| Component | 68K Offset | PPC Offset |
|-----------|-----------|------------|
| Regular field spawn | 0x07F9C | ~0x0CC60 |
| Cake detonation | 0x07A1C | 0x0C4E4 |
| CreateYummy | 0x07808 | 0x0C170 |
| Pattern/sequence spawn | 0x08CE0 | — |
| Spawn acceleration on score | 0x0F29E | — |
| Cooldown timer | A5-31094 | — |
| Burst modifier | A5-31096 | — |
| Laser charge counter | A5+27358 | — |
