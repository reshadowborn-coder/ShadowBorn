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
- latest verified head before this closeout: f88f83a2b8fb6c7356f0b8496e74162e62f78ecf;
- workflow run 36069333590 completed successfully.

Not claimed by this closeout:
- final production art, audio or content polish;
- physical Android/iOS device QA;
- store packaging/release certification.

Act 1 remains out of scope. After this closeout, Act 0 should only receive changes for a demonstrated regression or an explicit scope change.
