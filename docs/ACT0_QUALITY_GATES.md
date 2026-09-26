# Shadowborn — ACT 0 + Temple Quality Gates

Status: USER CANON / production quality contract
Baseline visual-gameplay readiness: 5/100

## Why this file exists
The current slice may be technically functional while still looking wrong from the player's camera. These gates exist to prevent repeating visible orientation, staging and presentation mistakes and to make progress measurable by what the player actually sees.

## Non-negotiable visual checks

1. Camera-first validation
- Every character, weapon, enemy, VFX and prop is judged from the final gameplay/cinematic camera, not from local axes or editor view.
- "Technically facing correctly" is not enough. If the player sees a back, wrong weapon direction, hidden face, broken silhouette, or unreadable action, it is a failure.
- Any orientation/facing change must be verified in the actual camera composition before readiness can increase.

2. Shadow weapon pickup
- When Shadow is shown from behind or 3/4-back, the rusty sword must lie and rotate so the blade/hilt direction makes physical sense relative to Shadow's hand and camera.
- Pickup animation, prop orientation, hand socket orientation and final equipped orientation are separate transforms and must be validated separately.
- The sword must never visually point toward the camera in a way that makes Shadow appear to grab it backwards.
- The transition world-prop -> hand socket must not pop, flip 180 degrees, teleport, or change scale.

3. Grave Hound facing
- Grave Hound must visually face Shadow in idle, windup, attack and recovery.
- Imported-model forward axis must be corrected on the visual/model layer without corrupting combat root logic.
- Root look_at alone is not accepted as proof.
- A combat-camera check must confirm head/chest direction, eye visibility and attack contact direction.
- If the hound reads as showing its back to Shadow/player, the build fails this gate.

4. Visible quality beats technical completion
- Do not raise ACT 0 + Temple readiness for code cleanup, research, CI green status, data structures, hidden optimization or asset quantity alone.
- Readiness increases only for changes that materially improve what the player sees/feels in the vertical slice.
- CI/static tests prove stability only, not visual quality or iPhone performance.

5. Graphics priority
- Current graphics quality is below target and must be treated as a primary production problem.
- Improve in this order: composition/camera -> actor silhouette -> lighting/value separation -> material families -> animation/contact -> restrained VFX -> microdetail.
- Dark mood must not become black mush. Shadow, enemy, path and landmark must remain readable on a phone-sized image.
- Avoid adding clutter/detail before macro readability is solved.

6. Shadow quality target
- Shadow must read as a coherent dark-fantasy protagonist, not as a generic dev humanoid with a dark material.
- Faceless void, hood, eyes, cloth silhouette, weapon and restrained smoke must work as one design.
- Temporary primitive additions must not distort human head/body proportions.

7. Grave Hound quality target
- Must read immediately as an undead/zombie dog, not a normal wolf with red eyes.
- Scale must remain approximately waist-high to Shadow.
- Undead cues should favor silhouette, emaciation, wounds/bone exposure, material decay and animation rather than expensive transparent FX.

8. Performance target
- iOS-first, iPhone 13 Pro, 60 FPS target.
- Prefer shared materials, instancing, GPU particles and bounded lights/shadows.
- Reduce transparent effects and cosmetic particles before sacrificing actor readability.
- Physical-device profiling is required before claiming performance target achieved.

## Required regression workflow
Before merging a presentation change:
1. Inspect the real final camera.
2. Check Shadow facing.
3. Check sword world orientation and pickup orientation.
4. Check Grave Hound visual facing in idle and attack.
5. Check actor silhouettes at phone-size/downscaled view.
6. Run Godot/CI/static tests.
7. Do not increase readiness unless the visible result is clearly better.

## Progress rule
User-established baseline remains 5/100 until the visible slice genuinely improves.
Research/technical maturity must always be reported separately.
No synthetic progress percentage.
