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
