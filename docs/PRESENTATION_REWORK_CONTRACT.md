# Shadowborn — presentation rework contract

This branch intentionally replaces the roaming graybox presentation with a battle-first mobile RPG slice.

## Non-negotiable direction
- Godot 4.4.1.
- iOS first, iPhone 13 Pro baseline.
- 60 FPS target, 30 FPS fallback.
- No free-roam directional controls in the primary loop.
- World navigation is node/icon driven; battle rooms load as authored combat stages.
- Combat framing uses a fixed cinematic side/three-quarter camera.
- Turn-meter combat remains the systemic foundation.
- Auto battle and x2 presentation speed are first-class controls.
- Shadowborn canon, characters, progression, skills, loot and world remain original.

## Quality gate
A scene is not accepted as playable content while it is only boxes/capsules with debug UI. Graybox geometry may exist behind authored visuals, but never as the user-facing target presentation.

## Vertical slice target
1. Launch directly into one polished sewer/temple combat room.
2. 2 allied units versus 2 enemies for framing validation.
3. Readable faces/silhouettes, idle motion, lunge, hit reaction, death.
4. Turn order, HP, turn meter, A1/A2, AUTO, x1/x2.
5. Fixed camera and no movement arrows.
6. Later replace procedural stand-ins with licensed/original skinned GLB characters without changing combat layout APIs.
