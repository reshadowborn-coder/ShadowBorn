# Character Import Audit — Shadow / Grave Hound

## Purpose

Production character decisions are made from **Godot 4.7.2 imported runtime data plus the fixed side-on gameplay camera**, not from Blender face count or portfolio close-ups.

The audit exists to make two candidate pipelines directly comparable:

1. an original Shadowborn-authored base;
2. a neutral CC0 MakeHuman/MPFB body used only as an internal starting substrate.

Neither route is accepted because it is faster in the DCC. The winner is the route that reaches the Shadowborn identity, deformation and iPhone target with the least production risk.

## Runtime metrics collected

CharacterAssetAudit records after import:

- MeshInstance3D count;
- surface/material-slot count;
- imported vertex count;
- index and triangle count;
- unique material count;
- Skeleton3D count and maximum bone count;
- number of meshes actually bound to a skeleton;
- imported animation names;
- visible runtime height.

These values are diagnostics, not automatic art scores.

## Candidate A — original Shadowborn base

Advantages:
- full control of topology, silhouette and rig semantics;
- no risk of generic generator identity leaking into the final hero;
- easiest provenance story.

Risks:
- highest anatomy/retopology/weight-paint production cost;
- slower route to robust shoulders, hips, wrists and knees.

## Candidate B — MPFB / MakeHuman neutral substrate

Allowed role:
- internal anatomical/topology/rig starting substrate only.

Not allowed:
- recognizable stock MakeHuman face/body as final identity;
- third-party MPFB clothes/hair/body parts without their own provenance review;
- assuming generated geometry is mobile-ready merely because the source is CC0.

Why it is a candidate:
- MakeHuman core graphical assets and output are CC0 according to the official licensing documentation;
- MPFB works inside Blender and current 2.x documentation targets Blender 4.2+, with the 2.0.18 development notes explicitly carrying Blender 5.2 compatibility work.

Required Shadowborn transformation:
- custom body proportions;
- original hood/cowl/cloth construction;
- recessed faceless identity;
- original materials;
- production weapon socket;
- Shadowborn animation/deformation pass;
- runtime geometry/material reduction when the imported Godot audit shows it is needed.

## Acceptance experiment

For each candidate, export one stripped test character through:

Blender 5.2.2 LTS -> GLB -> Godot 4.7.2

Then compare:

1. provenance/license clarity;
2. Godot-imported vertices/surfaces/materials;
3. rest pose, scale and forward axis;
4. shoulder, elbow, wrist, hip, knee and neck deformation;
5. Wrist.R / weapon socket;
6. hood/cowl integration;
7. phone-size idle/A1/A2 silhouette;
8. time required to reach a non-generic Shadow identity;
9. iPhone 13 Pro 60 FPS impact after the real materials and animations are present.

No route is adopted until the experiment is captured in the research database.

## Guardrail

A lower triangle count does not win if the silhouette/deformation is worse. A more detailed mesh does not win if the extra cost is invisible in the shipping camera. Imported runtime evidence and visible value are both required.
