# Checkpoint 01 — Animation Rebuild Brief

## Goal

Replace generic semantic stand-ins with purpose-built combat motion while keeping gameplay state authoritative.

Current non-shipping shortcuts include reversed Death, Roll/Run as A2 preparation, slowed generic Sword_Slash as heavy identity and one generic Hound Attack.

## Semantic animation model

Every combat action must expose four readable phases:

1. **Anticipation** — player understands an action is starting.
2. **Commitment** — motion is no longer just idle/setup.
3. **Semantic contact** — visual hit aligns with authoritative combat event.
4. **Recovery** — actor returns to stable actionable state.

Animation never decides damage, cooldown or turn ownership. It is calibrated to the combat resolver.

## Shadow minimum clips

- `SHD_AWAKENING_01`
- `SHD_RECOVER_STAND_01`
- `SHD_IDLE_COMBAT_01`
- `SHD_A1_SWORD_01`
- `SHD_A2_LUNGE_01`
- `SHD_HIT_LIGHT_01`
- `SHD_DEATH_01`
- `SHD_PICKUP_SWORD_01`

## Grave Hound minimum clips

- `HND_IDLE_LOW_01`
- `HND_LOCO_01`
- `HND_BITE_01`
- `HND_RUSH_REND_01`
- `HND_HIT_01`
- `HND_DEATH_01`

## Motion rules

### Shadow
- A1 compact and efficient;
- A2 has a clearly different whole-body preparation and commitment;
- weight comes from center-of-mass shift, momentum and recovery, not universal slow motion;
- feet/weapon do not magnetically home during the active contact phase.

### Hound
- real canid footfall logic first;
- whole body participates in Bite/Rush;
- jaw contact is supported by neck/chest drive;
- Rush prep must be visually distinct from idle;
- no mid-active homing.

## Import / retarget contract

- author/export baseline: Blender 5.2.2 LTS -> glTF/GLB -> Godot 4.7.2;
- begin with a 30 FPS animation-bake baseline that matches the DCC; increase only when a fast-motion import comparison demonstrates lost curve fidelity;
- enable trimming and immutable-track removal where they preserve the authored action;
- keep `Always Sample` off by default because it increases imported data; enable it only when Blender/glTF interpolation differs materially from the Godot result;
- Shadow humanoid retargeting must validate both BoneMap and Bone Rest, not bone names alone. Godot can warn about mapping problems without blocking import, so a successful import is not an acceptance signal;
- Grave Hound stays on a dedicated quadruped rig. Do not force the humanoid profile onto it;
- separate AnimationLibrary assets are allowed when they reduce duplication and retarget parity is proven.

## Diagnostic pose-strip policy

CI captures normalized pose samples at 15%, 50% and 85% for action-shape review. These three samples are deliberately **diagnostic only**:

- they expose whether anticipation, commitment and recovery produce distinct silhouettes;
- they make generic/reused attacks easier to reject;
- they do **not** define hit timing;
- 50% of a clip is never assumed to be semantic contact.

Production contact timing is authored/calibrated explicitly against the combat resolver and then validated in the shipping camera.

## Root / warping policy

Gameplay movement remains authoritative.

Allowed:
- bounded pre-contact alignment;
- small foot/paw ground correction;
- camera-safe orientation adjustment.

Forbidden:
- large magnetic warp during active frames;
- warp that hides bad authored locomotion;
- animation callback changing combat outcome.

## Secondary motion

Cloth, straps, tail, loose skin and particles are secondary.

They may be reduced for mobile performance, but:
- main pose;
- weapon/jaw trajectory;
- anticipation;
- contact;
- recovery

must remain intact.

## 30/60 and x1/x2

The same semantic contact order must hold at 30 and 60 FPS.

Presentation speed may compress clip time for a debug/test speed mode, but must not create a different gameplay outcome.

## Acceptance

For each clip record:

- anticipation start;
- commitment marker;
- semantic contact;
- visible contact;
- recovery end;
- foot/paw contact notes.

PASS requires:
- silhouette distinction at gameplay camera;
- no obvious foot/paw skate;
- visible contact within accepted tolerance of semantic contact;
- no recovery before hit feedback;
- user-rated motion materially above current 10/100 baseline.
