# ACT 1 — SCOPE CONTRACT

Act 1 begins only after the completed Act 0 save contract.

## Act 1.1 — Sewer first descent

The first playable sewer descent is intentionally short and authored.

### Stage 1 — First chamber
- one Sewer Rat;
- normal 1v1 combat;
- teaches the new enemy family without a new system overload;
- victory unlocks the second chamber.

### Stage 2 — Tainted chamber
- one Poison Rat;
- normal 1v1 combat;
- introduces the poison identity/status;
- victory unlocks the third chamber.

### Stage 3 — Pack chamber
- exactly two Sewer Rats;
- authored solo-limit encounter;
- the player cannot permanently clear the pair on first contact;
- the encounter ends in the intended defeat/retreat beat;
- this is narrative gating, not a hidden DPS check.

## Temple return chain

After the Stage 3 solo-limit:
1. Act 1.1 sewer defeat is committed to save;
2. Shadow returns to the Temple;
3. Keeper briefs the player on the sewer threat;
4. the player is directed to the Smith;
5. after the Smith handoff the player is directed to the Temple Guard;
6. the Temple Guard offers membership in the Temple Watch Covenant;
7. joining that covenant completes the Act 1.1 onboarding chain and unlocks the next Act 1 progression gate.

## Covenant compatibility

Act 0 already persists covenant_joined for the Forgotten Covenant weapon-binding rite.
That field is not renamed or reinterpreted because doing so would corrupt existing saves.

Act 1 introduces a separate faction flag:
- temple_watch_covenant_joined

The Forgotten Covenant remains the Act 0 weapon pact.
The Temple Watch Covenant is the Act 1 factional oath offered by the Temple Guard.

## Fixed Act 1.1 rules

- sewer room order is fixed: Rat -> Poison Rat -> two Rats;
- first Stage 3 contact is always the authored solo-limit defeat;
- the Temple briefing cannot be skipped;
- the Smith handoff cannot be skipped;
- Temple Watch Covenant membership cannot be granted before the previous handoffs;
- every irreversible transition must commit atomically before presentation advances;
- save/resume must preserve every Act 1.1 handoff.

## Mutable presentation

These may change without changing the progression contract:
- room dimensions;
- sewer props/materials;
- enemy visual scale/pose;
- camera framing;
- exact combat numbers;
- dialogue wording;
- VFX/audio;
- checkpoint positions inside their authored regions.

Act 1.2+ is outside this contract.

## Mobile rendering policy for Act 1.1

The sewer remains authored as a small number of readable rooms. Do not convert its current low-count structural geometry to RenderingServer or a broad MultiMesh only to reduce node count.

For the current iPhone-first slice:
- keep the Godot Mobile renderer and Metal target;
- keep structural room silhouettes normally visible;
- use finite GeometryInstance3D visibility ranges for nonessential micro-detail such as tracks, scratches and small debris;
- use VISIBILITY_RANGE_FADE_DISABLED on Mobile instead of transparency-based fading;
- disable shadow casting on floor marks and liquid overlays that do not need to contribute to the directional shadow map;
- continue measuring node, mesh, collision, light and render-surface budgets in CI;
- revisit MultiMesh only when repeated same-mesh populations become large enough that reduced draw/setup cost outweighs its coarser per-node culling.


## Multi-enemy input pacing

Two-enemy combat accepts at most one player command per presentation window.

The lock belongs to MultiEnemyEncounter, not to a specific touch HUD. This prevents rapid touch input from consuming multiple authored rounds and keeps the rule identical for touch, future controller input and automated callers.

Target switching is locked during the same committed-action window. Terminal outcomes release the lock immediately; non-terminal rounds release it after the bounded presentation interval. Delayed unlocks are generation-guarded so a timer from an older encounter cannot unlock a newly started encounter.


## Guard covenant recovery

The persisted `guard_covenant` stage is a valid recovery state, not a dead end.

If a save already proves `temple_watch_covenant_joined=true` while `act1_1_complete=false`, the player must never be asked to join the Temple Watch a second time. Returning to the Temple Guard finalizes the missing Act 1.1 completion commit while preserving the already committed oath.

A failed finalization save must roll back only to the persisted Guard covenant recovery state, never to an earlier Smith handoff and never to an uncommitted completion.
