# Shadow — Production Asset Brief (Checkpoint 01)

## Purpose

Replace the Quaternius development humanoid with the first real Shadowborn hero asset. The asset must read as **Shadow**, not as a recolored generic adventurer, from the actual iPhone gameplay camera.

Production path:

`res://assets/characters/shadow/shadow.glb`

## Identity

- human-form dark-fantasy silhouette;
- face remains unreadable/recessed rather than a visible generic human face;
- authored hood/cowl/head construction — no CapsuleMesh/SphereMesh overlays;
- restrained asymmetry and wear;
- early-condition clothing/armor feels poor, damaged and functional rather than heroic or ornate;
- weapon family must remain legible at phone scale;
- no permanent neon outline required to understand the character.

## Silhouette hierarchy

At gameplay distance the player should read, in order:

1. head/hood identity;
2. torso/shoulder mass;
3. weapon family;
4. cloth/back-layer shape;
5. only then belts, seams, rivets and small wear.

Microdetail that disappears at gameplay distance does not justify geometry or texture cost.

## Material families

Minimum authored separation:

- dark cloth / hood / drape;
- worn leather straps and reinforcement;
- dark iron/steel accents;
- shadow/void surface where lore requires it;
- optional muted bone/bronze detail only if it supports the starting design.

Each material must differ through roughness, surface response and construction logic, not only albedo color.

## Rig / deformation

- humanoid retarget-compatible skeleton;
- stable shoulders, elbows, wrists, hips, knees and neck;
- no collapsing armor or rubber plate deformation;
- right-hand weapon socket verified in combat poses;
- feet remain stable enough for planted contact in A1/A2;
- hood/cloth secondary motion may be baked or lightweight, but it never owns gameplay timing.

## Required animation support

The production model must support the semantic set in `docs/art/ANIMATION_REBUILD_BRIEF.md`.

Checkpoint 01 minimum:
- awakening / formation;
- recovery to stand;
- combat idle;
- A1;
- A2;
- hit;
- death;
- sword pickup / equip.

## LOD and mobile rules

- author LODs from gameplay-camera value, not portfolio close-up value;
- preserve silhouette and weapon shape before surface microdetail;
- reduce small straps, trim thickness and tiny geometry before head/weapon/body silhouette;
- material-slot count must be justified and measured on iPhone 13 Pro;
- no alpha-heavy cloth solution by default.

## Acceptance

PASS only when:

- `VisualAssetPolicy` reports production provenance;
- no vendor body or primitive identity overlay is visible;
- user can identify Shadow from a clean gameplay-camera screenshot without UI;
- A1/A2 silhouettes stay distinct at phone size;
- deformation holds in idle, A1, A2, hit and death;
- 30/60 FPS device captures remain stable after integration.

FAIL examples:

- looks like a generic medieval adventurer painted black;
- identity depends on glowing eyes only;
- hood clips through shoulders during A1/A2;
- weapon socket floats or twists;
- detail looks good only in a close-up render but collapses in gameplay.
