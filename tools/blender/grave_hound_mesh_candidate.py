#!/usr/bin/env python3
"""Build the first original Shadowborn Grave Hound mesh candidate.

This is a production-CANDIDATE generator, not final accepted art. It proves that
an original continuous-looking canine body can be authored on the measured
Basic Quadruped + custom jaw rig and exported as a skinned GLB with four
influences per vertex and semantic animation names.

Run inside Blender 5.2.2:
  blender -b --factory-startup --python tools/blender/grave_hound_mesh_candidate.py -- --out-dir build/dcc_hound
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

import bpy
from mathutils import Vector

from grave_hound_rig_smoke import (
    EXPECTED_BLENDER,
    MAX_GAME_DEFORM_BONES_CANDIDATE,
    SMOKE_ACTIONS,
    _clear_scene,
    _create_hound_metarig,
    _create_smoke_actions,
    _enable_rigify,
    _generate_rig,
    _require_blender_version,
    _reset_rig_pose,
)

BODY_NAME = "HND_BODY_CANDIDATE"
MIN_CANDIDATE_VERTICES = 500
MAX_CANDIDATE_VERTICES = 2200
MAX_INFLUENCES = 4


def _args() -> argparse.Namespace:
    argv = sys.argv
    argv = argv[argv.index("--") + 1 :] if "--" in argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", default="build/dcc_hound")
    return parser.parse_args(argv)


class MeshBuilder:
    def __init__(self) -> None:
        self.vertices: list[tuple[float, float, float]] = []
        self.faces: list[tuple[int, ...]] = []
        self.weight_pools: list[tuple[str, ...]] = []
        self.forced_weights: list[dict[str, float] | None] = []

    def _add_vertex(
        self,
        point: Vector,
        weight_pool: tuple[str, ...],
        forced: dict[str, float] | None = None,
    ) -> int:
        self.vertices.append(tuple(point))
        self.weight_pools.append(weight_pool)
        self.forced_weights.append(forced)
        return len(self.vertices) - 1

    def ellipsoid(
        self,
        center: Vector,
        radii: Vector,
        weight_pool: tuple[str, ...],
        segments: int = 12,
        rings: int = 7,
        forced: dict[str, float] | None = None,
    ) -> None:
        start = len(self.vertices)
        south = self._add_vertex(center + Vector((0, 0, -radii.z)), weight_pool, forced)
        ring_indices: list[list[int]] = []
        for r in range(1, rings):
            phi = -math.pi * 0.5 + math.pi * float(r) / float(rings)
            cp = math.cos(phi)
            sp = math.sin(phi)
            ring: list[int] = []
            for s in range(segments):
                theta = math.tau * float(s) / float(segments)
                p = center + Vector((
                    radii.x * cp * math.cos(theta),
                    radii.y * cp * math.sin(theta),
                    radii.z * sp,
                ))
                ring.append(self._add_vertex(p, weight_pool, forced))
            ring_indices.append(ring)
        north = self._add_vertex(center + Vector((0, 0, radii.z)), weight_pool, forced)

        first = ring_indices[0]
        for s in range(segments):
            self.faces.append((south, first[(s + 1) % segments], first[s]))
        for r in range(len(ring_indices) - 1):
            a = ring_indices[r]
            b = ring_indices[r + 1]
            for s in range(segments):
                n = (s + 1) % segments
                self.faces.append((a[s], a[n], b[n], b[s]))
        last = ring_indices[-1]
        for s in range(segments):
            self.faces.append((last[s], last[(s + 1) % segments], north))

    def body_loft(
        self,
        stations: list[tuple[Vector, float, float]],
        weight_pool: tuple[str, ...],
        segments: int = 14,
    ) -> None:
        """Create one connected torso skin through elliptical cross-section rings.

        Local quadruped convention is X=width, Y=head/tail axis, Z=height.
        Stations are ordered front(chest) -> rear(pelvis).
        """
        if len(stations) < 2:
            raise RuntimeError("Hound torso loft requires at least two stations")

        rings: list[list[int]] = []
        for center, half_width, half_height in stations:
            ring: list[int] = []
            for i in range(segments):
                angle = math.tau * float(i) / float(segments)
                point = center + Vector((
                    half_width * math.cos(angle),
                    0.0,
                    half_height * math.sin(angle),
                ))
                ring.append(self._add_vertex(point, weight_pool))
            rings.append(ring)

        for ring_index in range(len(rings) - 1):
            a = rings[ring_index]
            b = rings[ring_index + 1]
            for i in range(segments):
                n = (i + 1) % segments
                self.faces.append((a[i], a[n], b[n], b[i]))

        front_center = self._add_vertex(stations[0][0], weight_pool)
        rear_center = self._add_vertex(stations[-1][0], weight_pool)
        for i in range(segments):
            n = (i + 1) % segments
            self.faces.append((front_center, rings[0][i], rings[0][n]))
            self.faces.append((rear_center, rings[-1][n], rings[-1][i]))

    def tapered_segment(
        self,
        start: Vector,
        end: Vector,
        radius_start: float,
        radius_end: float,
        weight_pool: tuple[str, ...],
        segments: int = 8,
        forced: dict[str, float] | None = None,
    ) -> None:
        axis = end - start
        if axis.length < 1e-5:
            return
        forward = axis.normalized()
        reference = Vector((0, 0, 1))
        if abs(forward.dot(reference)) > 0.92:
            reference = Vector((1, 0, 0))
        side = forward.cross(reference).normalized()
        up = side.cross(forward).normalized()

        ring_a: list[int] = []
        ring_b: list[int] = []
        for i in range(segments):
            angle = math.tau * float(i) / float(segments)
            radial = side * math.cos(angle) + up * math.sin(angle)
            ring_a.append(self._add_vertex(start + radial * radius_start, weight_pool, forced))
            ring_b.append(self._add_vertex(end + radial * radius_end, weight_pool, forced))

        for i in range(segments):
            n = (i + 1) % segments
            self.faces.append((ring_a[i], ring_a[n], ring_b[n], ring_b[i]))

        center_a = self._add_vertex(start, weight_pool, forced)
        center_b = self._add_vertex(end, weight_pool, forced)
        for i in range(segments):
            n = (i + 1) % segments
            self.faces.append((center_a, ring_a[n], ring_a[i]))
            self.faces.append((center_b, ring_b[i], ring_b[n]))

    def triangle(
        self,
        a: Vector,
        b: Vector,
        c: Vector,
        weight_pool: tuple[str, ...],
        forced: dict[str, float] | None = None,
    ) -> None:
        ia = self._add_vertex(a, weight_pool, forced)
        ib = self._add_vertex(b, weight_pool, forced)
        ic = self._add_vertex(c, weight_pool, forced)
        self.faces.append((ia, ib, ic))


def _bone_center(rig: bpy.types.Object, name: str) -> Vector:
    bone = rig.data.bones.get(name)
    if bone is None:
        raise RuntimeError(f"Missing required Hound deform bone: {name}")
    return (bone.head_local + bone.tail_local) * 0.5


def _bone_head(rig: bpy.types.Object, name: str) -> Vector:
    bone = rig.data.bones.get(name)
    if bone is None:
        raise RuntimeError(f"Missing required Hound deform bone: {name}")
    return bone.head_local.copy()


def _bone_tail(rig: bpy.types.Object, name: str) -> Vector:
    bone = rig.data.bones.get(name)
    if bone is None:
        raise RuntimeError(f"Missing required Hound deform bone: {name}")
    return bone.tail_local.copy()


def _pool(*names: str) -> tuple[str, ...]:
    return tuple(names)


def _append_leg(builder: MeshBuilder, rig: bpy.types.Object, side: str, front: bool) -> None:
    if front:
        names = [
            f"DEF-front_thigh.{side}",
            f"DEF-front_thigh.{side}.001",
            f"DEF-front_shin.{side}",
            f"DEF-front_shin.{side}.001",
            f"DEF-front_foot.{side}",
            f"DEF-front_foot.{side}.001",
            f"DEF-front_toe.{side}",
        ]
        radii = [0.074, 0.069, 0.058, 0.050, 0.046, 0.040, 0.032]
    else:
        names = [
            f"DEF-thigh.{side}",
            f"DEF-thigh.{side}.001",
            f"DEF-shin.{side}",
            f"DEF-shin.{side}.001",
            f"DEF-foot.{side}",
            f"DEF-foot.{side}.001",
            f"DEF-toe.{side}",
        ]
        radii = [0.088, 0.080, 0.067, 0.057, 0.050, 0.043, 0.034]

    leg_pool = tuple(names)
    for index, bone_name in enumerate(names):
        start = _bone_head(rig, bone_name)
        end = _bone_tail(rig, bone_name)
        r0 = radii[index]
        r1 = max(r0 * 0.82, 0.030)
        builder.tapered_segment(start, end, r0, r1, leg_pool, segments=8)

    paw_center = _bone_tail(rig, names[-1])
    builder.ellipsoid(
        paw_center + Vector((0.0, -0.015, 0.012)),
        Vector((0.058, 0.084, 0.036)),
        leg_pool,
        segments=10,
        rings=6,
    )


def _build_candidate_geometry(rig: bpy.types.Object) -> MeshBuilder:
    b = MeshBuilder()

    pelvis_pool = _pool(
        "DEF-spine.004", "DEF-spine.005", "DEF-pelvis.L", "DEF-pelvis.R",
        "DEF-thigh.L", "DEF-thigh.R"
    )
    abdomen_pool = _pool("DEF-spine.005", "DEF-spine.006", "DEF-spine.007")
    chest_pool = _pool(
        "DEF-spine.007", "DEF-spine.008", "DEF-shoulder.L", "DEF-shoulder.R",
        "DEF-front_thigh.L", "DEF-front_thigh.R"
    )
    neck_pool = _pool("DEF-spine.008", "DEF-spine.009", "DEF-spine.010", "DEF-spine.011")
    head_pool = _pool("DEF-spine.010", "DEF-spine.011")
    jaw_pool = _pool("DEF-jaw", "DEF-spine.011")

    pelvis = (_bone_center(rig, "DEF-spine.004") + _bone_center(rig, "DEF-spine.005")) * 0.5
    abdomen = (_bone_center(rig, "DEF-spine.006") + _bone_center(rig, "DEF-spine.007")) * 0.5
    chest = (_bone_center(rig, "DEF-spine.007") + _bone_center(rig, "DEF-spine.008")) * 0.5
    shoulder_mid = (_bone_center(rig, "DEF-shoulder.L") + _bone_center(rig, "DEF-shoulder.R")) * 0.5

    # Camera-reviewed v3 torso: one connected loft instead of overlapping
    # chest/abdomen/pelvis ellipsoids. The topline stays continuous while the
    # underside tucks strongly through the abdomen.
    torso_pool = _pool(
        "DEF-spine.004", "DEF-spine.005", "DEF-spine.006", "DEF-spine.007", "DEF-spine.008",
        "DEF-pelvis.L", "DEF-pelvis.R",
        "DEF-shoulder.L", "DEF-shoulder.R",
        "DEF-thigh.L", "DEF-thigh.R",
        "DEF-front_thigh.L", "DEF-front_thigh.R",
        "DEF-spine", "DEF-spine.001",
    )

    chest_front = shoulder_mid + Vector((0.0, -0.080, 0.005))
    chest_rear = chest + Vector((0.0, 0.090, 0.000))
    abdomen_front = (chest + abdomen) * 0.5 + Vector((0.0, 0.015, 0.010))
    abdomen_rear = abdomen + Vector((0.0, 0.110, 0.025))
    loin = (abdomen + pelvis) * 0.5 + Vector((0.0, 0.030, 0.030))
    pelvis_front = pelvis + Vector((0.0, -0.110, 0.015))
    pelvis_rear = pelvis + Vector((0.0, 0.145, 0.010))

    tail_root = _bone_head(rig, "DEF-spine") + Vector((0.0, -0.015, 0.000))
    torso_stations = [
        (chest_front, 0.205, 0.245),
        (chest,       0.220, 0.255),
        (chest_rear,  0.205, 0.225),
        (abdomen_front,0.165, 0.170),
        (abdomen_rear, 0.142, 0.132),
        (loin,         0.158, 0.150),
        (pelvis_front, 0.182, 0.190),
        (pelvis_rear,  0.174, 0.182),
        (tail_root,    0.090, 0.082),
    ]
    # Basic Quadruped faces -Y, so ensure station order follows head -> tail.
    torso_stations.sort(key=lambda station: station[0].y)
    b.body_loft(torso_stations, torso_pool, segments=14)

    # Neck transitions into shoulders instead of floating as a thin tube.
    neck_start = _bone_center(rig, "DEF-spine.008")
    neck_mid = _bone_center(rig, "DEF-spine.009")
    neck_end = _bone_center(rig, "DEF-spine.010")
    b.tapered_segment(neck_start, neck_mid, 0.125, 0.110, neck_pool, segments=10)
    b.tapered_segment(neck_mid, neck_end, 0.110, 0.098, neck_pool, segments=10)

    head_bone = rig.data.bones["DEF-spine.011"]
    head_center = (head_bone.head_local + head_bone.tail_local) * 0.5
    head_forward = (head_bone.tail_local - head_bone.head_local).normalized()
    b.ellipsoid(head_center + Vector((0, 0, 0.006)), Vector((0.150, 0.178, 0.148)), head_pool)

    muzzle_root = head_center + head_forward * 0.085 + Vector((0, 0, -0.020))
    muzzle_tip = head_center + head_forward * 0.325 + Vector((0, 0, -0.040))
    b.tapered_segment(muzzle_root, muzzle_tip, 0.095, 0.055, head_pool, segments=10)

    # Separate lower-jaw volume guarantees semantic bite deformation around DEF-jaw.
    jaw_head = _bone_head(rig, "DEF-jaw")
    jaw_tail = _bone_tail(rig, "DEF-jaw")
    b.tapered_segment(
        jaw_head + Vector((0, 0, -0.035)),
        jaw_tail + Vector((0, 0, -0.035)),
        0.076,
        0.045,
        jaw_pool,
        segments=10,
        forced={"DEF-jaw": 0.86, "DEF-spine.011": 0.14},
    )

    # Ear silhouette: one intact, one torn/asymmetric. Both remain head-driven.
    ear_root_l = head_center + Vector((0.110, 0.010, 0.105))
    b.triangle(
        ear_root_l + Vector((0.0, -0.055, 0.0)),
        ear_root_l + Vector((0.010, 0.000, 0.255)),
        ear_root_l + Vector((-0.020, 0.095, 0.035)),
        head_pool,
        forced={"DEF-spine.011": 1.0},
    )
    # Right ear is deliberately torn/shorter and leans rearward.
    ear_root_r = head_center + Vector((-0.110, 0.025, 0.095))
    b.triangle(
        ear_root_r + Vector((0.0, -0.045, 0.0)),
        ear_root_r + Vector((-0.010, 0.035, 0.170)),
        ear_root_r + Vector((0.015, 0.115, 0.030)),
        head_pool,
        forced={"DEF-spine.011": 1.0},
    )

    _append_leg(b, rig, "L", front=True)
    _append_leg(b, rig, "R", front=True)
    _append_leg(b, rig, "L", front=False)
    _append_leg(b, rig, "R", front=False)

    # Damaged tail: shortened to three deform segments and given a slight corpse droop.
    tail_names = ("DEF-spine", "DEF-spine.001", "DEF-spine.002")
    tail_radii = (0.060, 0.046, 0.030)
    for i, name in enumerate(tail_names):
        drop_a = Vector((0, 0, -0.018 * float(i)))
        drop_b = Vector((0, 0, -0.018 * float(i + 1)))
        b.tapered_segment(
            _bone_head(rig, name) + drop_a,
            _bone_tail(rig, name) + drop_b,
            tail_radii[i],
            max(tail_radii[i] * 0.68, 0.016),
            tail_names,
            segments=8,
        )

    return b


def _point_segment_distance(point: Vector, start: Vector, end: Vector) -> float:
    axis = end - start
    length_sq = axis.length_squared
    if length_sq <= 1e-10:
        return (point - start).length
    t = max(0.0, min(1.0, (point - start).dot(axis) / length_sq))
    closest = start + axis * t
    return (point - closest).length


def _weights_for_vertex(
    rig: bpy.types.Object,
    point: Vector,
    pool: tuple[str, ...],
    forced: dict[str, float] | None,
) -> dict[str, float]:
    if forced is not None:
        total = sum(forced.values())
        if total <= 0.0:
            raise RuntimeError("Forced Hound weights must have positive sum")
        return {name: value / total for name, value in forced.items()}

    scored: list[tuple[float, str]] = []
    for bone_name in pool:
        bone = rig.data.bones.get(bone_name)
        if bone is None or not bone.use_deform:
            continue
        distance = _point_segment_distance(point, bone.head_local, bone.tail_local)
        scored.append((distance, bone_name))
    scored.sort(key=lambda item: item[0])
    chosen = scored[:MAX_INFLUENCES]
    if not chosen:
        raise RuntimeError("No deform bones available for Hound candidate vertex")

    raw: list[tuple[str, float]] = []
    for distance, bone_name in chosen:
        weight = 1.0 / max(distance, 0.018) ** 2.0
        raw.append((bone_name, weight))
    total = sum(weight for _, weight in raw)
    return {bone_name: weight / total for bone_name, weight in raw}


def _create_candidate_mesh(rig: bpy.types.Object) -> tuple[bpy.types.Object, dict]:
    builder = _build_candidate_geometry(rig)
    vertex_count = len(builder.vertices)
    if not (MIN_CANDIDATE_VERTICES <= vertex_count <= MAX_CANDIDATE_VERTICES):
        raise RuntimeError(
            f"Hound candidate vertex count outside envelope: {vertex_count} "
            f"(expected {MIN_CANDIDATE_VERTICES}..{MAX_CANDIDATE_VERTICES})"
        )

    mesh = bpy.data.meshes.new(BODY_NAME + "_Mesh")
    mesh.from_pydata(builder.vertices, [], builder.faces)
    mesh.update()
    # Organic candidate uses smooth vertex normals; silhouette remains geometry-driven.
    for polygon in mesh.polygons:
        polygon.use_smooth = True

    obj = bpy.data.objects.new(BODY_NAME, mesh)
    bpy.context.scene.collection.objects.link(obj)

    mat = bpy.data.materials.new("HND_DRY_GRAVE_HIDE")
    mat.diffuse_color = (0.075, 0.085, 0.068, 1.0)
    mat.metallic = 0.0
    mat.roughness = 0.88
    obj.data.materials.append(mat)

    groups: dict[str, bpy.types.VertexGroup] = {}
    max_influences = 0
    four_influence_vertices = 0

    for index, point_tuple in enumerate(builder.vertices):
        point = Vector(point_tuple)
        weights = _weights_for_vertex(
            rig,
            point,
            builder.weight_pools[index],
            builder.forced_weights[index],
        )
        max_influences = max(max_influences, len(weights))
        if len(weights) == 4:
            four_influence_vertices += 1
        for bone_name, weight in weights.items():
            group = groups.get(bone_name)
            if group is None:
                group = obj.vertex_groups.new(name=bone_name)
                groups[bone_name] = group
            group.add([index], float(weight), "REPLACE")

    if max_influences > MAX_INFLUENCES:
        raise RuntimeError(f"Hound candidate exceeded {MAX_INFLUENCES} influences")

    modifier = obj.modifiers.new(name="HoundArmature", type="ARMATURE")
    modifier.object = rig
    modifier.use_vertex_groups = True

    world_matrix = obj.matrix_world.copy()
    obj.parent = rig
    obj.matrix_parent_inverse = rig.matrix_world.inverted()
    obj.matrix_world = world_matrix

    obj["shadowborn_asset_tier"] = "production_candidate"
    obj["shadowborn_original_mesh"] = True
    obj["shadowborn_shipping_accepted"] = False

    return obj, {
        "vertex_count": vertex_count,
        "polygon_count": len(builder.faces),
        "max_influences_per_vertex": max_influences,
        "four_influence_vertex_count": four_influence_vertices,
        "material_slots": len(obj.data.materials),
    }


def _save_source(out_dir: Path) -> Path:
    path = out_dir / "grave_hound_mesh_candidate.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(path))
    return path


def _export_candidate(
    rig: bpy.types.Object,
    candidate: bpy.types.Object,
    out_dir: Path,
) -> Path:
    path = out_dir / "grave_hound_mesh_candidate.glb"
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    candidate.select_set(True)
    bpy.context.view_layer.objects.active = rig

    kwargs = dict(
        filepath=str(path),
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
    props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
    if "export_all_influences" in props:
        kwargs["export_all_influences"] = False
    if "export_influence_nb" in props:
        kwargs["export_influence_nb"] = 4

    result = bpy.ops.export_scene.gltf(**kwargs)
    if "FINISHED" not in result or not path.exists() or path.stat().st_size <= 0:
        raise RuntimeError(f"Hound candidate GLB export failed: {result}")
    return path


def _roundtrip_candidate(path: Path) -> dict:
    _clear_scene()
    result = bpy.ops.import_scene.gltf(
        filepath=str(path),
        bone_heuristic="BLENDER",
        guess_original_bind_pose=True,
    )
    if "FINISHED" not in result:
        raise RuntimeError(f"Hound candidate GLB re-import failed: {result}")

    armatures = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if len(armatures) != 1:
        raise RuntimeError(f"Candidate expected one armature, found {len(armatures)}")

    candidate = next((obj for obj in meshes if obj.name.startswith(BODY_NAME)), None)
    if candidate is None:
        raise RuntimeError(f"Round-trip lost {BODY_NAME}")

    max_positive = 0
    weighted_vertices = 0
    for vertex in candidate.data.vertices:
        positive = sum(1 for g in vertex.groups if g.weight > 1e-6)
        max_positive = max(max_positive, positive)
        if positive > 0:
            weighted_vertices += 1

    if max_positive > MAX_INFLUENCES:
        raise RuntimeError(
            f"Round-trip candidate exceeds {MAX_INFLUENCES} influences: {max_positive}"
        )
    if weighted_vertices != len(candidate.data.vertices):
        raise RuntimeError(
            f"Round-trip candidate has unweighted vertices: "
            f"{weighted_vertices}/{len(candidate.data.vertices)}"
        )

    actions = sorted(action.name for action in bpy.data.actions)
    missing = sorted(set(SMOKE_ACTIONS) - set(actions))
    if missing:
        raise RuntimeError(f"Round-trip candidate lost semantic actions: {missing}")

    return {
        "armature_count": len(armatures),
        "mesh_count": len(meshes),
        "candidate_vertex_count": len(candidate.data.vertices),
        "candidate_polygon_count": len(candidate.data.polygons),
        "weighted_vertex_count": weighted_vertices,
        "max_positive_influences_per_vertex": max_positive,
        "animation_actions": actions,
    }


def main() -> None:
    args = _args()
    out_dir = Path(args.out_dir).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    _require_blender_version()
    _enable_rigify()
    _clear_scene()

    metarig = _create_hound_metarig()
    rig = _generate_rig(metarig)
    actions = _create_smoke_actions(rig)
    candidate, candidate_stats = _create_candidate_mesh(rig)

    _reset_rig_pose(rig)
    source_path = _save_source(out_dir)
    glb_path = _export_candidate(rig, candidate, out_dir)
    roundtrip = _roundtrip_candidate(glb_path)

    report = {
        "status": "pass",
        "purpose": "fourth camera-reviewed original skinned Grave Hound candidate with connected torso/tail silhouette; not final user-accepted art",
        "blender_version": bpy.app.version_string,
        "rig_route": "Basic Quadruped + Shadowborn custom jaw",
        "candidate_mesh": BODY_NAME,
        "candidate_revision": 4,
        "torso_topology": "single_connected_elliptical_loft_surface",
        "candidate_stats_before_export": candidate_stats,
        "roundtrip": roundtrip,
        "semantic_actions": actions,
        "semantic_actions_are_final_art": False,
        "anatomy_policy": {
            "deep_shoulder_chest": True,
            "tucked_abdomen": True,
            "stronger_hindquarter_mass": True,
            "compact_forelimb_read": True,
            "short_damaged_tail": True,
            "asymmetric_ears": True,
        },
        "source_blend": source_path.name,
        "candidate_glb": glb_path.name,
        "shipping_path_written": False,
        "next_gate": "Godot 4.7.2 import + fixed side-camera capture + deform review of idle/bite before any shipping-path promotion",
    }
    report_path = out_dir / "grave_hound_mesh_candidate_report.json"
    report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print("SHADOWBORN_HOUND_MESH_CANDIDATE_PASS")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
