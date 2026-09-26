# Checkpoint 01 Environment — Production Brief

## Scope lock

Build only:

1. Awakening pocket.
2. Grave Hound arena.

Do not expand into Temple, sewer, second encounter or broader Act 1 production until this checkpoint passes user visual acceptance.

## Production paths

- `res://assets/environments/checkpoint01/awakening_environment.tscn`
- `res://assets/environments/checkpoint01/grave_hound_arena.tscn`

## Required scene contract

### Awakening environment

Required nodes:
- `AwakeningCamera` — Camera3D
- `ShadowSpawn` — Node3D
- `SwordSpawn` — Node3D

### Grave Hound arena

Required nodes:
- `BattleCamera` — Camera3D
- `PlayerHome` — Node3D
- `EnemyHome` — Node3D
- `CameraTarget` — Node3D

These nodes are part of the runtime contract and are checked by the manual Visual Acceptance workflow.

## Awakening composition

One strong image, not generic clutter:

- hero grave/slab or corpse-resting structure;
- broken funerary masonry;
- one memorable architectural motif;
- controlled route/negative space;
- authored foreground framing;
- background mass that supports the Shadow silhouette.

The player should remember “where I woke up”, not merely “gray cemetery”.

## Grave Hound arena

- clean central combat plane;
- authored edge density outside silhouettes and attack travel;
- one environmental landmark;
- no waist-high clutter crossing actor bodies;
- no repeated BoxMesh wall rhythm as final art;
- visual continuity with Awakening, but a distinct encounter image.

## Minimum modular kit

Checkpoint-only subset:

- 2–3 wall/ruin modules;
- broken wall variant;
- arch/threshold hero module;
- hero grave/slab;
- 3–5 grave-marker variants;
- 3–5 rubble pieces with size hierarchy;
- one iron/wood funerary prop family;
- ground transition elements;
- decals/masks for damp, soot, mineral stain and local damage.

## Material families

At minimum:

- weathered cemetery stone;
- cut/dressed funerary stone;
- damp/darker burial stone;
- rubble/break stone;
- oxidized iron;
- old wood;
- restrained organic ground.

Use authored PBR maps/trim/shared detail strategy. Procedural sine/noise shaders remain debug-only.

## Damage and aging

Every visible break should answer at least one cause:

- structural collapse;
- battle impact;
- long-term water ingress;
- foot traffic;
- repair/rebuild;
- root/soil pressure.

Avoid random crack noise as a substitute for damage history.

## Lighting ownership

Production environment scenes own:

- WorldEnvironment;
- authored lights;
- fog/atmosphere setup;
- final camera framing.

Lighting is tuned only after real geometry/materials are integrated.

Do not use extra blue fog, bloom or rim lights to hide weak modeling.

## Mobile rules

- Mobile renderer supported features only;
- one or very few real-time shadow casters, justified by profile;
- avoid alpha-heavy vegetation/fog stacks;
- material/sample count measured;
- repeated background families may use clustered MultiMesh only after culling/readability review;
- 1K/2K source maps are default candidates; higher resolution requires visible gameplay-camera benefit.

## Acceptance

PASS only when:

- acceptance workflow finds all required scene anchors;
- no debug primitive environment is visible;
- blind screenshot reads as a specific abandoned funerary place;
- Shadow/Hound silhouette remains clean;
- material families stay distinct at phone size;
- user review materially exceeds the previous 5/100 baseline;
- target-device 30/60 evidence is acceptable.
