#!/usr/bin/env python3
"""Build the first original Shadowborn Shadow mesh candidate.

Production-candidate goals:
- faceless hood/cowl identity visible from gameplay camera;
- weak, incomplete early-game silhouette rather than heroic knight mass;
- human proportions on the measured Rigify Basic Human game rig;
- four-influence skin path;
- semantic idle/A1 actions inherited from shadow_rig_smoke.py.

This does not write res://assets/characters/shadow/shadow.glb.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0,str(SCRIPT_DIR))

import bpy
from mathutils import Vector

from shadow_rig_smoke import (
    EXPECTED_BLENDER,
    SMOKE_ACTIONS,
    _clear_scene,
    _create_basic_human_metarig,
    _create_smoke_actions,
    _enable_rigify,
    _generate_rig,
    _require_blender_version,
    _reset_pose,
)

BODY_NAME="SHD_BODY_CANDIDATE"
HOOD_NAME="SHD_HOOD_CANDIDATE"
VOID_NAME="SHD_FACE_VOID_CANDIDATE"
CLOTH_NAME="SHD_HIP_CLOTH_CANDIDATE"
MAX_INFLUENCES=4


def _args():
    argv=sys.argv
    argv=argv[argv.index("--")+1:] if "--" in argv else []
    parser=argparse.ArgumentParser()
    parser.add_argument("--out-dir",default="build/dcc_shadow")
    return parser.parse_args(argv)


class MeshBuilder:
    def __init__(self):
        self.vertices=[]
        self.faces=[]
        self.weight_pools=[]
        self.forced_weights=[]

    def _v(self,p,pool,forced=None):
        self.vertices.append(tuple(p))
        self.weight_pools.append(tuple(pool))
        self.forced_weights.append(forced)
        return len(self.vertices)-1

    def body_loft(self,stations,pool,segments=14):
        rings=[]
        for center,rx,rz in stations:
            ring=[]
            for i in range(segments):
                a=math.tau*float(i)/float(segments)
                ring.append(self._v(center+Vector((rx*math.cos(a),0.0,rz*math.sin(a))),pool))
            rings.append(ring)
        for r in range(len(rings)-1):
            a=rings[r]; b=rings[r+1]
            for i in range(segments):
                n=(i+1)%segments
                self.faces.append((a[i],a[n],b[n],b[i]))
        c0=self._v(stations[0][0],pool)
        c1=self._v(stations[-1][0],pool)
        for i in range(segments):
            n=(i+1)%segments
            self.faces.append((c0,rings[0][n],rings[0][i]))
            self.faces.append((c1,rings[-1][i],rings[-1][n]))

    def tube(self,points,radii,pool,segments=10,forced=None):
        rings=[]
        for idx,p in enumerate(points):
            if idx==0: tangent=(points[1]-points[0]).normalized()
            elif idx==len(points)-1: tangent=(points[-1]-points[-2]).normalized()
            else: tangent=(points[idx+1]-points[idx-1]).normalized()
            ref=Vector((0,0,1))
            if abs(tangent.dot(ref))>0.92: ref=Vector((1,0,0))
            side=tangent.cross(ref).normalized()
            up=side.cross(tangent).normalized()
            ring=[]
            for i in range(segments):
                a=math.tau*float(i)/float(segments)
                radial=side*math.cos(a)+up*math.sin(a)
                ring.append(self._v(p+radial*radii[idx],pool,forced))
            rings.append(ring)
        for r in range(len(rings)-1):
            a=rings[r]; b=rings[r+1]
            for i in range(segments):
                n=(i+1)%segments
                self.faces.append((a[i],a[n],b[n],b[i]))
        s=self._v(points[0],pool,forced)
        e=self._v(points[-1],pool,forced)
        for i in range(segments):
            n=(i+1)%segments
            self.faces.append((s,rings[0][i],rings[0][n]))
            self.faces.append((e,rings[-1][n],rings[-1][i]))

    def ellipsoid(self,center,radii,pool,segments=14,rings=7,forced=None):
        south=self._v(center+Vector((0,0,-radii.z)),pool,forced)
        rr=[]
        for r in range(1,rings):
            phi=-math.pi*0.5+math.pi*float(r)/float(rings)
            cp=math.cos(phi); sp=math.sin(phi)
            ring=[]
            for s in range(segments):
                theta=math.tau*float(s)/float(segments)
                ring.append(self._v(center+Vector((
                    radii.x*cp*math.cos(theta),
                    radii.y*cp*math.sin(theta),
                    radii.z*sp,
                )),pool,forced))
            rr.append(ring)
        north=self._v(center+Vector((0,0,radii.z)),pool,forced)
        for s in range(segments):
            self.faces.append((south,rr[0][(s+1)%segments],rr[0][s]))
        for r in range(len(rr)-1):
            a=rr[r]; b=rr[r+1]
            for s in range(segments):
                n=(s+1)%segments
                self.faces.append((a[s],a[n],b[n],b[s]))
        for s in range(segments):
            self.faces.append((rr[-1][s],rr[-1][(s+1)%segments],north))

    def quad(self,a,b,c,d,pool,forced=None):
        ia=self._v(a,pool,forced); ib=self._v(b,pool,forced)
        ic=self._v(c,pool,forced); idd=self._v(d,pool,forced)
        self.faces.append((ia,ib,ic,idd))


def _bone(rig,name):
    b=rig.data.bones.get(name)
    if b is None: raise RuntimeError(f"Missing required Shadow deform bone: {name}")
    return b

def _center(rig,name):
    b=_bone(rig,name)
    return (b.head_local+b.tail_local)*0.5

def _pool(*names): return tuple(names)


def _dist_point_segment(p,a,b):
    axis=b-a
    ls=axis.length_squared
    if ls<=1e-10: return (p-a).length
    t=max(0.0,min(1.0,(p-a).dot(axis)/ls))
    return (p-(a+axis*t)).length


def _weights(rig,p,pool,forced):
    if forced:
        total=sum(forced.values())
        return {k:v/total for k,v in forced.items()}
    scored=[]
    for name in pool:
        b=rig.data.bones.get(name)
        if b is None or not b.use_deform: continue
        scored.append((_dist_point_segment(p,b.head_local,b.tail_local),name))
    scored.sort(key=lambda x:x[0])
    chosen=scored[:MAX_INFLUENCES]
    if not chosen: raise RuntimeError("No Shadow deform bones for vertex")
    raw=[(name,1.0/max(d,0.018)**2.0) for d,name in chosen]
    total=sum(v for _,v in raw)
    return {name:v/total for name,v in raw}


def _material(name,color,roughness):
    mat=bpy.data.materials.new(name)
    mat.diffuse_color=color
    mat.metallic=0.0
    mat.roughness=roughness
    mat.use_nodes=True
    bsdf=mat.node_tree.nodes.get("Principled BSDF")
    if bsdf is not None:
        if "Base Color" in bsdf.inputs: bsdf.inputs["Base Color"].default_value=color
        if "Roughness" in bsdf.inputs: bsdf.inputs["Roughness"].default_value=roughness
        if "Metallic" in bsdf.inputs: bsdf.inputs["Metallic"].default_value=0.0
    return mat


def _skin_object(rig,name,builder,material):
    mesh=bpy.data.meshes.new(name+"_Mesh")
    mesh.from_pydata(builder.vertices,[],builder.faces)
    mesh.update()
    for poly in mesh.polygons: poly.use_smooth=True
    obj=bpy.data.objects.new(name,mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(material)

    groups={}
    max_inf=0
    for idx,pt in enumerate(builder.vertices):
        ws=_weights(rig,Vector(pt),builder.weight_pools[idx],builder.forced_weights[idx])
        max_inf=max(max_inf,len(ws))
        for bone_name,w in ws.items():
            g=groups.get(bone_name)
            if g is None:
                g=obj.vertex_groups.new(name=bone_name); groups[bone_name]=g
            g.add([idx],float(w),"REPLACE")
    if max_inf>MAX_INFLUENCES:
        raise RuntimeError(f"{name} exceeds four influences")

    mod=obj.modifiers.new(name="ShadowArmature",type="ARMATURE")
    mod.object=rig
    mod.use_vertex_groups=True
    world=obj.matrix_world.copy()
    obj.parent=rig
    obj.matrix_parent_inverse=rig.matrix_world.inverted()
    obj.matrix_world=world
    obj["shadowborn_asset_tier"]="production_candidate"
    obj["shadowborn_original_mesh"]=True
    obj["shadowborn_shipping_accepted"]=False
    return obj,{"vertices":len(builder.vertices),"polygons":len(builder.faces),"max_influences":max_inf}


def _build_body(rig):
    b=MeshBuilder()

    hips=_center(rig,"DEF-spine")
    waist=_center(rig,"DEF-spine.002")
    chest=_center(rig,"DEF-spine.004")
    upper=_center(rig,"DEF-spine.005")

    torso_pool=_pool(
        "DEF-spine","DEF-spine.001","DEF-spine.002","DEF-spine.003","DEF-spine.004","DEF-spine.005",
        "DEF-pelvis.L","DEF-pelvis.R","DEF-shoulder.L","DEF-shoulder.R"
    )
    stations=[
        (hips+Vector((0,0,0.020)),0.195,0.165),
        (waist+Vector((0,0,0.015)),0.165,0.155),
        ((waist+chest)*0.5,0.195,0.190),
        (chest,0.235,0.205),
        (upper+Vector((0,0,-0.005)),0.215,0.175),
    ]
    stations.sort(key=lambda s:s[0].z)
    b.body_loft(stations,torso_pool,segments=14)

    # Arms: lean rather than heroic, with clear wrist/hand taper.
    for side in ("L","R"):
        arm_names=[
            f"DEF-shoulder.{side}",
            f"DEF-upper_arm.{side}",
            f"DEF-upper_arm.{side}.001",
            f"DEF-forearm.{side}",
            f"DEF-forearm.{side}.001",
            f"DEF-hand.{side}",
        ]
        points=[_bone(rig,arm_names[0]).head_local]
        points.extend(_bone(rig,n).tail_local for n in arm_names)
        side_sign = -1.0 if side=="L" else 1.0
        points = [
            p + Vector((0.018*side_sign*(1.0-float(i)/max(1.0,float(len(points)-1))),0.0,0.0))
            for i,p in enumerate(points)
        ]
        b.tube(points,[0.090,0.094,0.080,0.067,0.056,0.048,0.040],tuple(arm_names),segments=9)

    # Legs: slightly stronger thighs but still early/under-equipped.
    for side in ("L","R"):
        leg_names=[
            f"DEF-thigh.{side}",
            f"DEF-thigh.{side}.001",
            f"DEF-shin.{side}",
            f"DEF-shin.{side}.001",
            f"DEF-foot.{side}",
            f"DEF-toe.{side}",
        ]
        points=[_bone(rig,leg_names[0]).head_local]
        points.extend(_bone(rig,n).tail_local for n in leg_names)
        b.tube(points,[0.115,0.105,0.082,0.066,0.052,0.045,0.032],tuple(leg_names),segments=9)

    return b


def _build_hood(rig):
    b=MeshBuilder()
    head=_center(rig,"DEF-spine.006")
    neck_pool=_pool("DEF-spine.005","DEF-spine.006")

    # Narrow hood shell: taller than wide, no oversized sphere read.
    b.ellipsoid(
        head+Vector((0.0,0.010,0.010)),
        Vector((0.122,0.132,0.172)),
        neck_pool,
        segments=14,
        rings=7,
    )

    # Short cowl mass at shoulders, not a heroic cape.
    chest=_center(rig,"DEF-spine.005")
    b.body_loft([
        (chest+Vector((0,0,-0.070)),0.285,0.090),
        (chest+Vector((0,0,0.035)),0.238,0.075),
        (chest+Vector((0,0,0.115)),0.178,0.055),
    ],_pool("DEF-spine.004","DEF-spine.005","DEF-spine.006","DEF-shoulder.L","DEF-shoulder.R"),segments=14)
    return b


def _build_void(rig):
    b=MeshBuilder()
    head=_center(rig,"DEF-spine.006")
    # Basic Human faces -Y in the measured Rigify baseline.
    center=head+Vector((0.0,-0.145,0.005))
    b.ellipsoid(
        center,
        Vector((0.082,0.018,0.112)),
        _pool("DEF-spine.006"),
        segments=12,
        rings=6,
        forced={"DEF-spine.006":1.0},
    )
    return b


def _build_cloth(rig):
    b=MeshBuilder()
    hips=_center(rig,"DEF-spine")
    pool=_pool("DEF-spine","DEF-pelvis.L","DEF-pelvis.R","DEF-thigh.L","DEF-thigh.R")

    # Asymmetric torn front/back panels; thin geometry owns the early silhouette.
    front_y=-0.118
    back_y=0.108
    z0=hips.z+0.055
    z1=hips.z-0.34
    # Three shorter torn panels read as damaged cloth instead of one rigid skirt.
    b.quad(
        Vector((-0.18,front_y,z0)),
        Vector((-0.035,front_y,z0)),
        Vector((-0.055,front_y,z1-0.045)),
        Vector((-0.16,front_y,z1+0.030)),
        pool,
    )
    b.quad(
        Vector((0.005,front_y,z0-0.010)),
        Vector((0.17,front_y,z0)),
        Vector((0.12,front_y,z1+0.055)),
        Vector((0.025,front_y,z1-0.010)),
        pool,
    )
    b.quad(
        Vector((0.16,back_y,z0)),
        Vector((-0.16,back_y,z0)),
        Vector((-0.105,back_y,z1+0.065)),
        Vector((0.075,back_y,z1+0.110)),
        pool,
    )
    return b


def _export(rig,objects,out_dir):
    path=out_dir/"shadow_mesh_candidate.glb"
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=rig

    props=bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
    kwargs=dict(
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
    if "export_all_influences" in props:kwargs["export_all_influences"]=False
    if "export_influence_nb" in props:kwargs["export_influence_nb"]=4
    result=bpy.ops.export_scene.gltf(**kwargs)
    if "FINISHED" not in result or not path.exists():
        raise RuntimeError(f"Shadow candidate export failed: {result}")
    return path


def _roundtrip(path):
    _clear_scene()
    result=bpy.ops.import_scene.gltf(
        filepath=str(path),
        bone_heuristic="BLENDER",
        guess_original_bind_pose=True,
    )
    if "FINISHED" not in result: raise RuntimeError("Shadow candidate re-import failed")
    arm=[o for o in bpy.context.scene.objects if o.type=="ARMATURE"]
    meshes=[o for o in bpy.context.scene.objects if o.type=="MESH"]
    actions=sorted(a.name for a in bpy.data.actions)
    if len(arm)!=1:raise RuntimeError(f"Expected one armature, found {len(arm)}")
    missing=sorted(set(SMOKE_ACTIONS)-set(actions))
    if missing:raise RuntimeError(f"Missing Shadow actions: {missing}")
    names=sorted(o.name for o in meshes)
    required=(BODY_NAME,HOOD_NAME,VOID_NAME,CLOTH_NAME)
    for prefix in required:
        if not any(name.startswith(prefix) for name in names):
            raise RuntimeError(f"Round-trip lost Shadow mesh layer: {prefix}")
    return {
        "armature_count":len(arm),
        "bone_count":len(arm[0].data.bones),
        "mesh_count":len(meshes),
        "mesh_names":names,
        "actions":actions,
    }


def main():
    args=_args()
    out=Path(args.out_dir).resolve()
    out.mkdir(parents=True,exist_ok=True)
    _require_blender_version()
    _enable_rigify()
    _clear_scene()

    metarig=_create_basic_human_metarig()
    rig=_generate_rig(metarig)
    actions,controls=_create_smoke_actions(rig)

    body,body_stats=_skin_object(rig,BODY_NAME,_build_body(rig),_material("SHD_SHADOW_BODY",(0.030,0.036,0.050,1.0),0.92))
    hood,hood_stats=_skin_object(rig,HOOD_NAME,_build_hood(rig),_material("SHD_WORN_DARK_CLOTH",(0.020,0.024,0.034,1.0),0.96))
    void,void_stats=_skin_object(rig,VOID_NAME,_build_void(rig),_material("SHD_FACELESS_VOID",(0.001,0.002,0.005,1.0),1.0))
    cloth,cloth_stats=_skin_object(rig,CLOTH_NAME,_build_cloth(rig),_material("SHD_TORN_HIP_CLOTH",(0.022,0.026,0.035,1.0),0.97))
    objects=[body,hood,void,cloth]

    _reset_pose(rig)
    blend=out/"shadow_mesh_candidate.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    glb=_export(rig,objects,out)
    roundtrip=_roundtrip(glb)

    report={
        "status":"pass",
        "purpose":"second camera-reviewed faceless Shadow mesh candidate with compact hood, connected upper silhouette and torn cloth panels; not final accepted art",
        "blender_version":bpy.app.version_string,
        "rig_route":"Rigify Basic Human",
        "measured_controls":controls,
        "semantic_actions":actions,
        "semantic_actions_are_final_art":False,
        "layers":{
            BODY_NAME:body_stats,
            HOOD_NAME:hood_stats,
            VOID_NAME:void_stats,
            CLOTH_NAME:cloth_stats,
        },
        "roundtrip":roundtrip,
        "source_blend":blend.name,
        "candidate_glb":glb.name,
        "shipping_path_written":False,
        "next_gate":"Godot import + fixed gameplay-camera idle/A1 silhouettes + sword socket/Grip validation",
    }
    (out/"shadow_mesh_candidate_report.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
    print("SHADOWBORN_SHADOW_MESH_CANDIDATE_PASS")
    print(json.dumps(report,indent=2))


if __name__=="__main__":
    main()
