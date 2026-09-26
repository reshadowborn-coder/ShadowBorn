# Shadowborn — ACT 0 Visual Research v2

Status: ACTIVE RESEARCH / USER CANON OVERRIDES
Applied-research baseline reset by user: ~5/100
Scope: ACT 0 + Temple Hub vertical slice, iOS-first, iPhone 13 Pro, Godot 4.4.1 Mobile renderer.

## 0. Core finding

The current visual ceiling is asset-limited, not primarily shader-limited.

Current main contains only:
- assets/branding
- assets/vendor

There are no production assets/characters or assets/environment directories in main. The playable slice is therefore built from temporary Quaternius models plus procedural PlaneMesh/BoxMesh/TorusMesh/SphereMesh/CapsuleMesh primitives and procedural materials.

Consequence:
- shader polish can improve mood but cannot create convincing ruined architecture, garment silhouettes, undead anatomy, chipped stone edges, roots, rubble, grave markers, cloth folds or believable material breakup by itself;
- the next large visual gain must come from a production art pipeline, not more graybox decoration;
- Quaternius remains useful for temporary rig/animation coverage, but its current models must not define final visual quality.

This is the most important visual-research correction.

## 1. Canon conflict cleanup

Latest USER CANON wins over older Drive research candidates.

Rejected/overridden older research items:
- no player-controlled cemetery walk or joystick/movement tutorial;
- no open-world traversal;
- current opening is the user-approved fast seated/dead Shadow awakening beside a wall with rusty sword nearby;
- do not silently restore the older sealed-grave formation sequence;
- battle/location transitions are node/icon -> load encounter, not manual world walking.

Keep from older Drive material:
- environment dominates opening frame;
- Shadow is small/weak/non-heroic;
- wet stone path/value hierarchy;
- gradual Temple landmark reveal;
- Temple = weak warm safety against cold cemetery;
- atmosphere before exposition;
- no lore dump.

## 2. What current graphics are missing

### 2.1 Macro geometry
Current primitives do not provide:
- chipped/non-uniform silhouettes;
- believable collapsed masonry;
- layered grave construction;
- broken arches;
- roots interacting with stone;
- rubble size hierarchy;
- roof/tile breakup;
- Temple silhouette complexity.

Rule: silhouette geometry carries age/damage first; normal maps and decals support it second.

### 2.2 Material families
Act 0 needs a small coherent library rather than one procedural gray stone:
1. wet worn cobblestone;
2. rough medieval block wall;
3. darker damp crypt stone;
4. dirt/leaf/moss ground blend;
5. corroded iron;
6. dead dark wood;
7. red/brown aged roof tile for Temple;
8. rusty weapon steel;
9. Shadow cloth/body;
10. undead flesh/fur/bone.

Each family needs consistent texel scale and roughness logic.

### 2.3 Character art
Shadow:
- current dev humanoid is a rig carrier, not final visual identity;
- hood, face void, cloth silhouette and smoke need to be one authored design;
- temporary primitive hood/eyes cannot carry production close/medium shots.

Grave Hound:
- current wolf is also a rig carrier;
- wounds/ribs overlays help but do not change skull, shoulder, abdomen or gait silhouette enough;
- production target needs emaciated dog anatomy and undead material breakup.

### 2.4 Lighting/composition
Darkness currently substitutes for art detail too often.
Target hierarchy:
actor/action > route/interaction floor > landmark > atmosphere > microdetail.

Use one primary shadowed directional light; local lights mostly unshadowed. Dark values must retain separation on SDR/mobile. Warm light is sparse navigation/emotional contrast, not general scene tint.

## 3. Production material pipeline

### PBR baseline
For hero ground/walls use real PBR maps:
- albedo/diffuse;
- OpenGL normal;
- roughness;
- AO or packed ARM where useful;
- displacement only for source/reference or selective geometry generation, not mandatory runtime tessellation.

Do not ship 8K because source offers 8K. For iPhone camera distance, start with 1K/2K runtime candidates and measure. Preserve higher-resolution source outside runtime if needed.

### CC0 candidate library
Poly Haven assets are CC0 and explicitly allow commercial use:
https://polyhaven.com/license

Candidate ground:
- Cobblestone 01 — aged worn cobblestone, dirt-filled joints, moss, damp sheen:
  https://polyhaven.com/a/cobblestone_01
- Stone Pathway 02 — rough damp stone + scattered leaf debris:
  https://polyhaven.com/a/stone_pathway_02
- Cobblestone Floor 001 — uneven medieval cobblestone, mud/moss:
  https://polyhaven.com/a/cobblestone_floor_001
- Forest Leaves 02 — leaf/twig/moss ground reference:
  https://polyhaven.com/a/forest_leaves_02

Candidate wall:
- Medieval Blocks 05 — chipped weathered blocks, deep dirty joints:
  https://polyhaven.com/a/medieval_blocks_05
- Medieval Blocks 03 — cleaner broad medieval blocks for controlled contrast:
  https://polyhaven.com/a/medieval_blocks_03

Selection rule:
- one primary ground family + one transition family;
- one primary wall family + one darker/damper variant;
- avoid mixing many unrelated scanned materials in one small scene.

## 4. Godot 4.4 art pipeline

Use imported source scenes rather than procedural replacement wherever production geometry exists.

Recommended flow:
source glTF/GLB -> Advanced Import Settings -> mesh/material/animation cleanup -> inherited scene -> Shadowborn-specific material overrides/attachments -> gameplay wrapper.

Godot 4.4 supports Advanced Import Settings per object/material and automatic mesh LOD generation. Use this instead of manually duplicating distant meshes where it works.

Official references:
https://docs.godotengine.org/en/4.4/tutorials/assets_pipeline/importing_3d_scenes/index.html
https://docs.godotengine.org/en/4.4/tutorials/3d/mesh_lod.html
https://docs.godotengine.org/en/4.4/tutorials/assets_pipeline/retargeting_3d_skeletons.html

### Animation strategy
Do not keep final animation locked to current dev character.

For humanoid Shadow:
- adopt SkeletonProfileHumanoid/BoneMap;
- separate reusable AnimationLibrary from character mesh;
- retarget locomotion/combat clips to the final Shadow rig;
- dedicated production clips still required for awakening, sword pickup, A1, A2, hit, death and victory.

Quaternius Universal Animation Library can remain a legal temporary/source library for broad coverage; final timing/choreography is authored for Shadowborn.
Reference:
https://quaternius.com/packs/universalanimationlibrary.html
https://quaternius.com/packs/universalanimationlibrary2.html

For Hound:
- do not force humanoid assumptions;
- use its own quadruped skeleton/profile and dedicated clips.

## 5. Mobile rendering research

Current project already correctly selects:
- Godot Mobile renderer;
- Metal on iOS;
- ETC2/ASTC import;
- 2048 directional shadow map.

Keep:
- shared materials/shaders;
- MultiMesh for repeated leaves/rocks where spatial grouping remains sensible;
- one primary real-time shadow source;
- GPU particles;
- bounded transparency.

Godot explicitly warns that overlapping transparency is expensive on mobile and recommends minimizing shadow-casting lights. It also recommends reusing materials/shaders and using LOD/occlusion selectively.

Official references:
https://docs.godotengine.org/en/4.4/tutorials/performance/gpu_optimization.html
https://docs.godotengine.org/en/4.4/tutorials/3d/mesh_lod.html
https://docs.godotengine.org/en/4.4/tutorials/3d/resolution_scaling.html

Research candidate, not canon:
- test iOS MetalFX spatial/temporal scaling after real device profiling;
- test 0.85/1.0 3D scale rather than assuming native is optimal;
- do not enable purely because available.

## 6. Competitor/reference synthesis — principles only

RAID-like combat screenshots show why our current arena reads weak:
- actors occupy a stronger fraction of the frame;
- combat midground is comparatively clean;
- detailed background sits behind readable silhouettes;
- ground provides a stable value plane;
- UI/action silhouettes remain readable despite environment detail.

Watcher of Realms shows a denser environment can still work when:
- actors sit on clear value/platform zones;
- warm and cold local accents separate groups;
- environmental detail is pushed away from critical silhouettes.

Dark-fantasy cemetery references repeatedly benefit from:
- one dominant path/value band;
- layered foreground/midground/background;
- sparse cold mist between depth layers;
- one architectural landmark/light pool instead of uniform detail.

Transfer to Shadowborn:
- do not imitate specific assets/layouts;
- use the composition grammar only.

## 7. Camera-first art acceptance

Every art asset is judged in the final phone camera, not in an asset viewer.

For each new environment asset/material:
1. place in final awakening/battle camera;
2. downscale to phone-size capture;
3. grayscale check;
4. verify Shadow/Hound/path/Temple separation;
5. disable expensive VFX and confirm composition still works;
6. only then approve microdetail.

For character/weapon:
- front/3/4/back camera checks;
- contact and pickup frame checks;
- no transform correction accepted solely from local axes.

## 8. Next production research tasks

P0:
- define production folder structure and asset manifest/licensing;
- integrate one real PBR ground family and compare against procedural cobblestone;
- create/obtain one non-box ruined stone hero prop (grave/arch/wall chunk) and test camera read;
- replace temporary Shadow hood primitive with an authored mesh or higher-quality base-character path;
- research/prepare a dedicated quadruped Grave Hound replacement.

P1:
- Temple exterior kit: wall, buttress/pillar, arch, round window, broken roof/tile, stair, rubble;
- environment decal/mask strategy for wetness/moss/dirt;
- animation retarget prototype for final Shadow skeleton.

P2:
- device-profile LOD thresholds;
- MetalFX/resolution-scale A/B;
- texture size/ASTC block-size matrix.

## 9. Research progress accounting

Do not call the research database “80% done” merely because it contains many rows.

Use two metrics:
- Knowledge coverage: how many relevant questions have sourced answers.
- Production-transfer coverage: how much of that knowledge is converted into tested assets/scenes.

User baseline for practical research usefulness is now ~5/100.
Raise it only when research produces a concrete, testable production decision or integrated asset.
