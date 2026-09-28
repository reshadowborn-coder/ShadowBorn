#!/usr/bin/env python3
"""Shadowborn Grave Hound DCC rig smoke test.

Run only inside Blender 5.2.2:
  blender -b --factory-startup --python tools/blender/grave_hound_rig_smoke.py -- --out-dir build/dcc_hound

This deliberately DOES NOT create the shipping grave_hound.glb. It proves that the
chosen Rigify Wolf -> deform-bone GLB -> Blender re-import route is reproducible.
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
}
MIN_METARIG_BONES = 24
MIN_DEFORM_BONES = 20


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


def _create_wolf_metarig() -> bpy.types.Object:
    armature = bpy.data.armatures.new("HND_METARIG")
    metarig = bpy.data.objects.new("HND_METARIG", armature)
    bpy.context.scene.collection.objects.link(metarig)
    bpy.context.view_layer.objects.active = metarig
    metarig.select_set(True)

    wolf_module = importlib.import_module("rigify.metarigs.Animals.wolf")
    wolf_module.create(metarig)

    rigify_types = {pb.rigify_type for pb in metarig.pose.bones if pb.rigify_type}
    missing = REQUIRED_RIGIFY_TYPES - rigify_types
    if missing:
        raise RuntimeError(f"Rigify Wolf metarig missing required rig types: {sorted(missing)}")
    if len(metarig.data.bones) < MIN_METARIG_BONES:
        raise RuntimeError(
            f"Unexpectedly small Wolf metarig: {len(metarig.data.bones)} bones"
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
    if len(deform_bones) < MIN_DEFORM_BONES:
        raise RuntimeError(
            f"Generated rig has too few deform bones: {len(deform_bones)}"
        )
    return rig


def _save_source(out_dir: Path) -> Path:
    blend_path = out_dir / "grave_hound_rig_smoke.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
    return blend_path


def _export_rig_only_glb(rig: bpy.types.Object, out_dir: Path) -> Path:
    glb_path = out_dir / "grave_hound_rig_smoke.glb"
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
    if len(bone_names) < MIN_DEFORM_BONES:
        raise RuntimeError(
            f"Round-trip GLB returned too few bones: {len(bone_names)}"
        )
    return {
        "imported_armature": armature.name,
        "imported_bone_count": len(bone_names),
        "sample_bones": bone_names[:16],
    }


def main() -> None:
    args = _args()
    out_dir = Path(args.out_dir).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    _require_blender_version()
    _enable_rigify()
    _clear_scene()

    metarig = _create_wolf_metarig()
    rigify_types = sorted({pb.rigify_type for pb in metarig.pose.bones if pb.rigify_type})
    metarig_bone_count = len(metarig.data.bones)

    rig = _generate_rig(metarig)
    deform_bones = sorted(b.name for b in rig.data.bones if b.use_deform)
    source_path = _save_source(out_dir)
    glb_path = _export_rig_only_glb(rig, out_dir)
    roundtrip = _roundtrip_check(glb_path)

    report = {
        "status": "pass",
        "purpose": "DCC rig/export smoke only; not shipping Grave Hound art",
        "blender_version": bpy.app.version_string,
        "rigify_source": "bundled Blender add-on",
        "metarig": "Wolf",
        "metarig_bone_count": metarig_bone_count,
        "required_rigify_types": sorted(REQUIRED_RIGIFY_TYPES),
        "observed_rigify_types": rigify_types,
        "generated_deform_bone_count": len(deform_bones),
        "generated_deform_bones": deform_bones,
        "source_blend": source_path.name,
        "smoke_glb": glb_path.name,
        "roundtrip": roundtrip,
        "shipping_path_written": False,
    }
    report_path = out_dir / "grave_hound_rig_smoke_report.json"
    report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print("SHADOWBORN_DCC_SMOKE_PASS")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
