extends Node3D

# Original Shadowborn Grave Hound production-preview.
# Vendor wolf geometry stays hidden; its quadruped skeleton/animations are a
# temporary carrier only. Visual acceptance still requires grave_hound.glb.

const PREVIEW_SOURCE := "generated://shadowborn/grave_hound_preview_v1"
const CARRIER_NAME := "AnimationCarrier"

var _flesh_material: ShaderMaterial
var _wound_material: StandardMaterial3D
var _bone_material: StandardMaterial3D
var _void_material: StandardMaterial3D

func _ready() -> void:
	var carrier := get_node_or_null(CARRIER_NAME)
	if carrier == null:
		push_error("Grave Hound preview: missing AnimationCarrier")
		return
	_hide_vendor_visuals(carrier)
	var skeleton := _find_skeleton(carrier)
	if skeleton == null:
		push_error("Grave Hound preview: animation carrier has no Skeleton3D")
		return
	_prepare_materials()
	_build_hound(skeleton)
	set_meta("shadowborn_preview_visible_geometry","original_shadowborn")
	set_meta("shadowborn_preview_animation_carrier","temporary_vendor_rig_hidden")

func _prepare_materials() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
void fragment() {
	float facing = clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0);
	float rim = pow(1.0-facing,2.4);
	ALBEDO = vec3(0.090,0.102,0.082);
	ROUGHNESS = 0.96;
	METALLIC = 0.0;
	EMISSION = vec3(0.055,0.085,0.065)*rim*0.14;
}
"""
	_flesh_material = ShaderMaterial.new()
	_flesh_material.shader = shader

	_wound_material = StandardMaterial3D.new()
	_wound_material.albedo_color = Color(0.105,0.018,0.012)
	_wound_material.roughness = 0.95

	_bone_material = StandardMaterial3D.new()
	_bone_material.albedo_color = Color(0.42,0.38,0.29)
	_bone_material.roughness = 0.91

	_void_material = StandardMaterial3D.new()
	_void_material.albedo_color = Color(0.004,0.006,0.005)
	_void_material.roughness = 1.0

func _hide_vendor_visuals(node: Node) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).visible = false
	for child in node.get_children():
		_hide_vendor_visuals(child)

func _build_hound(skeleton: Skeleton3D) -> void:
	_build_skinned_body(skeleton)
	_attach_head(skeleton)
	_attach_ears(skeleton)
	_attach_ribs(skeleton)
	_attach_wounds(skeleton)

func _build_skinned_body(skeleton: Skeleton3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)

	# Tucked abdomen -> larger diseased chest -> thin neck/head connection.
	_append_skinned_chain(st,skeleton,
		["Back","Torso","Torso2","Torso3","Neck1","Neck2","Neck3","Head"],
		[0.27,0.245,0.295,0.315,0.190,0.145,0.115,0.080],
		[0.190,0.170,0.220,0.250,0.150,0.115,0.090,0.065],14)

	for side in ["L","R"]:
		_append_skinned_chain(st,skeleton,
			["Torso2","FrontShoulder.%s" % side,"FrontUpperLeg.%s" % side,"FrontLowerLeg.%s" % side],
			[0.165,0.145,0.110,0.075],
			[0.128,0.112,0.086,0.060],10)
		_append_skinned_chain(st,skeleton,
			["Back","BackShoulder.%s" % side,"BackLeg.%s" % side,"BackUpperLeg.%s" % side,"BackLowerLeg.%s" % side],
			[0.165,0.155,0.135,0.105,0.070],
			[0.130,0.118,0.105,0.082,0.058],10)

	_append_skinned_chain(st,skeleton,
		["Back","Tail1","Tail2","Tail3","Tail4","Tail5","Tail6","Tail7","Tail8"],
		[0.080,0.075,0.068,0.060,0.052,0.044,0.036,0.028,0.018],
		[0.065,0.060,0.054,0.048,0.041,0.035,0.028,0.022,0.014],8)

	st.generate_normals()
	var mesh := st.commit()
	if mesh == null:
		push_error("Grave Hound preview: failed to build skinned mesh")
		return

	var visual := MeshInstance3D.new()
	visual.name = "GraveHoundSkinnedBodyV1"
	visual.mesh = mesh
	visual.material_override = _flesh_material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	visual.set_meta("shadowborn_visual_tier","production_preview")
	visual.set_meta("shadowborn_visual_source",PREVIEW_SOURCE)
	visual.set_meta("shadowborn_deformation_contract","continuous_quadruped_skin")
	skeleton.add_child(visual)
	visual.skeleton = visual.get_path_to(skeleton)
	visual.skin = skeleton.create_skin_from_rest_transforms()

func _attach_head(skeleton: Skeleton3D) -> void:
	var head_socket := _bone_socket(skeleton,"Head","HoundHeadSocket")
	if head_socket == null:
		return

	var skull := MeshInstance3D.new()
	skull.name = "HoundSkull"
	var skull_mesh := SphereMesh.new()
	skull_mesh.radius = 0.225
	skull_mesh.height = 0.40
	skull_mesh.radial_segments = 18
	skull_mesh.rings = 9
	skull_mesh.material = _flesh_material
	skull.mesh = skull_mesh
	skull.position = Vector3(0.0,0.06,0.0)
	skull.scale = Vector3(0.84,1.20,0.82)
	_tag_preview(skull)
	head_socket.add_child(skull)

	var muzzle := MeshInstance3D.new()
	muzzle.name = "HoundMuzzle"
	muzzle.mesh = _make_muzzle_mesh()
	muzzle.material_override = _flesh_material
	muzzle.position = Vector3(0.0,0.225,0.0)
	muzzle.scale = Vector3(1.10,1.03,1.10)
	_tag_preview(muzzle)
	head_socket.add_child(muzzle)

	var nose := MeshInstance3D.new()
	nose.name = "HoundNoseVoid"
	var nose_mesh := SphereMesh.new()
	nose_mesh.radius = 0.070
	nose_mesh.height = 0.12
	nose_mesh.radial_segments = 12
	nose_mesh.rings = 6
	nose_mesh.material = _void_material
	nose.mesh = nose_mesh
	nose.position = Vector3(0.0,0.43,0.0)
	nose.scale = Vector3(0.85,0.65,0.80)
	_tag_preview(nose)
	head_socket.add_child(nose)

func _attach_ears(skeleton: Skeleton3D) -> void:
	for side in ["L","R"]:
		var socket := _bone_socket(skeleton,"Ear1.%s" % side,"HoundEarSocket%s" % side)
		if socket == null:
			continue
		var ear := MeshInstance3D.new()
		ear.name = "HoundTornEar%s" % side
		ear.mesh = _make_ear_mesh(-1.0 if side == "L" else 1.0)
		ear.material_override = _flesh_material
		ear.rotation_degrees.z = 10.0 if side == "L" else -13.0
		_tag_preview(ear)
		socket.add_child(ear)

func _attach_ribs(skeleton: Skeleton3D) -> void:
	var socket := _bone_socket(skeleton,"Torso2","ExposedRibsSocket")
	if socket == null:
		return
	for side in [-1.0,1.0]:
		for i in range(3):
			var rib := MeshInstance3D.new()
			rib.name = "Rib_%s_%d" % ["L" if side < 0.0 else "R",i]
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.018
			mesh.bottom_radius = 0.023
			mesh.height = 0.27-float(i)*0.025
			mesh.radial_segments = 7
			mesh.material = _bone_material
			rib.mesh = mesh
			rib.position = Vector3(0.20*side,0.02+0.065*i,-0.10+0.035*i)
			rib.rotation_degrees = Vector3(78.0,8.0*side,side*(26.0-5.0*i))
			_tag_preview(rib)
			socket.add_child(rib)

func _attach_wounds(skeleton: Skeleton3D) -> void:
	var socket := _bone_socket(skeleton,"Torso2","HoundWoundsSocket")
	if socket == null:
		return
	for data in [
		[Vector3(0.19,0.04,-0.11),Vector3(1.30,0.20,0.72),-8.0],
		[Vector3(-0.16,-0.04,0.10),Vector3(1.05,0.17,0.62),11.0]
	]:
		var wound := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.105
		mesh.height = 0.21
		mesh.radial_segments = 9
		mesh.rings = 5
		mesh.material = _wound_material
		wound.mesh = mesh
		wound.position = data[0]
		wound.scale = data[1]
		wound.rotation_degrees.z = data[2]
		_tag_preview(wound)
		socket.add_child(wound)

func _make_muzzle_mesh() -> ArrayMesh:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	var sides := 12
	var back_y := -0.025
	var front_y := 0.245
	var back_rx := 0.125
	var back_rz := 0.105
	var front_rx := 0.078
	var front_rz := 0.062
	for i in range(sides):
		var a0 := TAU*float(i)/float(sides)
		var a1 := TAU*float(i+1)/float(sides)
		var b0 := Vector3(cos(a0)*back_rx,back_y,sin(a0)*back_rz)
		var b1 := Vector3(cos(a1)*back_rx,back_y,sin(a1)*back_rz)
		var f0 := Vector3(cos(a0)*front_rx,front_y,sin(a0)*front_rz)
		var f1 := Vector3(cos(a1)*front_rx,front_y,sin(a1)*front_rz)
		_quad(st,b0,b1,f1,f0)
		_tri(st,Vector3(0.0,front_y,0.0),f0,f1)
	st.generate_normals()
	return st.commit()

func _make_ear_mesh(side: float) -> ArrayMesh:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var root_l:=Vector3(-0.065,0.0,-0.025)
	var root_r:=Vector3(0.065,0.0,0.020)
	var mid:=Vector3(0.02*side,0.17,0.015)
	var tip:=Vector3(-0.015*side,0.31,-0.030)
	var torn:=Vector3(0.045*side,0.235,0.018)
	_tri(st,root_l,root_r,mid)
	_tri(st,root_l,mid,tip)
	_tri(st,mid,root_r,torn)
	_tri(st,root_l,tip,mid)
	_tri(st,mid,torn,root_r)
	st.generate_normals()
	return st.commit()

func _append_skinned_chain(st: SurfaceTool,skeleton: Skeleton3D,bone_names: Array,radii_x: Array,radii_z: Array,sides: int) -> void:
	if bone_names.size() < 2 or radii_x.size() != bone_names.size() or radii_z.size() != bone_names.size():
		push_error("Grave Hound preview: invalid chain definition")
		return
	var bone_indices: Array[int] = []
	var centers: Array[Vector3] = []
	for name_variant in bone_names:
		var idx := skeleton.find_bone(str(name_variant))
		if idx < 0:
			push_warning("Grave Hound preview: missing bone %s" % str(name_variant))
			return
		bone_indices.append(idx)
		centers.append(skeleton.get_bone_global_rest(idx).origin)

	var rings: Array = []
	rings.append(_skin_ring_record(centers[0],float(radii_x[0]),float(radii_z[0]),bone_indices[0],bone_indices[0],1.0,0.0))
	for i in range(bone_indices.size()-1):
		var a: Vector3 = centers[i]
		var b: Vector3 = centers[i+1]
		rings.append(_skin_ring_record(a.lerp(b,0.5),lerpf(float(radii_x[i]),float(radii_x[i+1]),0.5),lerpf(float(radii_z[i]),float(radii_z[i+1]),0.5),bone_indices[i],bone_indices[i+1],0.5,0.5))
		rings.append(_skin_ring_record(b,float(radii_x[i+1]),float(radii_z[i+1]),bone_indices[i+1],bone_indices[i+1],1.0,0.0))

	var ring_points: Array = []
	for r in range(rings.size()):
		var rec: Dictionary = rings[r]
		var prev_center: Vector3 = (rings[maxi(0,r-1)] as Dictionary)["center"]
		var next_center: Vector3 = (rings[mini(rings.size()-1,r+1)] as Dictionary)["center"]
		var tangent := (next_center-prev_center).normalized()
		if tangent.length() < 0.001:
			tangent = Vector3.FORWARD
		var helper := Vector3.UP if absf(tangent.dot(Vector3.UP)) < 0.82 else Vector3.FORWARD
		var axis_x := tangent.cross(helper).normalized()
		if axis_x.length() < 0.001:
			axis_x = Vector3.RIGHT
		var axis_z := axis_x.cross(tangent).normalized()
		var points: Array[Vector3] = []
		for side_idx in range(sides):
			var angle := TAU*float(side_idx)/float(sides)
			points.append((rec["center"] as Vector3)+axis_x*cos(angle)*float(rec["rx"])+axis_z*sin(angle)*float(rec["rz"]))
		ring_points.append(points)

	for r in range(rings.size()-1):
		var rec_a: Dictionary = rings[r]
		var rec_b: Dictionary = rings[r+1]
		var pa: Array = ring_points[r]
		var pb: Array = ring_points[r+1]
		for side_idx in range(sides):
			var ni := (side_idx+1)%sides
			_skin_tri(st,pa[side_idx],rec_a,pb[side_idx],rec_b,pb[ni],rec_b)
			_skin_tri(st,pa[side_idx],rec_a,pb[ni],rec_b,pa[ni],rec_a)

func _skin_ring_record(center: Vector3,rx: float,rz: float,bone_a: int,bone_b: int,weight_a: float,weight_b: float) -> Dictionary:
	return {"center":center,"rx":rx,"rz":rz,"bone_a":bone_a,"bone_b":bone_b,"weight_a":weight_a,"weight_b":weight_b}

func _skin_tri(st: SurfaceTool,a: Vector3,ra: Dictionary,b: Vector3,rb: Dictionary,c: Vector3,rc: Dictionary) -> void:
	_skin_vertex(st,a,ra)
	_skin_vertex(st,b,rb)
	_skin_vertex(st,c,rc)

func _skin_vertex(st: SurfaceTool,position: Vector3,record: Dictionary) -> void:
	st.set_bones(PackedInt32Array([int(record["bone_a"]),int(record["bone_b"]),0,0]))
	st.set_weights(PackedFloat32Array([float(record["weight_a"]),float(record["weight_b"]),0.0,0.0]))
	st.add_vertex(position)

func _bone_socket(skeleton: Skeleton3D,bone_name: String,node_name: String) -> BoneAttachment3D:
	if skeleton.find_bone(bone_name) < 0:
		return null
	var socket := BoneAttachment3D.new()
	socket.name = node_name
	socket.bone_name = bone_name
	skeleton.add_child(socket)
	return socket

func _tag_preview(mesh: MeshInstance3D) -> void:
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mesh.set_meta("shadowborn_visual_tier","production_preview")
	mesh.set_meta("shadowborn_visual_source",PREVIEW_SOURCE)

func _tri(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)

func _quad(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3) -> void:
	_tri(st,a,b,c)
	_tri(st,a,c,d)

func _find_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root as Skeleton3D
	for child in root.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null
