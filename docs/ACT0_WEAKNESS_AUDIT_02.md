# Act 0 weakness audit — pass 2

## High-risk gaps found and closed

- **Mobile-only project had no touch movement.** Added a dedicated touch movement layer while retaining keyboard input for desktop testing.
- **Weapon choice was mostly UI/data.** The forged family is now pushed into both 1v1 and Room 5 combat loadouts and receives a visible shadow-weapon proxy.
- **Room 5 first attempt could theoretically be won with enough damage.** The authored solo-limit now enforces non-lethal enemy floors until the scripted limit resolves.
- **Modal menus did not own movement focus.** Covenant and Settings now disable world navigation while open.
- **Corrupt/partial save combinations could create impossible states.** Migration now repairs dependency chains for Covenant, forge, Room 5 return/rematch and Act 0 completion.
- **Act 0 completion still allowed Room 5 trigger re-entry.** Completed progression now rejects further Catacomb encounters.
- **Repeated Room 5 target highlighting searched the whole scene tree.** The two Room 5 visuals are cached.

## Remaining risk

The current environment still has no confirmed Godot runtime/device execution. Static consistency is high, but parser/runtime, touch ergonomics, aspect-ratio behavior, frame pacing and actual Android/iOS performance still require a Godot/device test pass before calling Act 0 runtime-complete.
