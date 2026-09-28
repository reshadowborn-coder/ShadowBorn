#!/usr/bin/env python3
"""Shadowborn Shadow humanoid DCC rig + skin smoke.

Run inside Blender 5.2.2:
  blender -b --factory-startup --python tools/blender/shadow_rig_smoke.py -- --out-dir build/dcc_shadow

This is NOT shipping Shadow art. It proves a reproducible Basic Human Rigify
authoring path, deform-only GLB export, four-influence skinning and semantic
action round-trip before any final hood/body/armor mesh is authored.
"""

from __future__ import annotations

import argparse
import importlib
import json
import sys
from pathlib import Path

import bpy
from mathutils import Vector

EXPECTED_BLENDER = (5, 2, 2)
MIN_DEFORM_BONES = 20
MAX_DEFORM_BONES_CANDIDATE = 48
FOUR_INFLUENCE_BONES = (
    "DEF-spine.003",
    "DEF-spine.004",
    "DEF-shoulder.R",
    "DEF-upper_arm.R",
)
SMOKE_ACTIONS = ("SHD_IDLE_COMBAT_01", "SHD_A1_SWORD_01")


def _args() -> argparse.Namespace:
    argv = sys.argv
    argv = argv[argv.index("--") + 1:] if "--" in argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default="build/dcc_shadow")
    return parser.parse_args(argv)


def _require_blender_version() -> None:
    if tuple(bpy.app.version[:3]) != EXPECTED_BLENDER:
        raise RuntimeError(
            f"Expected Blender {EXPECTED_BLENDER}, got {tuple(bpy.app.version[:3])}"
        )


def _enable_rigify() -> None:
    result = bpy.ops.preferences.addon_enable(module="rigify")
    if "FINISHED" not in result:
        raise RuntimeError(f"Could not enable bundled Rigify: {result}")
    importlib.import_module("rigify")


def _clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.armatures, bpy.data.curves, bpy.data.actions):
        for block in list(datablocks):
            if block.users == 0:
                datablocks.remove(block)


def _create_basic_human_metarig() -> bpy.types.Object:
    armature = bpy.data.armatures.new("SHD_METARIG")
    metarig = bpy.data.objects.new("SHD_METARIG", armature)
    bpy.context.scene.collection.objects.link(metarig)
    bpy.context.view_layer.objects.active = metarig
    metarig.select_set(True)

    module = None
    errors: list[str] = []
    for module_name in (
        "rigify.metarigs.Basic.basic_human",
        "rigify.metarigs.basic_human",
    ):
        try:
            module = importlib.import_module(module_name)
            break
        except ModuleNotFoundError as exc:
            errors.append(str(exc))
    if module is None:
        raise RuntimeError(f"Could not import Rigify Basic Human metarig: {errors}")
    module.create(metarig)

    if len(metarig.data.bones) < 15:
        raise RuntimeError(f"Unexpectedly small Basic Human metarig: {len(metarig.data.bones)}")
    return metarig


def _generate_rig(metarig: bpy.types.Object) -> bpy.types.Object:
    bpy.context.view_layer.objects.active = metarig
    metarig.select_set(True)
    if metarig.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    result = bpy.ops.pose.rigify_generate()
    if "FINISHED" not in result:
        raise RuntimeError(f"Rigify generation failed: {result}")

    rig = getattr(metarig.data, "rigify_target_rig", None)
    if rig is None:
        candidates = [
            obj for obj in bpy.context.scene.objects
            if obj.type == "ARMATURE" and obj != metarig and "rig_id" in obj.data
        ]
        if len(candidates) != 1:
            raise RuntimeError(f"Could not resolve generated Shadow rig: {len(candidates)}")
        rig = candidates[0]

    deform = [b for b in rig.data.bones if b.use_deform]
    if not (MIN_DEFORM_BONES <= len(deform) <= MAX_DEFORM_BONES_CANDIDATE):
        raise RuntimeError(
            f"Shadow deform bone count outside candidate envelope: {len(deform)}"
        )
    return rig


def _tetra(center: Vector, radius: float):
    verts = [
        center + Vector(( radius,  radius,  radius)),
        center + Vector((-radius, -radius,  radius)),
        center + Vector((-radius,  radius, -radius)),
        center + Vector(( radius, -radius, -radius)),
    ]
    faces = [(0,1,2),(0,3,1),(0,2,3),(1,3,2)]
    return [tuple(v) for v in verts], faces


def _weighted_proxy(
    rig: bpy.types.Object,
    name: str,
    center: Vector,
    radius: float,
    weights: dict[str,float],
) -> bpy.types.Object:
    vertices, faces = _tetra(center, radius)
    mesh = bpy.data.meshes.new(name+"_Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)

    total = sum(weights.values())
    if total <= 0.0:
        raise RuntimeError(f"{name} weights sum to zero")
    for bone_name, value in weights.items():
        if bone_name not in rig.data.bones:
            raise RuntimeError(f"Missing deform bone for proxy: {bone_name}")
        group = obj.vertex_groups.new(name=bone_name)
        group.add(list(range(len(vertices))), float(value/total), "REPLACE")

    mod = obj.modifiers.new(name="ShadowArmature", type="ARMATURE")
    mod.object = rig
    mod.use_vertex_groups = True
    world = obj.matrix_world.copy()
    obj.parent = rig
    obj.matrix_parent_inverse = rig.matrix_world.inverted()
    obj.matrix_world = world
    obj["shadowborn_dcc_smoke_proxy"] = True
    return obj


def _create_skin_proxy(rig: bpy.types.Object) -> list[bpy.types.Object]:
    proxies: list[bpy.types.Object] = []
    deform = [b for b in rig.data.bones if b.use_deform]
    for index, bone in enumerate(deform):
        center = rig.matrix_world @ ((bone.head_local + bone.tail_local)*0.5)
        radius = max(0.009, min(0.024, bone.length*0.05))
        proxies.append(_weighted_proxy(
            rig,
            f"SHD_SKIN_PROXY_{index:02d}_{bone.name.replace('.','_')}",
            center,
            radius,
            {bone.name:1.0},
        ))

    available = [name for name in FOUR_INFLUENCE_BONES if name in rig.data.bones]
    if len(available) < 4:
        # Choose four torso/right-arm deform bones deterministically if Rigify
        # changed one of the preferred names.
        available = [
            b.name for b in deform
            if any(token in b.name.lower() for token in ("spine","shoulder","upper_arm"))
        ][:4]
    if len(available) != 4:
        raise RuntimeError(f"Could not resolve four-influence Shadow probe: {available}")

    center = Vector((0,0,0))
    for name in available:
        bone = rig.data.bones[name]
        center += rig.matrix_world @ ((bone.head_local+bone.tail_local)*0.5)
    center /= 4.0
    proxies.append(_weighted_proxy(
        rig,
        "SHD_SKIN_PROXY_4_INFLUENCE",
        center,
        0.035,
        {name:0.25 for name in available},
    ))
    return proxies


def _reset_pose(rig: bpy.types.Object) -> None:
    for pb in rig.pose.bones:
        pb.location = (0,0,0)
        pb.scale = (1,1,1)
        if pb.rotation_mode == "QUATERNION":
            pb.rotation_quaternion = (1,0,0,0)
        elif pb.rotation_mode == "AXIS_ANGLE":
            pb.rotation_axis_angle = (0,0,1,0)
        else:
            pb.rotation_euler = (0,0,0)


def _control(rig: bpy.types.Object, candidates: tuple[str,...]) -> bpy.types.PoseBone | None:
    for name in candidates:
        pb = rig.pose.bones.get(name)
        if pb is not None:
            return pb
    return None


def _create_smoke_actions(rig: bpy.types.Object) -> tuple[list[str],dict]:
    torso = _control(rig, ("torso","chest"))
    chest = _control(rig, ("chest","spine_fk.003","spine_fk.002"))
    head = _control(rig, ("head","neck"))
    upper_arm_r = _control(rig, ("upper_arm_fk.R","upper_arm_ik.R","upper_arm_parent.R"))
    forearm_r = _control(rig, ("forearm_fk.R","forearm_ik.R"))
    hand_r = _control(rig, ("hand_fk.R","hand_ik.R"))
    controls = {
        "torso": torso.name if torso else None,
        "chest": chest.name if chest else None,
        "head": head.name if head else None,
        "upper_arm_r": upper_arm_r.name if upper_arm_r else None,
        "forearm_r": forearm_r.name if forearm_r else None,
        "hand_r": hand_r.name if hand_r else None,
    }
    if torso is None or chest is None or head is None:
        raise RuntimeError(f"Missing essential Shadow controls: {controls}")

    bpy.context.scene.render.fps = 30
    rig.animation_data_create()
    created: list[str] = []

    def key_rot(pb: bpy.types.PoseBone, frame: int, xyz: tuple[float,float,float]) -> None:
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = xyz
        pb.keyframe_insert(data_path="rotation_euler",frame=frame,group="SHD_Smoke")

    _reset_pose(rig)
    idle = bpy.data.actions.new("SHD_IDLE_COMBAT_01")
    rig.animation_data.action = idle
    for frame, chest_x, head_x in ((1,0.015,-0.01),(16,0.030,-0.018),(31,0.015,-0.01)):
        key_rot(chest,frame,(chest_x,0,0))
        key_rot(head,frame,(head_x,0,0))
    created.append("SHD_IDLE_COMBAT_01")

    _reset_pose(rig)
    a1 = bpy.data.actions.new("SHD_A1_SWORD_01")
    rig.animation_data.action = a1
    for frame, torso_z, chest_z in ((1,0.0,0.0),(5,-0.14,-0.10),(9,0.20,0.18),(14,0.0,0.0)):
        key_rot(torso,frame,(0,0,torso_z))
        key_rot(chest,frame,(0,0,chest_z))
    if upper_arm_r is not None:
        for frame, angle in ((1,0.10),(5,-0.65),(9,0.75),(14,0.10)):
            key_rot(upper_arm_r,frame,(angle,0.0,-0.25))
    if forearm_r is not None:
        for frame, angle in ((1,-0.20),(5,-0.45),(9,-0.80),(14,-0.20)):
            key_rot(forearm_r,frame,(angle,0.0,0.0))
    if hand_r is not None:
        for frame, angle in ((1,0.0),(5,-0.20),(9,0.18),(14,0.0)):
            key_rot(hand_r,frame,(0.0,angle,0.0))
    created.append("SHD_A1_SWORD_01")

    rig.animation_data.action = None
    _reset_pose(rig)
    return created,controls


def _export(rig: bpy.types.Object, proxies:list[bpy.types.Object], out_dir:Path) -> Path:
    glb = out_dir/"shadow_game_rig_smoke.glb"
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    for obj in proxies:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
    kwargs = dict(
        filepath=str(glb),
        export_format="GLB",
        use_selection=True,
        export_skins=True,
        export_def_bones=True,
        export_leaf_bone=False,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_anim_single_armature=True,
        export_reset_pose_bones=True,
        export_frame_step=1,
        export_force_sampling=True,
        export_anim_slide_to_zero=True,
        export_yup=True,
        export_cameras=False,
        export_lights=False,
        export_extras=True,
    )
    if "export_all_influences" in props:
        kwargs["export_all_influences"] = False
    if "export_influence_nb" in props:
        kwargs["export_influence_nb"] = 4
    result = bpy.ops.export_scene.gltf(**kwargs)
    if "FINISHED" not in result or not glb.exists() or glb.stat().st_size <= 0:
        raise RuntimeError(f"Shadow GLB export failed: {result}")
    return glb


def _save(out_dir:Path) -> Path:
    path=out_dir/"shadow_game_rig_smoke.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(path))
    return path


def _roundtrip(glb:Path) -> dict:
    _clear_scene()
    result=bpy.ops.import_scene.gltf(
        filepath=str(glb),
        bone_heuristic="BLENDER",
        guess_original_bind_pose=True,
    )
    if "FINISHED" not in result:
        raise RuntimeError(f"Shadow GLB re-import failed: {result}")
    armatures=[o for o in bpy.context.scene.objects if o.type=="ARMATURE"]
    meshes=[o for o in bpy.context.scene.objects if o.type=="MESH"]
    if len(armatures)!=1:
        raise RuntimeError(f"Expected one Shadow armature, found {len(armatures)}")
    bones=sorted(b.name for b in armatures[0].data.bones)
    actions=sorted(a.name for a in bpy.data.actions)
    missing=sorted(set(SMOKE_ACTIONS)-set(actions))
    if missing:
        raise RuntimeError(f"Shadow GLB lost semantic actions: {missing}")

    max_positive=0
    weighted=0
    four_found=False
    for obj in meshes:
        for v in obj.data.vertices:
            positive=sum(1 for g in v.groups if g.weight>1e-6)
            max_positive=max(max_positive,positive)
            weighted += 1 if positive>0 else 0
            four_found = four_found or positive==4
    if max_positive>4 or not four_found or weighted==0:
        raise RuntimeError(
            f"Shadow skin contract failed: max={max_positive}, four={four_found}, weighted={weighted}"
        )
    return {
        "armature_count":len(armatures),
        "imported_bone_count":len(bones),
        "imported_bones":bones,
        "imported_mesh_count":len(meshes),
        "max_positive_influences_per_vertex":max_positive,
        "four_influence_vertex_found":four_found,
        "actions":actions,
    }


def main() -> None:
    args=_args()
    out_dir=Path(args.out_dir).resolve()
    out_dir.mkdir(parents=True,exist_ok=True)
    _require_blender_version()
    _enable_rigify()
    _clear_scene()

    metarig=_create_basic_human_metarig()
    metarig_bone_count=len(metarig.data.bones)
    rig=_generate_rig(metarig)
    deform=sorted(b.name for b in rig.data.bones if b.use_deform)
    proxies=_create_skin_proxy(rig)
    actions,controls=_create_smoke_actions(rig)
    source=_save(out_dir)
    glb=_export(rig,proxies,out_dir)
    roundtrip=_roundtrip(glb)

    report={
        "status":"pass",
        "purpose":"Shadow humanoid rig/skin/action smoke only; not shipping art",
        "blender_version":bpy.app.version_string,
        "authoring_metarig":"Rigify Basic Human",
        "metarig_bone_count":metarig_bone_count,
        "generated_deform_bone_count":len(deform),
        "generated_deform_bones":deform,
        "measured_controls":controls,
        "semantic_smoke_actions":actions,
        "semantic_smoke_actions_are_production_art":False,
        "source_blend":source.name,
        "smoke_glb":glb.name,
        "roundtrip":roundtrip,
        "shipping_path_written":False,
        "next_gate":"original faceless Shadow mesh candidate + hood/cowl + right-hand weapon socket + Godot humanoid retarget audit",
    }
    (out_dir/"shadow_rig_smoke_report.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
    print("SHADOWBORN_SHADOW_DCC_SMOKE_PASS")
    print(json.dumps(report,indent=2))


if __name__=="__main__":
    main()
