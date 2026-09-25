# Shadowborn Character Generator foundation

This directory is the first executable layer of the Character Generator MVP.

Current scope:
- `CharacterRecipe v0.1` machine-readable contract.
- Three deterministic MVP fixtures: `BODY_NEUTRAL`, `BODY_TALL_LEAN`, `BODY_STOCKY`.
- Sword + shield visual loadout only.
- Versioned MVP registry for reference/compatibility preflight.
- Dependency-free Python validator and deterministic recipe hashes.

This layer deliberately does not own gameplay stats, Schools, rarity, combat balance, save progression, or dual-wield logic.

Production engine remains Godot 4.4.1. Blender/Godot import stages are not claimed complete by these tests. The next implementation stages are the clean-template Blender headless compiler, body solve, armor fit, geometry/pose QA, GLB export, Godot post-import, and physical iPhone 13 Pro validation.

IDs marked in the registry as `tooling_only_ids` are implementation identifiers introduced for the MVP build pipeline. They do not change gameplay canon. Body, weapon, armor-module, and material-family IDs mirror the Master Research Sheet.
