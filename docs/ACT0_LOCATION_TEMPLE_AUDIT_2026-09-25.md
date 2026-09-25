# Shadowborn Act 0 Location & Temple Hub Audit — 2026-09-25

## Goal

Keep Act 0 readable and atmospheric on iPhone without turning the opening into an open-world traversal problem or a static menu room.

The current design target is a compact Dark Souls-like onboarding route:
awakening -> cemetery/ruin corridor -> Temple reveal -> Temple safe hub -> Catacombs.

## Competitive reference lessons

### Firelink Shrine / Souls hubs

Useful patterns:
- one dominant visual anchor gives the player orientation;
- service NPCs occupy recognisable corners rather than generic menu points;
- NPCs visually perform their role (for example a blacksmith working at an anvil);
- hub NPC population changes as progression advances;
- ruin, asymmetry and vertical silhouettes make a safe space memorable without making it visually clean.

Do not copy:
- console-scale wandering distance;
- repeated long walks between services;
- interaction density that assumes a controller and large display.

### Roundtable-style base of operations

Useful patterns:
- the hub is a preparation space, not just a pause screen;
- merchant, equipment/progression and practice functions are spatially separated;
- services become more meaningful as progress advances;
- the central focal point visually communicates "this is home/base".

For Shadowborn:
- Keeper -> Covenant -> Smith -> Catacombs remains the authored progression spine;
- Merchant and Engraver can stay initially limited, but should look like real service stations;
- the Temple must visibly react to the Room 5 story handoff.

### Knighthood / mobile RPG readability

Useful patterns:
- role and action should be legible at phone scale;
- forging, heroes and progression are presented with strong silhouettes and short interaction loops;
- mobile readability is more important than dense environmental detail.

For Shadowborn:
- use large role silhouettes and distinct station accents;
- avoid small visual clutter in the central movement lane;
- keep expensive lighting and particles bounded.

## Current Act 0 exterior assessment

### Strong

- The awakening pocket gives an immediate contained start.
- The cemetery/ruin route has a clear forward axis.
- Hound -> Armless -> Temple reveal -> Shield creates escalating authored beats.
- Broken walls, graves, steps, moss, dead trees and columns already support the abandoned battle-site tone.
- The Temple is a distant landmark before it becomes an interactable hub.
- The route is intentionally linear enough for mobile onboarding without feeling like a menu.

### Still production-dependent

- final material breakup and decals;
- fog/atmospheric depth;
- production foliage;
- authored environmental audio;
- final character/enemy animation;
- physical iPhone camera/framing review.

Do not widen the exterior into an open-world space during Act 0 polish.

## Temple assessment before this pass

The functional layout was correct, but the presentation was too static:
- Smith existed as an anvil/forge with no smith character;
- Merchant existed as a counter/shelf with no merchant;
- Engraver existed as a table/rune stones with no engraver;
- Keeper was only a body/head proxy;
- Covenant lacked a strong vertical focal frame;
- the nave was too clean and box-like;
- the hub did not visually change after the first story summon.

## Temple changes in this pass

### Living service NPCs

Added lightweight articulated graybox NPCs:
- Keeper;
- Smith;
- Merchant;
- Engraver;
- Gravebound Warden story companion.

Their silhouettes are intentionally different:
- Smith: wider/heavier;
- Merchant: smaller/hooded;
- Engraver: narrow/tall;
- Keeper: elongated ritual silhouette;
- Warden: broad armored guard silhouette.

### Role-specific motion

The NPCs no longer stand statue-still.

Keeper:
- breathing;
- slow body sway;
- slow head scan;
- restrained hand movement;
- interaction nod.

Smith:
- breathing;
- repeating hammer-work cycle;
- hammer and hammer head move as one articulated tool;
- head movement toward the work;
- interaction reaction that interrupts the work pose.

Merchant:
- breathing;
- head scanning;
- small hand gestures;
- interaction acknowledgement gesture.

Engraver:
- forward working posture;
- fast stylus/scratching movement;
- slower head movement;
- interaction reaction that lifts attention from the work.

Gravebound Warden:
- restrained guard breathing;
- subtle weight shift;
- head scan;
- fixed shield/sword silhouette.

Reduced Motion lowers ambient movement amplitude rather than changing gameplay composition.

### Mobile CPU protection

Temple NPC pose updates sleep while the player is outside the hub range.
Hidden story-companion visuals do not animate.

### Progression-reactive hub

The Gravebound Warden is hidden on a fresh game.
It becomes visible only after the committed Room 5 story-summon handoff.

This makes the Temple visibly remember progression instead of only changing save flags/UI.

### Hub architecture and environmental storytelling

Added low-cost geometry:
- Covenant vertical spines/crown;
- Covenant rune focal mark;
- service backdrops and role sigils;
- broken roof ribs;
- torn banners;
- broken pews;
- restrained rubble along the walls.

The central traversal lane stays clear.

### Lighting strategy

No additional Light3D nodes were added.

Important service/focal marks use emissive materials:
- Smith ember/forge mark;
- Engraver rune mark;
- Keeper mark;
- Covenant rune core.

This improves phone-scale readability while avoiding multiple dynamic lights and shadow costs.

## Remaining gaps before production quality

### P0 — explicit interaction affordance

Temple interactions are still Area-enter driven.

Before final UI polish, evaluate a mobile context-interact affordance:
- proximity indicator;
- one large interaction button;
- no accidental menu opening while simply crossing a service trigger.

Do not add this until the touch-flow is tested against the current automatic tutorial pacing.

### P0 — production character animation

Current motion is intentionally cheap graybox articulation.

Production replacement needs:
- skeleton/rig contract;
- idle loop;
- role/work loop;
- interaction reaction;
- transition/blend rules;
- interruption safety;
- Reduced Motion policy;
- animation LOD/range policy.

### P1 — hub audio identity

Need separate low-cost audio zones:
- forge metal/ember loop;
- distant Temple wind/stone resonance;
- restrained rune tone near Engraver/Covenant;
- catacomb air/rumble near the passage.

Audio should reinforce spatial orientation, not become constant loud ambience.

### P1 — stronger return-state changes

Possible later visual changes:
- forge state after first committed forge;
- Covenant mark after joining;
- restrained companion staging after Act 0 completion;
- Merchant/Engraver visual activation when their real systems unlock.

Any state change must be derived from committed progression, never tentative runtime state.

### P1 — physical iPhone validation

CI protects:
- node/mesh/material/light budgets;
- asset sizes;
- safe-area policy;
- Debug and Release iPhone compilation.

Still required on physical iPhone 13 Pro:
- readability of service silhouettes;
- emissive brightness on OLED;
- whether ambient NPC movement is visible but not distracting;
- 60 FPS/30 FPS frame pacing;
- heat and battery behaviour;
- interaction reachability in both landscape directions.

## Current design verdict

The Act 0 exterior route is structurally strong for a mobile tutorial and should remain compact.

The Temple now has a stronger hub identity, but it is still a production graybox. The correct next quality step is not to add more systems or more geometry. It is to replace the proxy art/animation/audio while preserving the spatial hierarchy, role silhouettes, progression-reactive hub state and performance budgets established here.
