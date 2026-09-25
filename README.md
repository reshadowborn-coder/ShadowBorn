# Shadowborn — Checkpoint 01

The reboot branch is deliberately restricted to two things:

1. Awakening cinematic.
2. First battle against the Grave Hound.

Nothing else should expand until this checkpoint is tested and approved.

## Test flow

Title → BEGIN → awakening cinematic → first battle → checkpoint result → replay/title.

## Controls

- Tap/click during the awakening cinematic to skip.
- A1: Basic Slash.
- A2: Shadow Lunge.
- AUTO: on/off.
- x1/x2 battle speed.

## Final-art hooks

The runtime automatically looks for:

- `assets/characters/shadow/shadow.glb`
- `assets/characters/grave_hound/grave_hound.glb`

If present, those skinned assets replace the procedural development stand-ins.

## Target

Godot 4.4.1, iPhone-first, iPhone 13 Pro baseline, 60 FPS target.
