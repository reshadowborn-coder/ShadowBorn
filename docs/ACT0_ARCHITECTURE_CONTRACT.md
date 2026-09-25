# Act 0 architecture contract

This document separates the gameplay structure that is fixed for Act 0 from values that are intentionally safe to tune while iterating on the prototype.

## Fixed structure

The following must not be changed indirectly from presentation, graybox, UI or balance code.

### Progression state machine

Authoritative source: `scripts/progression/act0_contract.gd`.

Canonical stage order:

`exterior -> temple_entry -> weapon_choice -> first_forge -> catacombs -> room5_return -> room5_rematch -> act0_complete`

Code outside `Act0Progression` / `Act0Orchestrator` must not invent new stage strings or skip transitions.

### Exterior authored chain

The fixed exterior chain is:

`Hound -> residual absorption -> Armless Skeleton -> Temple reveal -> Shield -> Faded Sigil -> Temple threshold`

Shield is not a valid encounter until Hound and Armless are cleared and the Temple reveal has been persisted.

Residual absorption, Temple reveal and Faded Sigil are one-shot persisted beats. They must converge forward during save recovery and must not replay as rewards.

### Covenant and first forge

The five fixed weapon-family IDs are:

- `sword_shield`
- `bow`
- `two_hand_axe`
- `dual_daggers`
- `mage_staff`

The choice is irreversible after a successful save.

The first forged item is canonical: matching family, `+0`, no bonus, equipped, and a deterministic item ID. A malformed forged item is rolled back by save migration rather than trusted.

### Catacomb membership

Room membership and encounter IDs are fixed in `Act0Contract.CATACOMB_ENCOUNTER_IDS`.

Rooms 1-4 remain authored 1v1 encounters. Room 5 remains the authored 1v2 story limit/rematch.

Enemy HP, DEF, damage and presentation can be tuned separately without changing room membership.

### Room 5 story chain

The fixed chain is:

`Room 5 solo limit -> Temple return -> Keeper story handoff -> story team slot -> Room 5 rematch -> act0_complete`

Completion cannot be committed before the story summon and rematch prerequisites are satisfied.

## Mutable structure

### Spatial tuning

Authoritative source: `scripts/world/act0_layout.gd`.

Trigger positions, checkpoint positions and trigger widths belong here. Graybox builders and triggers should reference these values instead of duplicating coordinates.

Changing a layout value is allowed only while the corresponding smoke test still proves that mandatory triggers span the traversable route and progression blockers cannot be bypassed.

### Combat tuning

Mutable values live in:

- `scripts/combat/shadow_loadout.gd`
- `scripts/progression/catacomb_encounter_plan.gd`
- presentation timing/animation code

Weapon coefficients, cooldowns, Veil values and Catacomb enemy stats may be tuned. The five family IDs, fixed room membership and story progression order must not change with balance edits.

Every family must continue to pass the Catacomb playability probe through Rooms 1-4 and the Room 5 companion rematch.

### Presentation

Proxy meshes, colors, animation distances, camera framing, story-toast wording and production art/audio are replaceable presentation layers as long as they do not become progression authorities.

## Save and transaction rules

Every irreversible transition must obey one of these patterns:

1. Persist the candidate state before promoting it in memory, as used by the first forge; or
2. Capture the previous runtime state, mutate, save, and roll back if saving fails.

A successful combat clear, Temple reveal, Faded Sigil, Temple crossing, Covenant choice, Catacomb entry, Room 5 solo limit, story summon and Act 0 completion must never exist only in memory.

`SaveManager` keeps the current save plus the previous valid generation. If the primary JSON is corrupt, loading falls back to the backup.

Migration repairs dependency chains instead of trusting contradictory late-state flags. Invalid checkpoint coordinates are relocated to a safe zone compatible with the repaired stage.

## Physical-route rules

Mandatory progression may not rely only on an Area3D that can be walked around.

- exterior encounter/reveal triggers span the playable route;
- the Temple has a physical blocker until Shield + Faded Sigil;
- Keeper and Forgotten Covenant handoffs span the Temple nave;
- Catacomb entry is physically blocked until the first forge;
- Catacomb room triggers span the corridor;
- Catacomb side walls are continuous between rooms.

## CI gates

The Act 0 workflow must stay green for:

- Godot project parse/import;
- deterministic progression/save tests;
- save-file corruption recovery;
- Chapter 0 combat fixture parity;
- pre-Temple playable adapter tests;
- all-family Catacomb playability probe;
- Act 0 scene/physical-route smoke tests.

A failed intermediate commit is not a verified Act 0 state. Only the latest green `main` is considered testable.

## Manual-device boundary

Automated CI does not replace physical-device QA. Manual testing is still required for touch feel, readability, camera comfort, 30/60 FPS presentation, device resume behavior, audio and final production art.
