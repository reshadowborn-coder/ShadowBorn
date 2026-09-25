# ShadowBorn

Mobile-first dark-fantasy RPG prototype in Godot.

## Current target

Act 0 is implemented end-to-end as a gameplay prototype: ruined cemetery/Temple exterior, Temple safe hub, Forgotten Covenant weapon choice, atomic first forge/equip, Catacombs Rooms 1-5, scripted solo-limit 1v2, first story team slot, Room 5 rematch, save/retry/resume and recovery checks.

The current hardening pass separates fixed progression rules from mutable layout/balance values and tests physical route containment as well as state integrity.

See:
- `docs/ACT0_SCOPE.md` for the completion contract;
- `docs/ACT0_ARCHITECTURE_CONTRACT.md` for fixed vs tunable structure;
- `docs/ACT0_CLOSEOUT.md` for the verified gameplay boundary.

Production art/audio, physical Android/iOS QA and store packaging remain outside gameplay-complete status.
