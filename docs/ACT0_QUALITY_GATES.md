# Shadowborn — ACT 0 + Temple Quality Gates

Status: USER CANON / production quality contract
Current user-reported visible build quality (2026-10-09): approximately 2/100. Historical 2026-09-26 baseline: 5/100.
Historical 2026-09-28 feedback: 8.5/100 (previously 7/100), with a then-preferred diagonal angle. SUPERSEDED by the latest user canon: fixed battle rooms, controlled side-on RAID-like camera, no manual movement or walkable traversal, and no visible travel. Historical ratings do not override the latest approximately 2/100 quality assessment.

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
- Improve in this order: composition/camera -> focal Shadow/Hound silhouettes and production assets -> animation/contact -> lighting/value -> materials/VFX -> microdetail.
- Dark mood must not become black mush. Shadow, enemy, fixed battle floor and room landmarks must remain readable on a phone-sized image.
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

## Renderer provenance evidence gate
- GL Compatibility/OpenGL screenshots are diagnostic projection and layout proxies, not Mobile renderer or iPhone Metal acceptance. Record exact commit SHA, Godot version, renderer, driver, viewport and production/preview asset tier with every capture.
- Mobile renderer screenshots from a supported desktop Vulkan runner are a separate intermediate test. If Mobile cannot initialize, report UNAVAILABLE rather than silently falling back to GL.
- Only a physical iPhone 13 Pro Metal capture can validate target lighting/VFX, safe-area touch placement, GPU frame time and thermal behavior. Do not raise the 2/100 visible-quality estimate from CI or proxy images.
- A production provenance tag on an environment scene proves source ownership, not visual approval; final Shadow/Hound GLBs and camera-view silhouette/CONTACT_T0_POST_DRAW evidence remain required.

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
Current user-reported visible quality remains approximately 2/100 until new gameplay-camera and physical-device evidence justifies a revised user assessment. Preserve earlier 5/100 and 8.5/100 ratings as dated history only.
Research/technical maturity must always be reported separately.
No synthetic progress percentage.
