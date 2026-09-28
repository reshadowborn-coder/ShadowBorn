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
RIBS_NAME = "HND_EXPOSED_RIBS_CANDIDATE"
WOUND_NAME = "HND_THORAX_WOUND_CANDIDATE"
EYE_SOCKET_NAME = "HND_MISSING_EYE_SOCKET_CANDIDATE"
JAW_BONE_NAME = "HND_EXPOSED_JAW_BONE_CANDIDATE"
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

    def tube_chain(
        self,
        points: list[Vector],
        radii: list[float],
        weight_pool: tuple[str, ...],
        segments: int = 8,
        cap_ends: bool = True,
        forced: dict[str, float] | None = None,
    ) -> None:
        """Create one connected limb/neck tube through all joints.

        Rings are oriented from the local path tangent, so bends stay connected
        without the visible cap seams produced by per-bone cylinders.
        """
        if len(points) < 2 or len(points) != len(radii):
            raise RuntimeError("tube_chain requires matching point/radius arrays")

        rings: list[list[int]] = []
        for index, point in enumerate(points):
            if index == 0:
                tangent = (points[1] - points[0]).normalized()
            elif index == len(points) - 1:
                tangent = (points[-1] - points[-2]).normalized()
            else:
                tangent = (points[index + 1] - points[index - 1]).normalized()

            reference = Vector((0, 0, 1))
            if abs(tangent.dot(reference)) > 0.92:
                reference = Vector((1, 0, 0))
            side = tangent.cross(reference).normalized()
            up = side.cross(tangent).normalized()

            ring: list[int] = []
            for i in range(segments):
                angle = math.tau * float(i) / float(segments)
                radial = side * math.cos(angle) + up * math.sin(angle)
                ring.append(
                    self._add_vertex(
                        point + radial * radii[index],
                        weight_pool,
                        forced,
                    )
                )
            rings.append(ring)

        for ring_index in range(len(rings) - 1):
            a = rings[ring_index]
            b = rings[ring_index + 1]
            for i in range(segments):
                n = (i + 1) % segments
                self.faces.append((a[i], a[n], b[n], b[i]))

        if cap_ends:
            first_center = self._add_vertex(points[0], weight_pool, forced)
            last_center = self._add_vertex(points[-1], weight_pool, forced)
            for i in range(segments):
                n = (i + 1) % segments
                self.faces.append((first_center, rings[0][n], rings[0][i]))
                self.faces.append((last_center, rings[-1][i], rings[-1][n]))

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
        joint_radii = [0.098, 0.086, 0.066, 0.054, 0.046, 0.039, 0.032, 0.024]
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
        joint_radii = [0.118, 0.102, 0.076, 0.062, 0.051, 0.043, 0.034, 0.025]

    leg_pool = tuple(names)
    points = [_bone_head(rig, names[0])]
    points.extend(_bone_tail(rig, bone_name) for bone_name in names)
    builder.tube_chain(
        points,
        joint_radii,
        leg_pool,
        segments=9,
        cap_ends=True,
    )

    paw_center = points[-1] + Vector((0.0, -0.018, 0.010))
    builder.ellipsoid(
        paw_center,
        Vector((0.052, 0.078, 0.031)),
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
    )

    chest_front = shoulder_mid + Vector((0.0, -0.080, 0.005))
    chest_rear = chest + Vector((0.0, 0.090, 0.000))
    abdomen_front = (chest + abdomen) * 0.5 + Vector((0.0, 0.015, 0.010))
    abdomen_rear = abdomen + Vector((0.0, 0.110, 0.025))
    loin = (abdomen + pelvis) * 0.5 + Vector((0.0, 0.030, 0.030))
    pelvis_front = pelvis + Vector((0.0, -0.110, 0.015))
    pelvis_rear = pelvis + Vector((0.0, 0.145, 0.010))

    torso_stations = [
        (chest_front, 0.218, 0.255),
        (chest,       0.232, 0.272),
        (chest_rear,  0.210, 0.232),
        (abdomen_front,0.162, 0.160),
        (abdomen_rear, 0.140, 0.126),
        (loin,         0.160, 0.152),
        (pelvis_front, 0.198, 0.212),
        (pelvis_rear,  0.184, 0.198),
    ]
    # Basic Quadruped faces -Y, so ensure station order follows head -> tail.
    torso_stations.sort(key=lambda station: station[0].y)
    b.body_loft(torso_stations, torso_pool, segments=14)

    # One connected neck tube avoids stacked-cylinder seams under the skull.
    neck_start = _bone_center(rig, "DEF-spine.008")
    neck_mid = _bone_center(rig, "DEF-spine.009")
    neck_end = _bone_center(rig, "DEF-spine.010")
    b.tube_chain(
        [neck_start, neck_mid, neck_end],
        [0.122, 0.108, 0.094],
        neck_pool,
        segments=10,
        cap_ends=True,
    )

    head_bone = rig.data.bones["DEF-spine.011"]
    head_center = (head_bone.head_local + head_bone.tail_local) * 0.5
    head_forward = (head_bone.tail_local - head_bone.head_local).normalized()

    # Continuous canine skull/muzzle profile. The old ellipsoid + cylinder read
    # as a toy head in fixed-camera captures, so the visible upper head is now
    # one lofted surface from occiput to nose.
    skull_rear = head_center - head_forward * 0.085 + Vector((0.0, 0.0, 0.008))
    skull_mid = head_center + head_forward * 0.010 + Vector((0.0, 0.0, 0.006))
    cheek = head_center + head_forward * 0.085 + Vector((0.0, 0.0, -0.004))
    muzzle_mid = head_center + head_forward * 0.185 + Vector((0.0, 0.0, -0.024))
    nose = head_center + head_forward * 0.285 + Vector((0.0, 0.0, -0.038))
    head_stations = [
        (skull_rear, 0.108, 0.100),
        (skull_mid,  0.132, 0.114),
        (cheek,      0.106, 0.088),
        (muzzle_mid, 0.068, 0.055),
        (nose,       0.043, 0.038),
    ]
    head_stations.sort(key=lambda station: station[0].y)
    b.body_loft(head_stations, head_pool, segments=12)

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

    # Side-camera readable ears: narrow tapered organic wedges rather than
    # single triangles, so at least one ear survives the fixed side view.
    ear_pool = _pool("DEF-spine.011")
    ear_l_start = head_center + Vector((0.066, 0.008, 0.084))
    ear_l_end = ear_l_start + Vector((0.000, 0.058, 0.105))
    b.tapered_segment(
        ear_l_start,
        ear_l_end,
        0.034,
        0.008,
        ear_pool,
        segments=6,
        forced={"DEF-spine.011": 1.0},
    )
    # Torn ear is shorter and leans rearward.
    ear_r_start = head_center + Vector((-0.064, 0.022, 0.075))
    ear_r_end = ear_r_start + Vector((0.000, 0.070, 0.068))
    b.tapered_segment(
        ear_r_start,
        ear_r_end,
        0.029,
        0.007,
        ear_pool,
        segments=6,
        forced={"DEF-spine.011": 1.0},
    )

    _append_leg(b, rig, "L", front=True)
    _append_leg(b, rig, "R", front=True)
    _append_leg(b, rig, "L", front=False)
    _append_leg(b, rig, "R", front=False)

    # Damaged tail stump: tail-chain deformation repeatedly pulled the prototype
    # away from the pelvis in fixed-camera captures. For this corpse design the
    # retained visible tail is a short broken stump anchored to the pelvis/loin.
    tail_start = pelvis_rear.copy()
    tail_tip = tail_start + Vector((0.0, 0.135, -0.028))
    b.tapered_segment(
        tail_start,
        tail_tip,
        0.050,
        0.018,
        _pool("DEF-spine.004", "DEF-spine.005"),
        segments=8,
        forced={"DEF-spine.004": 0.72, "DEF-spine.005": 0.28},
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


def _create_ribs_candidate(rig: bpy.types.Object) -> tuple[bpy.types.Object, dict]:
    """Create three broad exposed rib arcs on the camera-near thorax.

    They are deliberately sparse: enough to read as undead anatomy at phone size
    without turning the rib cage into high-frequency shimmer.
    """
    builder = MeshBuilder()
    chest = (_bone_center(rig, "DEF-spine.007") + _bone_center(rig, "DEF-spine.008")) * 0.5
    rib_weights = {"DEF-spine.007": 0.54, "DEF-spine.008": 0.46}
    rib_pool = _pool("DEF-spine.007", "DEF-spine.008")

    # Camera sits on +X for the diagnostic side view, so expose the +X thorax.
    # Use one connected curved tube per rib; lateral-view anatomy should read as
    # springlike thoracic arcs, not vertical rods.
    for index, y_offset in enumerate((-0.095, 0.000, 0.092)):
        root = chest + Vector((0.205, y_offset, 0.135 - 0.006 * index))
        mid = chest + Vector((0.242, y_offset + 0.028, 0.012 - 0.014 * index))
        end = chest + Vector((0.202, y_offset + 0.072, -0.110 + 0.004 * index))
        builder.tube_chain(
            [root, mid, end],
            [0.015, 0.013, 0.008 if index != 2 else 0.006],
            rib_pool,
            segments=7,
            cap_ends=True,
            forced=rib_weights,
        )

    mesh = bpy.data.meshes.new(RIBS_NAME + "_Mesh")
    mesh.from_pydata(builder.vertices, [], builder.faces)
    mesh.update()
    for polygon in mesh.polygons:
        polygon.use_smooth = True

    obj = bpy.data.objects.new(RIBS_NAME, mesh)
    bpy.context.scene.collection.objects.link(obj)

    bone_mat = bpy.data.materials.new("HND_EXPOSED_OLD_BONE")
    bone_mat.diffuse_color = (0.34, 0.31, 0.235, 1.0)
    bone_mat.metallic = 0.0
    bone_mat.roughness = 0.94
    obj.data.materials.append(bone_mat)

    groups: dict[str, bpy.types.VertexGroup] = {}
    max_influences = 0
    for vertex_index, point_tuple in enumerate(builder.vertices):
        weights = _weights_for_vertex(
            rig,
            Vector(point_tuple),
            builder.weight_pools[vertex_index],
            builder.forced_weights[vertex_index],
        )
        max_influences = max(max_influences, len(weights))
        for bone_name, weight in weights.items():
            group = groups.get(bone_name)
            if group is None:
                group = obj.vertex_groups.new(name=bone_name)
                groups[bone_name] = group
            group.add([vertex_index], float(weight), "REPLACE")

    modifier = obj.modifiers.new(name="HoundRibArmature", type="ARMATURE")
    modifier.object = rig
    modifier.use_vertex_groups = True

    world_matrix = obj.matrix_world.copy()
    obj.parent = rig
    obj.matrix_parent_inverse = rig.matrix_world.inverted()
    obj.matrix_world = world_matrix

    obj["shadowborn_asset_tier"] = "production_candidate"
    obj["shadowborn_anatomy_layer"] = "exposed_ribs"
    obj["shadowborn_original_mesh"] = True
    obj["shadowborn_shipping_accepted"] = False

    return obj, {
        "vertex_count": len(builder.vertices),
        "polygon_count": len(builder.faces),
        "max_influences_per_vertex": max_influences,
        "rib_arc_count": 3,
        "material_slots": len(obj.data.materials),
    }


def _create_wound_candidate(rig: bpy.types.Object) -> tuple[bpy.types.Object, dict]:
    """Create a dark irregular thorax cavity under the exposed ribs.

    This is a side-readable wound layer, not a literal boolean hole. At phone
    scale it prevents the ribs from reading as decorative bars glued to intact skin.
    """
    builder = MeshBuilder()
    chest = (_bone_center(rig, "DEF-spine.007") + _bone_center(rig, "DEF-spine.008")) * 0.5
    forced = {"DEF-spine.007": 0.56, "DEF-spine.008": 0.44}
    pool = _pool("DEF-spine.007", "DEF-spine.008")

    center = chest + Vector((0.218, 0.010, 0.000))
    ring_offsets = [
        Vector((0.0, -0.105,  0.090)),
        Vector((0.0, -0.132,  0.022)),
        Vector((0.0, -0.104, -0.082)),
        Vector((0.0, -0.030, -0.112)),
        Vector((0.0,  0.070, -0.100)),
        Vector((0.0,  0.122, -0.035)),
        Vector((0.0,  0.115,  0.065)),
        Vector((0.0,  0.040,  0.112)),
        Vector((0.0, -0.045,  0.110)),
    ]
    points = [center + offset for offset in ring_offsets]
    for i in range(len(points)):
        builder.triangle(
            center,
            points[i],
            points[(i + 1) % len(points)],
            pool,
            forced=forced,
        )

    mesh = bpy.data.meshes.new(WOUND_NAME + "_Mesh")
    mesh.from_pydata(builder.vertices, [], builder.faces)
    mesh.update()

    obj = bpy.data.objects.new(WOUND_NAME, mesh)
    bpy.context.scene.collection.objects.link(obj)

    mat = bpy.data.materials.new("HND_DRY_THORAX_CAVITY")
    mat.diffuse_color = (0.052, 0.012, 0.010, 1.0)
    mat.metallic = 0.0
    mat.roughness = 0.84
    obj.data.materials.append(mat)

    groups: dict[str, bpy.types.VertexGroup] = {}
    max_influences = 0
    for vertex_index, point_tuple in enumerate(builder.vertices):
        weights = _weights_for_vertex(
            rig,
            Vector(point_tuple),
            builder.weight_pools[vertex_index],
            builder.forced_weights[vertex_index],
        )
        max_influences = max(max_influences, len(weights))
        for bone_name, weight in weights.items():
            group = groups.get(bone_name)
            if group is None:
                group = obj.vertex_groups.new(name=bone_name)
                groups[bone_name] = group
            group.add([vertex_index], float(weight), "REPLACE")

    modifier = obj.modifiers.new(name="HoundWoundArmature", type="ARMATURE")
    modifier.object = rig
    modifier.use_vertex_groups = True

    world_matrix = obj.matrix_world.copy()
    obj.parent = rig
    obj.matrix_parent_inverse = rig.matrix_world.inverted()
    obj.matrix_world = world_matrix

    obj["shadowborn_asset_tier"] = "production_candidate"
    obj["shadowborn_anatomy_layer"] = "thorax_wound_cavity"
    obj["shadowborn_original_mesh"] = True
    obj["shadowborn_shipping_accepted"] = False

    return obj, {
        "vertex_count": len(builder.vertices),
        "polygon_count": len(builder.faces),
        "max_influences_per_vertex": max_influences,
        "material_slots": len(obj.data.materials),
    }


def _create_head_damage_layers(rig: bpy.types.Object) -> tuple[list[bpy.types.Object], dict]:
    """Create one missing-eye socket and one restrained exposed jaw-bone strip.

    These are opaque, skinned, side-readable identity layers. They intentionally
    avoid glow, transparency and oversized mutation so the creature remains an
    ordinary cemetery dog ruined by death.
    """
    head_bone = rig.data.bones.get("DEF-spine.011")
    jaw_bone = rig.data.bones.get("DEF-jaw")
    if head_bone is None or jaw_bone is None:
        raise RuntimeError("Hound head-damage layers require DEF-spine.011 and DEF-jaw")

    head_center = (head_bone.head_local + head_bone.tail_local) * 0.5

    # Production battle camera resolves the +X side; put the missing eye there.
    eye_builder = MeshBuilder()
    eye_center = head_center + Vector((0.120, -0.035, 0.030))
    eye_builder.ellipsoid(
        eye_center,
        Vector((0.018, 0.038, 0.032)),
        _pool("DEF-spine.011"),
        segments=10,
        rings=6,
        forced={"DEF-spine.011": 1.0},
    )

    eye_mesh = bpy.data.meshes.new(EYE_SOCKET_NAME + "_Mesh")
    eye_mesh.from_pydata(eye_builder.vertices, [], eye_builder.faces)
    eye_mesh.update()
    for polygon in eye_mesh.polygons:
        polygon.use_smooth = True
    eye_obj = bpy.data.objects.new(EYE_SOCKET_NAME, eye_mesh)
    bpy.context.scene.collection.objects.link(eye_obj)

    eye_mat = bpy.data.materials.new("HND_EMPTY_CLOUDED_SOCKET")
    eye_mat.diffuse_color = (0.025, 0.028, 0.024, 1.0)
    eye_mat.metallic = 0.0
    eye_mat.roughness = 0.90
    eye_obj.data.materials.append(eye_mat)

    eye_group = eye_obj.vertex_groups.new(name="DEF-spine.011")
    eye_group.add(list(range(len(eye_builder.vertices))), 1.0, "REPLACE")
    eye_modifier = eye_obj.modifiers.new(name="HoundEyeSocketArmature", type="ARMATURE")
    eye_modifier.object = rig
    eye_modifier.use_vertex_groups = True
    eye_world = eye_obj.matrix_world.copy()
    eye_obj.parent = rig
    eye_obj.matrix_parent_inverse = rig.matrix_world.inverted()
    eye_obj.matrix_world = eye_world

    jaw_builder = MeshBuilder()
    jaw_head = jaw_bone.head_local.copy()
    jaw_tail = jaw_bone.tail_local.copy()
    jaw_start = jaw_head.lerp(jaw_tail, 0.30) + Vector((0.055, 0.0, -0.010))
    jaw_end = jaw_head.lerp(jaw_tail, 0.86) + Vector((0.052, 0.0, -0.012))
    jaw_builder.tapered_segment(
        jaw_start,
        jaw_end,
        0.017,
        0.010,
        _pool("DEF-jaw", "DEF-spine.011"),
        segments=7,
        forced={"DEF-jaw": 0.90, "DEF-spine.011": 0.10},
    )

    jaw_mesh = bpy.data.meshes.new(JAW_BONE_NAME + "_Mesh")
    jaw_mesh.from_pydata(jaw_builder.vertices, [], jaw_builder.faces)
    jaw_mesh.update()
    for polygon in jaw_mesh.polygons:
        polygon.use_smooth = True
    jaw_obj = bpy.data.objects.new(JAW_BONE_NAME, jaw_mesh)
    bpy.context.scene.collection.objects.link(jaw_obj)

    jaw_mat = bpy.data.materials.new("HND_EXPOSED_JAW_BONE")
    jaw_mat.diffuse_color = (0.36, 0.32, 0.235, 1.0)
    jaw_mat.metallic = 0.0
    jaw_mat.roughness = 0.95
    jaw_obj.data.materials.append(jaw_mat)

    for bone_name, weight in (("DEF-jaw", 0.90), ("DEF-spine.011", 0.10)):
        group = jaw_obj.vertex_groups.new(name=bone_name)
        group.add(list(range(len(jaw_builder.vertices))), weight, "REPLACE")
    jaw_modifier = jaw_obj.modifiers.new(name="HoundJawDamageArmature", type="ARMATURE")
    jaw_modifier.object = rig
    jaw_modifier.use_vertex_groups = True
    jaw_world = jaw_obj.matrix_world.copy()
    jaw_obj.parent = rig
    jaw_obj.matrix_parent_inverse = rig.matrix_world.inverted()
    jaw_obj.matrix_world = jaw_world

    for obj, layer in ((eye_obj, "missing_eye_socket"), (jaw_obj, "damaged_jaw_bone")):
        obj["shadowborn_asset_tier"] = "production_candidate"
        obj["shadowborn_anatomy_layer"] = layer
        obj["shadowborn_original_mesh"] = True
        obj["shadowborn_shipping_accepted"] = False

    return [eye_obj, jaw_obj], {
        "missing_eye_socket_vertices": len(eye_builder.vertices),
        "missing_eye_socket_polygons": len(eye_builder.faces),
        "exposed_jaw_bone_vertices": len(jaw_builder.vertices),
        "exposed_jaw_bone_polygons": len(jaw_builder.faces),
        "material_slots": 2,
    }


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

    dry_mat = bpy.data.materials.new("HND_DRY_GRAVE_HIDE")
    dry_mat.diffuse_color = (0.17, 0.19, 0.16, 1.0)
    dry_mat.metallic = 0.0
    dry_mat.roughness = 0.88
    obj.data.materials.append(dry_mat)

    wet_mat = bpy.data.materials.new("HND_WET_DEAD_FUR")
    wet_mat.diffuse_color = (0.070, 0.082, 0.068, 1.0)
    wet_mat.metallic = 0.0
    wet_mat.roughness = 0.38
    obj.data.materials.append(wet_mat)

    # Broad opaque wet-fur zones only. Avoid noisy micro-patches and alpha hair
    # cards at the first mobile gameplay distance.
    wet_face_count = 0
    for polygon in mesh.polygons:
        center = Vector((0.0, 0.0, 0.0))
        for vertex_index in polygon.vertices:
            center += Vector(mesh.vertices[vertex_index].co)
        center /= float(len(polygon.vertices))
        shoulder_patch = (-0.38 <= center.y <= -0.08 and center.z >= 0.50)
        rump_patch = (0.20 <= center.y <= 0.48 and center.z >= 0.54)
        if shoulder_patch or rump_patch:
            polygon.material_index = 1
            wet_face_count += 1

    if wet_face_count < 8:
        raise RuntimeError(f"Wet-fur material breakup selected too few body faces: {wet_face_count}")

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
        "wet_fur_face_count": wet_face_count,
        "material_slots": len(obj.data.materials),
    }


def _save_source(out_dir: Path) -> Path:
    path = out_dir / "grave_hound_mesh_candidate.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(path))
    return path


def _export_candidate(
    rig: bpy.types.Object,
    candidate: bpy.types.Object,
    ribs: bpy.types.Object,
    wound: bpy.types.Object,
    head_damage: list[bpy.types.Object],
    out_dir: Path,
) -> Path:
    path = out_dir / "grave_hound_mesh_candidate.glb"
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    candidate.select_set(True)
    ribs.select_set(True)
    wound.select_set(True)
    for damage_obj in head_damage:
        damage_obj.select_set(True)
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
    ribs = next((obj for obj in meshes if obj.name.startswith(RIBS_NAME)), None)
    if ribs is None:
        raise RuntimeError(f"Round-trip lost {RIBS_NAME}")
    wound = next((obj for obj in meshes if obj.name.startswith(WOUND_NAME)), None)
    if wound is None:
        raise RuntimeError(f"Round-trip lost {WOUND_NAME}")
    eye_socket = next((obj for obj in meshes if obj.name.startswith(EYE_SOCKET_NAME)), None)
    if eye_socket is None:
        raise RuntimeError(f"Round-trip lost {EYE_SOCKET_NAME}")
    jaw_damage = next((obj for obj in meshes if obj.name.startswith(JAW_BONE_NAME)), None)
    if jaw_damage is None:
        raise RuntimeError(f"Round-trip lost {JAW_BONE_NAME}")

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
        "rib_vertex_count": len(ribs.data.vertices),
        "rib_polygon_count": len(ribs.data.polygons),
        "wound_vertex_count": len(wound.data.vertices),
        "wound_polygon_count": len(wound.data.polygons),
        "eye_socket_vertex_count": len(eye_socket.data.vertices),
        "eye_socket_polygon_count": len(eye_socket.data.polygons),
        "jaw_damage_vertex_count": len(jaw_damage.data.vertices),
        "jaw_damage_polygon_count": len(jaw_damage.data.polygons),
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
    ribs, rib_stats = _create_ribs_candidate(rig)
    wound, wound_stats = _create_wound_candidate(rig)
    head_damage, head_damage_stats = _create_head_damage_layers(rig)

    _reset_rig_pose(rig)
    source_path = _save_source(out_dir)
    glb_path = _export_candidate(rig, candidate, ribs, wound, head_damage, out_dir)
    roundtrip = _roundtrip_candidate(glb_path)

    report = {
        "status": "pass",
        "purpose": "fifteenth camera-reviewed Grave Hound candidate with opaque wet-dead-fur material breakup plus controlled corpse damage; not final user-accepted art",
        "blender_version": bpy.app.version_string,
        "rig_route": "Basic Quadruped + Shadowborn custom jaw",
        "candidate_mesh": BODY_NAME,
        "candidate_revision": 15,
        "torso_topology": "single_connected_elliptical_loft_surface",
        "tail_policy": "short broken stump anchored to pelvis/loin deform bones; full tail chain intentionally not visible",
        "candidate_stats_before_export": candidate_stats,
        "exposed_rib_stats_before_export": rib_stats,
        "thorax_wound_stats_before_export": wound_stats,
        "head_damage_stats_before_export": head_damage_stats,
        "roundtrip": roundtrip,
        "semantic_actions": actions,
        "semantic_actions_are_final_art": False,
        "anatomy_policy": {
            "deep_shoulder_chest": True,
            "tucked_abdomen": True,
            "stronger_hindquarter_mass": True,
            "deeper_thorax_and_proximal_limb_mass": True,
            "compact_forelimb_read": True,
            "short_damaged_tail": True,
            "asymmetric_ears": True,
            "continuous_canine_head_profile": True,
            "exposed_thorax_cavity": True,
            "single_missing_eye": True,
            "controlled_damaged_jaw": True,
            "opaque_wet_dead_fur_patches": True,
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
