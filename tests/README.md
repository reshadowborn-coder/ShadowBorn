# Act 0 regression tests

Run from the repository root with a Godot 4 executable:

`godot4 --headless --path . --script res://tests/act0_state_tests.gd`

Run the Chapter 0 combat golden-fixture parity suite with:

`godot4 --headless --path . --script res://tests/ch00_combat_fixture_tests.gd`

The suites check the highest-risk deterministic rules that should not regress:
- new game starts at 0 Silver;
- Covenant/weapon choice order;
- first forge requires Silver and creates a +0/no-bonus item;
- Catacomb rooms cannot be skipped;
- Room 5 solo-limit and story summon are one-shot;
- Act 0 only completes after the Room 5 rematch;
- combat damage math remains deterministic;
- Chapter 0 Hound / Armless / Shield A1+A2 semantic traces remain aligned with the reviewed golden fixture corpus.

The combat fixture suite currently validates 44 decision rows across 9 reference branches. The CSV reference digest column is informational only; the test compares semantic state directly instead of treating that offline digest as authoritative runtime truth.

Physical-device execution is still required for animation/readability, 30/60 FPS presentation parity, input feel, and blind-player comprehension.

## CI

Every push to `main` downloads Godot 4.4.1 on Ubuntu, parses/imports the project headlessly, runs Act 0 state tests, runs the Chapter 0 combat fixture parity suite, and then runs the scene smoke suite. This catches parser, deterministic-state, and combat-semantic regressions before a mobile device pass.
