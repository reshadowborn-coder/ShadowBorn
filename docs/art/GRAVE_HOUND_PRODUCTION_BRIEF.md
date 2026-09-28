# Grave Hound — Production Asset Brief (Checkpoint 01)

## Purpose

Replace the Quaternius wolf plus procedural wounds/ribs with a purpose-built undead canid that reads immediately as the first Shadowborn enemy.

Production path:

`res://assets/characters/grave_hound/grave_hound.glb`

## Identity

The Grave Hound is not “a wolf tinted green”. It should read as:

- waist-high predatory canid;
- underfed/emaciated body;
- damaged undead anatomy integrated into sculpt and materials;
- low, tense threat silhouette;
- believable canine weight distribution;
- restrained supernatural cues.

Eyes may support identity, but the creature must still read as undead with emissive eyes disabled.

## Anatomy / silhouette

Prioritize:

1. skull/head profile;
2. neck/shoulder line;
3. chest/rib compression;
4. fore/hind leg stance;
5. spine and pelvis;
6. tail as secondary read.

Exposed ribs, wounds and bone must be modeled/sculpted as part of the creature, not attached sphere/cylinder decorations.

## Material families

- dry damaged hide/fur;
- exposed bone;
- dark wound/tissue;
- dirt/mud;
- optional restrained eye emission.

Avoid glossy gore. The creature should feel old, starved and grave-soiled rather than freshly bloody.

### Undead identity macro-pass

Checkpoint 01 identity must survive with eye emission disabled and without transparent gore cards.

Priority forms in the shipping side camera:
1. asymmetric exposed rib window on one flank;
2. readable shoulder/scapula bone break or exposed crest;
3. one large hide rupture around the rib/shoulder transition;
4. compact damaged tail and asymmetric ears;
5. only after those read, add smaller dirt/wound breakup.

Material rule for the first Hound GLB:
- keep **three opaque gameplay families** as the target baseline: dry hide, bone, dark tissue/grave-soil;
- do not use semi-transparent blood/fur to rescue weak anatomy;
- if a later torn-edge card is unavoidable, prefer alpha scissor over alpha blending and validate it on the mobile renderer;
- tangent-space normal maps follow glTF +Y convention and remain secondary to silhouette;
- Godot imported mesh/material/vertex statistics are authoritative because glTF may split vertices at normals/UV/material boundaries.

The current generated candidate is a topology/rig/animation research asset, not accepted shipping art. Smooth shading may improve surface continuity but never counts as a silhouette fix.

## Rig

Minimum functional chain:

- root/pelvis;
- spine segments;
- neck/head;
- jaw;
- left/right foreleg chains;
- left/right hind-leg chains;
- paw contact bones or stable end effectors;
- tail chain if retained.

The rig must support readable real canine gait timing before undead stylization.

### Rig authoring route

- Blender 5.2 Rigify **Basic Quadruped** is the preferred production rig-authoring baseline.
- A measured Blender 5.2.2 smoke showed Basic Quadruped at 34 metarig / 46 generated deform bones versus Wolf at 190 / 197 before project-specific pruning.
- Add a Shadowborn jaw as a `basic.super_copy` deform/control bone; disable nonessential breast deform helpers for the Hound candidate rig.
- Use the quadruped rig as an authoring/control framework only; it is not a visible asset source.
- Final Grave Hound mesh, proportions, wounds, skull, materials and animation poses remain original Shadowborn content.
- Export deformation bones/required hierarchy to GLB; do not ship Rigify control widgets or editor-only UI objects.
- Current compact game-rig candidate must stay at or below 48 deform bones until iPhone 13 Pro profiling justifies a change; this is a Shadowborn project budget candidate, not an iOS hard limit.
- Validate the exported Godot Skeleton3D bone hierarchy and all paw contacts before animation polish.

## DCC / GLB handoff contract

- author/export baseline: Blender 5.2.2 LTS → glTF 2.0 / GLB → Godot 4.7.2;
- tangent-space normal maps use the OpenGL (+Y) convention and are treated as non-color data in the DCC;
- imported Godot mesh statistics are authoritative for runtime geometry/material budgets; Blender face count alone is not accepted;
- verify rest pose, body scale and canine visual forward axis in Godot before reviewing idle/bite/rush;
- export idle, locomotion, bite, rush/rend, hit and death as isolated actions; reset pose bones between actions when not all channels are keyed;
- only generate/use LODs when fixed side-camera captures show no loss of jaw/paw/shoulder readability and profiling shows a benefit.

## Required animation support

Checkpoint 01 minimum:
- low idle;
- locomotion;
- bite;
- rush/rend;
- hit reaction;
- death.

The body may be asymmetric/undead, but paw order and support phases must remain believable.

## Mobile/readability rules

- no dense rib cage that turns into shimmer/noise at phone scale;
- preserve head/jaw/shoulder silhouette before small exposed-bone detail;
- emission never dominates the silhouette;
- alpha fur cards only if measured and justified;
- LOD reduction must keep paw/leg readability in combat.

## Acceptance

PASS only when:

- `VisualAssetPolicy` reports production provenance;
- creature is recognizable with emissive eyes disabled;
- no Quaternius wolf mesh or primitive wound/rib dressing is player-visible;
- idle, bite and rush remain distinct in silhouette;
- no obvious paw skate in gameplay camera;
- semantic contact in Bite/Rend can be calibrated to the authored animation;
- 30/60 FPS captures remain stable on iPhone 13 Pro.

FAIL examples:

- healthy wolf with zombie accessories;
- miniature horse/dog gait;
- all threat communicated by red eyes;
- paws slide while body moves;
- generic Attack reused for both Bite and Rush.
