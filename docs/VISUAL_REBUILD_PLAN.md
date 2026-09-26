# Shadowborn Visual Rebuild Plan — Checkpoint 01

## Why this exists

The current Checkpoint 01 build is a technical stand-in, not an acceptable visual baseline.

Direct user device review on 2026-09-26 scored the current build approximately:

- overall visual quality: **5/100**
- animation: **10/100**
- lighting/shadows: **5/100**
- environment/interior: **5/100**

The current runtime uses vendor development meshes, primitive programmatic environment geometry, procedural placeholder materials and reused generic animation clips. Those are useful for combat/system verification, but they must not silently become shipping art.

## Non-negotiable rule

**Do not polish the placeholder stack into permanence.**

Performance tests can reject an expensive or unstable implementation. They cannot certify art quality. Visual acceptance requires gameplay-camera review by a human/user on the target device.

## Phase 1 — production asset boundary

Required production paths:

- `assets/characters/shadow/shadow.glb`
- `assets/characters/grave_hound/grave_hound.glb`
- `assets/weapons/shadow_sword/shadow_sword.glb`
- `assets/environments/checkpoint01/awakening_environment.tscn`
- `assets/environments/checkpoint01/grave_hound_arena.tscn`

Rules:

- vendor Quaternius assets remain debug-only;
- primitive emergency meshes remain debug-only;
- visual-acceptance mode must fail loudly when production assets are missing;
- every instantiated character carries provenance metadata;
- environment scenes are authored separately from gameplay code.

## Phase 2 — authored characters

### Shadow
Purpose-built silhouette, hood/head/face void, cloth/leather/metal/shadow surfaces, production sword socket, clean deformation.

### Grave Hound
Purpose-built canine/undead anatomy, clean jaw/neck/spine/shoulder deformation, readable head/rib silhouette without neon-eye dependence.

## Phase 3 — purpose-built animation

Forbidden as shipping substitutes:
- reversed Death as resurrection;
- Roll/Run as A2 preparation;
- slowed generic slash as heavy identity;
- one generic Attack for all Hound actions.

Minimum authored set:
- Shadow: formation/recovery, idle, A1, A2, hit, death.
- Hound: idle, locomotion, bite, rush/rend, hit, death.

## Phase 4 — environment/material rebuild

Only the bounded Checkpoint 01 environments are rebuilt:
1. Awakening pocket.
2. Grave Hound arena.

Use an authored cemetery/crypt modular kit, grave markers, hero grave/slab, believable masonry/rubble, and PBR stone/iron/wood/cloth/bone/organic families. Inline sine/noise shaders remain debug-only.

## Phase 5 — lighting/camera/VFX

Order:
1. composition/silhouette;
2. material response;
3. key/fill/separation;
4. shadows;
5. fog/atmosphere;
6. VFX;
7. secondary particles/cloth.

Do not hide weak geometry with fog, bloom or extra rim lights.

## Acceptance ladder

A. Asset provenance — no player-visible vendor/debug asset in acceptance mode.
B. Gameplay-camera image quality — user/human review.
C. Animation quality — no placeholder semantic clip.
D. Target device — iPhone 13 Pro 60 FPS target, stable 30 FPS, no cold first-use hitch.

## Scope lock

Do not build Temple, sewer, second encounter or broader Act 1 art until Awakening + Grave Hound pass this visual checkpoint.
