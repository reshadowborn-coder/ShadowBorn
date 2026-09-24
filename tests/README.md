# Act 0 regression tests

Run from the repository root with a Godot 4 executable:

`godot4 --headless --path . --script res://tests/act0_state_tests.gd`

The suite checks the highest-risk deterministic rules that should not regress:
- new game starts at 0 Silver;
- Covenant/weapon choice order;
- first forge requires Silver and creates a +0/no-bonus item;
- Catacomb rooms cannot be skipped;
- Room 5 solo-limit and story summon are one-shot;
- Act 0 only completes after the Room 5 rematch;
- combat damage math remains deterministic.

Runtime execution is still required on a machine/device with Godot 4 installed.
