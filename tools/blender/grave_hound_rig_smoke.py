#!/usr/bin/env python3
"""Shadowborn Grave Hound DCC rig smoke test.

Run only inside Blender 5.2.2:
  blender -b --factory-startup --python tools/blender/grave_hound_rig_smoke.py -- --out-dir build/dcc_hound

This deliberately DOES NOT create the shipping grave_hound.glb. It proves that the
chosen Basic Quadruped + custom jaw authoring rig can generate a compact deform-only
GLB and survive a Blender glTF round trip. Final runtime acceptance still requires
Godot 4.7.2 import, animation, gameplay-camera review and iPhone 13 Pro profiling.
"""

from __future__ import annotations

import argparse
import importlib
import json
import sys
from pathlib import Path

import bpy

EXPECTED_BLENDER = (5, 2, 2)
REQUIRED_RIGIFY_TYPES = {
    "limbs.front_paw",
    "limbs.rear_paw",
    "spines.basic_tail",
    "spines.super_head",
}
MIN_METARIG_BONES = 30
MIN_GAME_DEFORM_BONES = 32
MAX_GAME_DEFORM_BONES_CANDIDATE = 48
CUSTOM_JAW_NAME = "jaw"


def _args() -> argparse.Namespace:
    argv = sys.argv
    argv = argv[argv.index("--") + 1 :] if "--" in argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default="build/dcc_hound")
    return parser.parse_args(argv)


def _require_blender_version() -> None:
    version = tuple(bpy.app.version[:3])
    if version != EXPECTED_BLENDER:
        raise RuntimeError(
            f"Expected Blender {EXPECTED_BLENDER}, got {version}. "
            "Shadowborn DCC baseline is intentionally pinned."
        )


def _enable_rigify() -> None:
    # Importing Rigify is not enough: the add-on must be registered so Armature
    # receives rigify_colors / rigify_target_rig and the generation operators.
    try:
        result = bpy.ops.preferences.addon_enable(module="rigify")
    except Exception as exc:
        raise RuntimeError(f"Could not enable bundled Rigify add-on: {exc}") from exc
    if "FINISHED" not in result:
        raise RuntimeError(f"Could not enable bundled Rigify add-on: {result}")
    importlib.import_module("rigify")
    if not hasattr(bpy.types.Armature, "rigify_colors"):
        raise RuntimeError("Rigify module loaded but Armature properties were not registered")


def _clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.armatures, bpy.data.curves):
        for block in list(datablocks):
            if block.users == 0:
                datablocks.remove(block)


def _new_metarig_object(name: str) -> bpy.types.Object:
    armature = bpy.data.armatures.new(name)
    metarig = bpy.data.objects.new(name, armature)
    bpy.context.scene.collection.objects.link(metarig)
    bpy.context.view_layer.objects.active = metarig
    metarig.select_set(True)
    return metarig


def _add_hound_jaw(metarig: bpy.types.Object) -> None:
    """Add one simple controllable/deforming jaw below the Basic Quadruped head."""
    bpy.context.view_layer.objects.active = metarig
    if metarig.mode != "EDIT":
        bpy.ops.object.mode_set(mode="EDIT")

    armature = metarig.data
    if "spine.011" not in armature.edit_bones:
        raise RuntimeError("Basic Quadruped head tip spine.011 not found")

    jaw = armature.edit_bones.new(CUSTOM_JAW_NAME)
    # Basic Quadruped faces -Y. Keep the jaw under/forward of the terminal head bone.
    jaw.head = (0.0, -0.505, 0.865)
    jaw.tail = (0.0, -0.705, 0.815)
    jaw.roll = 0.0
    jaw.use_connect = False
    jaw.parent = armature.edit_bones["spine.011"]

    bpy.ops.object.mode_set(mode="OBJECT")
    pose_jaw = metarig.pose.bones[CUSTOM_JAW_NAME]
    pose_jaw.rigify_type = "basic.super_copy"
    pose_jaw.rotation_mode = "QUATERNION"
    pose_jaw.rigify_parameters.make_control = True
    pose_jaw.rigify_parameters.make_widget = False
    pose_jaw.rigify_parameters.make_deform = True


def _disable_nonessential_deform(metarig: bpy.types.Object) -> None:
    # Basic Quadruped ships breast volume helpers that are useful for general rigs
    # but not required for the phone-size Grave Hound silhouette.
    for bone_name in ("breast.L", "breast.R"):
        pose_bone = metarig.pose.bones.get(bone_name)
        if pose_bone is None:
            continue
        if pose_bone.rigify_type == "basic.super_copy":
            pose_bone.rigify_parameters.make_control = False
            pose_bone.rigify_parameters.make_widget = False
            pose_bone.rigify_parameters.make_deform = False


def _create_hound_metarig() -> bpy.types.Object:
    metarig = _new_metarig_object("HND_METARIG")
    module = importlib.import_module("rigify.metarigs.Basic.basic_quadruped")
    module.create(metarig)
    _add_hound_jaw(metarig)
    _disable_nonessential_deform(metarig)

    rigify_types = {pb.rigify_type for pb in metarig.pose.bones if pb.rigify_type}
    missing = REQUIRED_RIGIFY_TYPES - rigify_types
    if missing:
        raise RuntimeError(
            f"Basic Quadruped metarig missing required rig types: {sorted(missing)}"
        )
    if len(metarig.data.bones) < MIN_METARIG_BONES:
        raise RuntimeError(
            f"Unexpectedly small Basic Quadruped metarig: {len(metarig.data.bones)} bones"
        )
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
            raise RuntimeError(
                f"Could not resolve generated Rigify target rig; candidates={len(candidates)}"
            )
        rig = candidates[0]

    deform_bones = [bone for bone in rig.data.bones if bone.use_deform]
    deform_names = {bone.name for bone in deform_bones}
    if len(deform_bones) < MIN_GAME_DEFORM_BONES:
        raise RuntimeError(
            f"Generated game rig has too few deform bones: {len(deform_bones)}"
        )
    if len(deform_bones) > MAX_GAME_DEFORM_BONES_CANDIDATE:
        raise RuntimeError(
            "Generated game-rig candidate exceeds the temporary Shadowborn bone budget: "
            f"{len(deform_bones)} > {MAX_GAME_DEFORM_BONES_CANDIDATE}. "
            "This budget is a project candidate pending iPhone profiling, not a platform limit."
        )
    if "DEF-jaw" not in deform_names:
        raise RuntimeError("Generated game rig is missing DEF-jaw")
    return rig


def _save_source(out_dir: Path) -> Path:
    blend_path = out_dir / "grave_hound_game_rig_smoke.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
    return blend_path


def _export_rig_only_glb(rig: bpy.types.Object, out_dir: Path) -> Path:
    glb_path = out_dir / "grave_hound_game_rig_smoke.glb"
    bpy.ops.object.select_all(action="DESELECT")
    rig.hide_set(False)
    rig.hide_viewport = False
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig

    result = bpy.ops.export_scene.gltf(
        filepath=str(glb_path),
        export_format="GLB",
        use_selection=True,
        export_skins=True,
        export_def_bones=True,
        export_leaf_bone=False,
        export_animations=False,
        export_yup=True,
        export_cameras=False,
        export_lights=False,
        export_extras=True,
    )
    if "FINISHED" not in result or not glb_path.exists() or glb_path.stat().st_size <= 0:
        raise RuntimeError(f"glTF export failed: {result}")
    return glb_path


def _roundtrip_check(glb_path: Path) -> dict:
    _clear_scene()
    result = bpy.ops.import_scene.gltf(
        filepath=str(glb_path),
        bone_heuristic="BLENDER",
        guess_original_bind_pose=True,
    )
    if "FINISHED" not in result:
        raise RuntimeError(f"glTF re-import failed: {result}")

    armatures = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    if len(armatures) != 1:
        raise RuntimeError(f"Expected one imported armature, found {len(armatures)}")

    armature = armatures[0]
    bone_names = sorted(b.name for b in armature.data.bones)
    if not (MIN_GAME_DEFORM_BONES <= len(bone_names) <= MAX_GAME_DEFORM_BONES_CANDIDATE):
        raise RuntimeError(
            "Round-trip GLB bone count left the candidate game-rig envelope: "
            f"{len(bone_names)}"
        )
    if "DEF-jaw" not in bone_names:
        raise RuntimeError("Round-trip GLB lost DEF-jaw")
    return {
        "imported_armature": armature.name,
        "imported_bone_count": len(bone_names),
        "imported_bones": bone_names,
    }


def main() -> None:
    args = _args()
    out_dir = Path(args.out_dir).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    _require_blender_version()
    _enable_rigify()
    _clear_scene()

    metarig = _create_hound_metarig()
    rigify_types = sorted({pb.rigify_type for pb in metarig.pose.bones if pb.rigify_type})
    metarig_bones = sorted(b.name for b in metarig.data.bones)

    rig = _generate_rig(metarig)
    deform_bones = sorted(b.name for b in rig.data.bones if b.use_deform)
    source_path = _save_source(out_dir)
    glb_path = _export_rig_only_glb(rig, out_dir)
    roundtrip = _roundtrip_check(glb_path)

    report = {
        "status": "pass",
        "purpose": "DCC game-rig/export smoke only; not shipping Grave Hound art",
        "blender_version": bpy.app.version_string,
        "rigify_source": "bundled Blender add-on",
        "authoring_metarig": "Basic Quadruped + Shadowborn custom jaw",
        "metarig_bone_count": len(metarig_bones),
        "metarig_bones": metarig_bones,
        "required_rigify_types": sorted(REQUIRED_RIGIFY_TYPES),
        "observed_rigify_types": rigify_types,
        "disabled_runtime_deform_helpers": ["breast.L", "breast.R"],
        "generated_deform_bone_count": len(deform_bones),
        "candidate_max_deform_bones": MAX_GAME_DEFORM_BONES_CANDIDATE,
        "candidate_budget_is_platform_limit": False,
        "generated_deform_bones": deform_bones,
        "source_blend": source_path.name,
        "smoke_glb": glb_path.name,
        "roundtrip": roundtrip,
        "shipping_path_written": False,
        "next_gate": "Godot 4.7.2 generated-GLB import + authored mesh/weights + semantic clips + iPhone 13 Pro profile",
    }
    report_path = out_dir / "grave_hound_rig_smoke_report.json"
    report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print("SHADOWBORN_DCC_SMOKE_PASS")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
