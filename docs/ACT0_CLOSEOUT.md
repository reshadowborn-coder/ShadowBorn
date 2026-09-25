# Act 0 closeout

Status: gameplay-complete against docs/ACT0_SCOPE.md.

Verified on main:
- exterior progression reaches the Temple and grants first Silver once;
- Temple hub contains Keeper, Smith, Merchant, Engraver placeholder and Forgotten Covenant interactions;
- all five combat-family choices are present and irreversible after confirmation;
- first forge/equip is committed through the save transaction before in-memory promotion;
- Catacomb Rooms 1–4 are ordered encounters;
- Room 5 first contact is a scripted solo-limit 1v2 and returns the player to the Temple;
- Keeper handoff unlocks the first story companion/team slot;
- Room 5 rematch is gated by that unlock and completes Act 0;
- save migration repairs invalid dependency chains and reconstructed encounter ledgers;
- Continue/New Game and one-time Shadow form selection are wired into startup;
- touch input ownership, modal overlays and landscape HUD anchoring are implemented.

Verification available in this repository:
- GitHub Actions imports/parses the Godot project headlessly;
- deterministic Act 0 state/combat tests run headlessly;
- the state suite covers all five weapon families through first forge/equip and the canonical resume matrix from exterior through `act0_complete`;
- latest verified gameplay/test head before this closeout documentation update: 1a809d4f53e2f3d31c8c21d5238606e7822a9475;
- workflow run 36105721141 completed successfully on Godot 4.4.1, including project parse/import, deterministic state tests, combat fixture parity, pre-Temple adapter tests and Act 0 scene smoke.

Not claimed by this closeout:
- final production art, audio or content polish;
- physical Android/iOS device QA;
- store packaging/release certification.

Act 1 remains out of scope. After this closeout, Act 0 should only receive changes for a demonstrated regression or an explicit scope change.
