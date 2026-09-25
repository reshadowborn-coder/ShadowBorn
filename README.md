# Shadowborn

Fresh gameplay reboot of Shadowborn as an iPhone-first, fixed-camera, turn-meter dark-fantasy RPG.

## Core loop

Title → Campaign node → authored battle room → turn-meter combat → result.

There is no free-roam joystick layer in the primary loop. The world is navigated through authored nodes and encounters; combat is presented in staged 3D rooms.

## Current playable slice

- Act I / 1.1 Sewers
- Three waves
- Shadow basic attack + Shadow Lunge
- Enemy basic + poison attack
- Speed-driven turn meter
- Poison, stun, freeze and sleep rules in the combat core
- Manual / AUTO
- x1 / x2
- Fixed cinematic three-quarter camera
- Attack windup, impact, hit reaction, death and damage callouts
- Mobile-first 1920×1080 reference canvas and iOS Metal/mobile renderer

## Art pipeline

The runtime checks for:

- `assets/characters/shadow/shadow.glb`
- `assets/characters/rat/rat.glb`

When those files exist, they replace development fallback visuals automatically. Fallback meshes exist only so mechanics, framing and animation timing can be tested before final skinned assets land.

## Performance baseline

Primary target: iPhone 13 Pro, 60 FPS. A 30 FPS battery mode will be added only after the visual slice is stable.

## Important

The old Act 0/Act 1 graybox architecture is intentionally absent from the reboot branch. It remains preserved in Git history and on `main`.
