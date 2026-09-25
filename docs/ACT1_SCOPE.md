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