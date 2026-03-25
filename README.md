# Splitfield

A JezzBall/Qix-style arcade puzzle game built with Godot 4.6.

Fire barrier beams across the field to section off space while bouncing balls try to destroy your beams. Fill 80% of the field to advance. Infinite procedurally generated levels.

**[Play in your browser](https://gettierproblem.github.io/splitfield/)**

## Controls

- **Left click / tap** — fire beam
- **Space / Right click** — toggle horizontal/vertical orientation
- **Scroll up / W** — load laser cartridge (fast beam, uses ammo)
- **Scroll down / D** — load cluster magnet (attracts balls, uses ammo)
- **Scroll reverses / Middle click** — unload (scroll down while laser loaded unloads, etc.)
- **Esc / Pause button** — pause

## Demo Replay

Every game is automatically recorded. High scores appear on the main menu — click any score to watch its demo.

**Playback controls:**
- **Progress slider** — drag to seek (forward or backward)
- **Speed** — cycle through 1x / 2x / 4x / 8x
- **Pause / Play** — pause and resume playback
- **Replay** — restart the demo from the beginning
- **Stop** — return to main menu

Demos are stored as compact binary files (~360KB for 10 minutes) using deterministic input recording with seeded RNG replay.
