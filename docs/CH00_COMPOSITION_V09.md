# Chapter 0 composition pass v0.9

Purpose: make the route read as an authored journey rather than three boxes in a straight corridor, without increasing the dynamic-light budget.

Implemented:
- Awakening burial pocket around the starting point: slab, asymmetric broken walls, fallen arch, grave marker.
- Mid-route occlusion masses so the temple is not continuously exposed from spawn.
- Broken reveal arch and foreground screens before the forecourt.
- One-shot temple reveal trigger: temporarily takes camera ownership, frames the facade, then returns control.
- Reveal is presentation-only. It does not mutate combat state, damage, cooldowns, checkpoints, or save data.
- Existing combat arenas remain deliberately clear; decoration is pushed to route edges and foreground/background framing.

Mobile contract:
- no new dynamic lights;
- all new architecture reuses the existing stone material;
- no transparent vegetation/fog cards added;
- reveal uses the existing camera only;
- collision/gameplay remains separable from decorative geometry for the later art replacement pass.

Next pass:
1. split decorative and gameplay/collision roots explicitly;
2. replace box tombstones with a small reusable grave/ruin proxy kit;
3. improve Shadow/enemy proportions and contact staging;
4. add an opening camera handoff that never consumes the player's first input;
5. runtime validation in Godot/Android remains mandatory before performance claims.
