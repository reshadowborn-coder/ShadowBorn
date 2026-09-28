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
1. asymmetric exposed rib window on one flank, placed just caudal to the scapular/shoulder mass so the rib structure reads anatomically rather than as random decoration;
2. readable shoulder/scapula bone break or exposed crest, using the scapular spine as the primary lateral bony landmark;
3. one large hide rupture bridging the shoulder-to-rib transition while preserving the forelimb chain and shoulder silhouette;
4. compact damaged tail and asymmetric ears;
5. only after those read, add smaller dirt/wound breakup.

Anatomy placement rule: damage may exaggerate or remove tissue, but it must still respect the recognizable canine shoulder → thorax → forelimb organization. Do not communicate decay by arbitrarily lengthening distal limb bones or scattering unattached rib/bone primitives.

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


## Fixed battle-camera deformation acceptance

Status: PRODUCTION DECISION / does not by itself raise visual readiness.

FACT:
- Blender 5.2 glTF export supports deformation-bones-only export, explicit skin influence counts, Armature Actions and resetting pose bones between actions.
- Godot mobile review should prefer opaque materials; alpha blending is slower and introduces sorting limitations.
- Canine/quadruped shoulder motion is not a rigid hinge at the thorax: the scapular/pectoral girdle contributes to forelimb excursion and load support. The Hound surface therefore needs a deformable shoulder-to-thorax transition rather than a visually welded upper leg.

RESEARCH CANDIDATE:
- Treat scapula/shoulder, thorax, tucked abdomen, pelvis and paw support as the five deformation zones that must survive the first production mesh pass.
- Paw-contact quality is judged from semantic attack phases and final camera; no invented centimeter tolerance is frozen before a real authored mesh and physical-device capture exist.

PRODUCTION DECISION:
- Every generated Hound candidate must produce exact BattleCamera captures with VFX/emission disabled in three diagnostic material modes: black silhouette, flat gray, neutral opaque PBR.
- The matrix currently gates idle and semantic Bite contact. Side diagnostic capture continues to cover idle, coil/windup, contact and recovery.
- Material review cannot rescue anatomy: silhouette and flat-gray passes must already show a low canine head, shoulder/chest mass, tucked abdomen, pelvis, short damaged tail and non-spider limb proportions.
- Neutral PBR may separate dry hide, bone and damaged tissue, but must stay opaque-first for Checkpoint 01.

PASS:
- Hound faces Shadow and Bite contact commits head/neck/chest toward the target from the production BattleCamera.
- Black silhouette reads as a waist-high undead canid rather than a generic wolf blob or insect/spider shape.
- Flat gray preserves skull/muzzle, shoulder/thorax, abdomen/pelvis and paw-chain readability without texture/emission help.
- Bite contact has no obvious limb telescoping, foreleg spider stretch, detached paw, floating body or instantaneous pose reset.
- Neutral PBR remains readable with emission off and does not depend on transparent gore/fur cards.
- The generated GLB still passes Godot 4.7.2 import, one-skeleton skinning, semantic action and four-influence gates.

FAIL:
- Any diagnostic pass needs eye glow, particles, blood transparency or dark lighting to hide weak anatomy.
- Shoulder or pelvis collapses into the torso at contact.
- Paw/limb deformation produces visible skating/stretch that breaks weight support.
- A green CI result is treated as visual acceptance without reviewing the generated captures.

Evidence links:
- Blender 5.2 glTF 2.0 exporter: https://docs.blender.org/manual/en/5.2/addons/scene_gltf2.html
- Blender 5.2 Rigify rig types: https://docs.blender.org/manual/en/5.2/addons/rigify/rig_types/index.html
- Godot 4.7 3D rendering limitations: https://docs.godotengine.org/en/4.7/tutorials/3d/3d_rendering_limitations.html
- Canine thoracic-limb kinematic model: DOI 10.1055/s-0042-1757591
- Comparative quadruped pectoral-girdle mechanics: DOI 10.1186/1742-9994-7-21
