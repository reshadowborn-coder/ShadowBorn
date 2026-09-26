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

## Visual rebuild boundary

The current player-visible Quaternius/primitive presentation is **debug-only** and failed visual acceptance. It is not the shipping art baseline.

The runtime now separates production content from debug fallbacks through `VisualAssetPolicy`.

Required production paths:

- `assets/characters/shadow/shadow.glb`
- `assets/characters/grave_hound/grave_hound.glb`
- `assets/weapons/shadow_sword/shadow_sword.glb`
- `assets/environments/checkpoint01/awakening_environment.tscn`
- `assets/environments/checkpoint01/grave_hound_arena.tscn`

Debug/vendor assets are allowed only outside visual-acceptance mode. Run the manual **Shadowborn Visual Acceptance** workflow when the production pack is ready; it intentionally fails while required production assets or environment anchors are missing.

See `docs/VISUAL_REBUILD_PLAN.md` for the rebuild sequence and acceptance rules.

## Target

Godot 4.4.1, iPhone-first, iPhone 13 Pro baseline, 60 FPS target.
