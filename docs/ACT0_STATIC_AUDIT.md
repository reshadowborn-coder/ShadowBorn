# Act 0 static audit — pass 1

Scope checked against ACT0_SCOPE.md.

Confirmed in source:
- exterior encounter ledger and first-Silver first-clear gate;
- Temple entry, Keeper/Covenant/Smith/Catacomb progression hooks;
- five weapon-family selection UI;
- first forge state transaction and +0/no-bonus item;
- Rooms 1–4 progression;
- Room 5 first-contact solo-limit state;
- Temple return, deterministic story companion and team slot;
- two-target Room 5 rematch layer;
- act0_complete transition;
- save schema v2 and resume-state fields.

Corrections made during audit:
- first forge now explicitly requires Covenant membership and first_forge stage;
- companion assist no longer fires after Shadow has already killed the final Room 5 enemy.

Not runtime-certified:
Godot runtime/device execution has not yet been performed in this environment. Gameplay-complete must remain distinct from runtime-verified. Remaining closeout work is scene/static consistency, save fault cases, and an actual Godot run when runtime is available.
