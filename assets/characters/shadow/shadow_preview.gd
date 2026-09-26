extends Node3D

# Original Shadowborn production-preview silhouette.
# Visible geometry is authored here from project-owned vertex layouts.
# The Quaternius child remains TEMPORARILY as an invisible animation/skeleton carrier.
# Acceptance mode still requires the final production shadow.glb.

const PREVIEW_SOURCE := "generated://shadowborn/shadow_preview_v2"
const CARRIER_NAME := "AnimationCarrier"

var _body_material: ShaderMaterial
var _cloth_material: ShaderMaterial
var _void_material: StandardMaterial3D
var _accent_material: StandardMaterial3D

func _ready() -> void:
	var carrier := get_node_or_null(CARRIER_NAME)
	if carrier == null:
		push_error("Shadow preview: missing AnimationCarrier")
		return
	_hide_vendor_visuals(carrier)
	var skeleton := _find_skeleton(carrier)
	if skeleton == null:
		push_error("Shadow preview: animation carrier has no Skeleton3D")
		return
	_prepare_materials()
	_build_original_silhouette(skeleton)
	set_meta("shadowborn_preview_visible_geometry","original_shadowborn")
	set_meta("shadowborn_preview_animation_carrier","temporary_vendor_rig_hidden")

func _prepare_materials() -> void:
	# Raise broad value separation slightly so the character reads against the
	# cemetery without becoming a glowing silhouette. Rim remains secondary.
	_body_material = _shadow_surface(Color(0.014,0.018,0.030),Color(0.045,0.082,0.160),0.15,0.94)
	_cloth_material = _shadow_surface(Color(0.020,0.025,0.041),Color(0.055,0.098,0.185),0.17,0.98)

	_void_material = StandardMaterial3D.new()
	_void_material.albedo_color = Color(0.0004,0.0008,0.0025)
	_void_material.roughness = 1.0
	_void_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	_accent_material = StandardMaterial3D.new()
	_accent_material.albedo_color = Color(0.035,0.11,0.30)
	_accent_material.roughness = 0.52
	_accent_material.emission_enabled = true
	_accent_material.emission = Color(0.025,0.085,0.24)
	_accent_material.emission_energy_multiplier = 0.42

func _shadow_surface(base_color: Color,edge_color: Color,edge_strength: float,roughness: float) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
uniform vec4 base_color : source_color;
uniform vec3 edge_color : source_color;
uniform float edge_strength = 0.10;
uniform float roughness_value = 0.95;
void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - facing, 2.25);
	ALBEDO = base_color.rgb;
	ROUGHNESS = roughness_value;
	METALLIC = 0.0;
	EMISSION = edge_color * rim * edge_strength;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("base_color",base_color)
	material.set_shader_parameter("edge_color",Vector3(edge_color.r,edge_color.g,edge_color.b))
	material.set_shader_parameter("edge_strength",edge_strength)
	material.set_shader_parameter("roughness_value",roughness)
	return material

func _hide_vendor_visuals(node: Node) -> void:
	if node is MeshInstance3D and not _has_production_tier_ancestor(node):
		(node as MeshInstance3D).visible = false
	for child in node.get_children():
		_hide_vendor_visuals(child)

func _has_production_tier_ancestor(node: Node) -> bool:
	var cursor: Node = node
	while cursor != null and cursor != self:
		var tier := str(cursor.get_meta("shadowborn_visual_tier",""))
		if tier in ["production","production_preview"]:
			return true
		cursor = cursor.get_parent()
	return false

func _build_original_silhouette(skeleton: Skeleton3D) -> void:
	# V3: one continuously skinned body surface replaces the visible rigid
	# torso/limb tubes. Mid-rings carry 50/50 weights between semantic bones so
	# shoulders, elbows, hips and knees deform instead of opening hard seams.
	_build_skinned_body(skeleton)

	# Identity layers: short cowl, asymmetric rear drape and split hip cloth.
	_attach_mesh(skeleton,"Chest","ShadowCowl",_make_cowl_mesh(),Vector3(0.0,0.01,0.0),Vector3.ZERO,_cloth_material)
	_attach_mesh(skeleton,"Hips","ShadowTabardBack",_make_tabard_mesh(-1.0),Vector3(0.0,0.05,0.0),Vector3.ZERO,_cloth_material)
	_attach_mesh(skeleton,"Hips","ShadowTabardFront",_make_tabard_mesh(1.0),Vector3(0.0,0.04,0.0),Vector3.ZERO,_cloth_material)

	# Faceted hood with an actual face opening rather than a spherical helmet.
	_attach_mesh(skeleton,"Head","ShadowHood",_make_hood_mesh(),Vector3(0.0,0.045,0.0),Vector3.ZERO,_cloth_material)
	_attach_mesh(skeleton,"Head","ShadowFaceVoid",_make_face_void_mesh(),Vector3(0.0,0.035,0.0),Vector3.ZERO,_void_material)
	_attach_mesh(skeleton,"Head","ShadowHoodTail",_make_hood_tail_mesh(),Vector3(0.0,0.06,-0.03),Vector3.ZERO,_cloth_material)
	_attach_mesh(skeleton,"Head","ShadowEyeL",_make_diamond_mesh(0.028,0.008),Vector3(-0.045,0.006,0.191),Vector3.ZERO,_accent_material)
	_attach_mesh(skeleton,"Head","ShadowEyeR",_make_diamond_mesh(0.028,0.008),Vector3(0.045,0.006,0.191),Vector3.ZERO,_accent_material)

	for side in ["L","R"]:
		# Hands/feet remain small rigid extremity previews; the major deformation
		# envelope is now owned by the continuous skinned body surface.
		_attach_segment(skeleton,"Wrist.%s" % side,"ShadowHand_%s" % side,0.105,0.055,0.043,0.044,0.036,-0.008,_body_material)
		_attach_mesh(skeleton,"Foot.%s" % side,"ShadowFoot_%s" % side,_make_foot_mesh(),Vector3(0.0,-0.015,0.05),Vector3.ZERO,_body_material)

	# Restrained semantic accent. It should support identity, never become the focal point.
	_attach_mesh(skeleton,"Chest","ShadowChestCore",_make_diamond_mesh(0.042,0.060),Vector3(0.0,0.070,0.205),Vector3.ZERO,_accent_material)

func _build_skinned_body(skeleton: Skeleton3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)

	# Body proportions are intentionally narrow/weak. Each branch begins inside a
	# larger mass (Chest or Hips) so the disconnected topology overlaps invisibly
	# while skin weights keep the visible silhouette continuous during motion.
	_append_skinned_chain(st,skeleton,
		["Hips","Torso","Chest","Neck"],
		[0.18,0.205,0.225,0.095],
		[0.12,0.14,0.150,0.080],10)
	for side in ["L","R"]:
		_append_skinned_chain(st,skeleton,
			["Chest","UpperArm.%s" % side,"LowerArm.%s" % side,"Wrist.%s" % side],
			[0.125,0.085,0.064,0.043],
			[0.095,0.070,0.052,0.038],9)
		_append_skinned_chain(st,skeleton,
			["Hips","UpperLeg.%s" % side,"LowerLeg.%s" % side,"Foot.%s" % side],
			[0.125,0.105,0.075,0.050],
			[0.098,0.080,0.060,0.042],9)

	st.generate_normals()
	var mesh := st.commit()
	if mesh == null:
		push_error("Shadow preview: failed to build skinned body mesh")
		return

	var visual := MeshInstance3D.new()
	visual.name = "ShadowSkinnedBodyV3"
	visual.mesh = mesh
	visual.material_override = _body_material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	visual.set_meta("shadowborn_visual_tier","production_preview")
	visual.set_meta("shadowborn_visual_source","generated://shadowborn/shadow_skinned_preview_v3")
	visual.set_meta("shadowborn_deformation_contract","continuous_skinned_surface")
	skeleton.add_child(visual)
	visual.skeleton = visual.get_path_to(skeleton)
	visual.skin = skeleton.create_skin_from_rest_transforms()

func _append_skinned_chain(st: SurfaceTool,skeleton: Skeleton3D,bone_names: Array,radii_x: Array,radii_z: Array,sides: int) -> void:
	if bone_names.size() < 2 or radii_x.size() != bone_names.size() or radii_z.size() != bone_names.size():
		push_error("Shadow preview: invalid skinned chain definition")
		return

	var bone_indices: Array[int] = []
	var centers: Array[Vector3] = []
	for name_variant in bone_names:
		var idx := skeleton.find_bone(str(name_variant))
		if idx < 0:
			push_warning("Shadow preview: skinned chain missing bone %s" % str(name_variant))
			return
		bone_indices.append(idx)
		centers.append(skeleton.get_bone_global_rest(idx).origin)

	var rings: Array = []
	rings.append(_skin_ring_record(centers[0],float(radii_x[0]),float(radii_z[0]),bone_indices[0],bone_indices[0],1.0,0.0))
	for i in range(bone_indices.size()-1):
		var center_a: Vector3 = centers[i]
		var center_b: Vector3 = centers[i+1]
		var mid := center_a.lerp(center_b,0.5)
		rings.append(_skin_ring_record(
			mid,
			lerpf(float(radii_x[i]),float(radii_x[i+1]),0.5),
			lerpf(float(radii_z[i]),float(radii_z[i+1]),0.5),
			bone_indices[i],bone_indices[i+1],0.5,0.5
		))
		rings.append(_skin_ring_record(
			center_b,float(radii_x[i+1]),float(radii_z[i+1]),
			bone_indices[i+1],bone_indices[i+1],1.0,0.0
		))

	var ring_points: Array = []
	for r in range(rings.size()):
		var rec: Dictionary = rings[r]
		var prev_center: Vector3 = (rings[maxi(0,r-1)] as Dictionary)["center"]
		var next_center: Vector3 = (rings[mini(rings.size()-1,r+1)] as Dictionary)["center"]
		var tangent := (next_center-prev_center).normalized()
		if tangent.length() < 0.001:
			tangent = Vector3.UP
		var helper := Vector3.FORWARD if absf(tangent.dot(Vector3.UP)) > 0.82 else Vector3.UP
		var axis_x := tangent.cross(helper).normalized()
		if axis_x.length() < 0.001:
			axis_x = Vector3.RIGHT
		var axis_z := axis_x.cross(tangent).normalized()
		var points: Array[Vector3] = []
		for side_idx in range(sides):
			var a := TAU*float(side_idx)/float(sides)
			points.append(
				(rec["center"] as Vector3)
				+axis_x*cos(a)*float(rec["rx"])
				+axis_z*sin(a)*float(rec["rz"])
			)
		ring_points.append(points)

	for r in range(rings.size()-1):
		var rec_a: Dictionary = rings[r]
		var rec_b: Dictionary = rings[r+1]
		var pts_a: Array = ring_points[r]
		var pts_b: Array = ring_points[r+1]
		for side_idx in range(sides):
			var next_idx := (side_idx+1)%sides
			_skin_tri(st,pts_a[side_idx],rec_a,pts_b[side_idx],rec_b,pts_b[next_idx],rec_b)
			_skin_tri(st,pts_a[side_idx],rec_a,pts_b[next_idx],rec_b,pts_a[next_idx],rec_a)

func _skin_ring_record(center: Vector3,rx: float,rz: float,bone_a: int,bone_b: int,weight_a: float,weight_b: float) -> Dictionary:
	return {
		"center":center,
		"rx":rx,
		"rz":rz,
		"bone_a":bone_a,
		"bone_b":bone_b,
		"weight_a":weight_a,
		"weight_b":weight_b
	}

func _skin_tri(st: SurfaceTool,a: Vector3,ra: Dictionary,b: Vector3,rb: Dictionary,c: Vector3,rc: Dictionary) -> void:
	_skin_vertex(st,a,ra)
	_skin_vertex(st,b,rb)
	_skin_vertex(st,c,rc)

func _skin_vertex(st: SurfaceTool,position: Vector3,record: Dictionary) -> void:
	st.set_bones(PackedInt32Array([
		int(record["bone_a"]),int(record["bone_b"]),0,0
	]))
	st.set_weights(PackedFloat32Array([
		float(record["weight_a"]),float(record["weight_b"]),0.0,0.0
	]))
	st.add_vertex(position)

func _attach_segment(skeleton: Skeleton3D,bone_name: String,node_name: String,length: float,rx0: float,rz0: float,rx1: float,rz1: float,start_y: float,material: Material) -> void:
	_attach_mesh(skeleton,bone_name,node_name,_make_frustum_mesh(length,rx0,rz0,rx1,rz1,start_y),Vector3.ZERO,Vector3.ZERO,material)

func _attach_mesh(skeleton: Skeleton3D,bone_name: String,node_name: String,mesh: ArrayMesh,position: Vector3,rotation_deg: Vector3,material: Material) -> void:
	if skeleton.find_bone(bone_name) < 0:
		push_warning("Shadow preview: missing expected bone %s" % bone_name)
		return
	var socket := BoneAttachment3D.new()
	socket.name = "%sSocket" % node_name
	socket.bone_name = bone_name
	skeleton.add_child(socket)
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.mesh = mesh
	visual.position = position
	visual.rotation_degrees = rotation_deg
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	visual.set_meta("shadowborn_visual_tier","production_preview")
	visual.set_meta("shadowborn_visual_source",PREVIEW_SOURCE)
	socket.add_child(visual)

func _make_frustum_mesh(length: float,rx0: float,rz0: float,rx1: float,rz1: float,start_y: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 10
	for i in range(sides):
		var a0 := TAU*float(i)/float(sides)
		var a1 := TAU*float(i+1)/float(sides)
		var p0 := Vector3(cos(a0)*rx0,start_y,sin(a0)*rz0)
		var p1 := Vector3(cos(a1)*rx0,start_y,sin(a1)*rz0)
		var q0 := Vector3(cos(a0)*rx1,start_y+length,sin(a0)*rz1)
		var q1 := Vector3(cos(a1)*rx1,start_y+length,sin(a1)*rz1)
		_tri(st,p0,q0,q1)
		_tri(st,p0,q1,p1)
		_tri(st,Vector3(0,start_y,0),p1,p0)
		_tri(st,Vector3(0,start_y+length,0),q0,q1)
	st.generate_normals()
	return st.commit()

func _make_cowl_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var p := [
		Vector3(-0.27,0.065,0.095),Vector3(0.25,0.055,0.095),
		Vector3(0.20,-0.115,0.145),Vector3(-0.235,-0.145,0.150),
		Vector3(-0.25,0.045,-0.125),Vector3(0.23,0.035,-0.130),
		Vector3(0.18,-0.145,-0.155),Vector3(-0.22,-0.185,-0.160)
	]
	_quad(st,p[0],p[1],p[2],p[3])
	_quad(st,p[5],p[4],p[7],p[6])
	_quad(st,p[4],p[0],p[3],p[7])
	_quad(st,p[1],p[5],p[6],p[2])
	_quad(st,p[3],p[2],p[6],p[7])
	st.generate_normals()
	return st.commit()

func _make_back_drape_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a:=Vector3(-0.34,0.04,-0.14)
	var b:=Vector3(0.29,0.03,-0.15)
	var c:=Vector3(0.22,-0.38,-0.18)
	var d:=Vector3(-0.26,-0.48,-0.17)
	var e:=Vector3(-0.04,-0.58,-0.17)
	_tri(st,a,b,c)
	_tri(st,a,c,e)
	_tri(st,a,e,d)
	_tri(st,c,b,a)
	_tri(st,e,c,a)
	_tri(st,d,e,a)
	st.generate_normals()
	return st.commit()

func _make_hood_mesh() -> ArrayMesh:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)

	# Rounded open hood: build several elliptical rings around the back/sides while
	# deliberately leaving the +Z face sector empty. This keeps a real recessed
	# void and removes the previous helmet-like pyramid crown.
	var levels := [
		[Vector3(0.0,-0.205,-0.015),0.155,0.135],
		[Vector3(0.0,-0.080,-0.020),0.190,0.165],
		[Vector3(0.0,0.070,-0.025),0.205,0.180],
		[Vector3(-0.005,0.185,-0.035),0.170,0.145],
		[Vector3(-0.015,0.255,-0.050),0.105,0.090]
	]
	var segments := 14
	var start_angle := deg_to_rad(135.0)
	var span := deg_to_rad(270.0)
	var rings: Array = []
	for level_variant in levels:
		var level: Array = level_variant
		var center: Vector3 = level[0]
		var rx := float(level[1])
		var rz := float(level[2])
		var ring: Array[Vector3] = []
		for i in range(segments+1):
			var a := start_angle+span*float(i)/float(segments)
			ring.append(center+Vector3(cos(a)*rx,0.0,sin(a)*rz))
		rings.append(ring)

	for r in range(rings.size()-1):
		var a_ring: Array = rings[r]
		var b_ring: Array = rings[r+1]
		for i in range(segments):
			_quad(st,a_ring[i],a_ring[i+1],b_ring[i+1],b_ring[i])

	# Soft rear crown cap; front remains open for the void plane.
	var top_center := Vector3(-0.02,0.285,-0.065)
	var last_ring: Array = rings[rings.size()-1]
	for i in range(segments):
		_tri(st,last_ring[i],last_ring[i+1],top_center)

	st.generate_normals()
	return st.commit()

func _make_face_void_mesh() -> ArrayMesh:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a:=Vector3(-0.118,0.070,0.188)
	var b:=Vector3(0.118,0.070,0.188)
	var c:=Vector3(0.100,-0.145,0.188)
	var d:=Vector3(-0.100,-0.145,0.188)
	_quad(st,a,b,c,d)
	st.generate_normals()
	return st.commit()

func _make_hood_tail_mesh() -> ArrayMesh:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a:=Vector3(-0.11,0.17,-0.14)
	var b:=Vector3(0.11,0.17,-0.14)
	var c:=Vector3(0.06,-0.05,-0.26)
	var d:=Vector3(-0.07,-0.08,-0.27)
	var tip:=Vector3(-0.025,-0.23,-0.22)
	_tri(st,a,b,c)
	_tri(st,a,c,d)
	_tri(st,d,c,tip)
	_tri(st,c,b,a)
	_tri(st,d,c,a)
	_tri(st,tip,c,d)
	st.generate_normals()
	return st.commit()

func _make_tabard_mesh(front_sign: float) -> ArrayMesh:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z:=0.13*front_sign
	var a:=Vector3(-0.145,0.01,z)
	var b:=Vector3(0.145,0.01,z)
	var c:=Vector3(0.115,-0.43,z+0.018*front_sign)
	var d:=Vector3(-0.075,-0.50,z+0.014*front_sign)
	var e:=Vector3(-0.14,-0.35,z+0.010*front_sign)
	_tri(st,a,b,c)
	_tri(st,a,c,d)
	_tri(st,a,d,e)
	_tri(st,c,b,a)
	_tri(st,d,c,a)
	_tri(st,e,d,a)
	st.generate_normals()
	return st.commit()

func _make_foot_mesh() -> ArrayMesh:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := [
		Vector3(-0.070,-0.035,-0.085),Vector3(0.070,-0.035,-0.085),
		Vector3(0.078,-0.035,0.165),Vector3(-0.078,-0.035,0.165),
		Vector3(-0.060,0.055,-0.065),Vector3(0.060,0.055,-0.065),
		Vector3(0.065,0.035,0.150),Vector3(-0.065,0.035,0.150)
	]
	_quad(st,pts[0],pts[1],pts[2],pts[3])
	_quad(st,pts[4],pts[7],pts[6],pts[5])
	_quad(st,pts[0],pts[4],pts[5],pts[1])
	_quad(st,pts[1],pts[5],pts[6],pts[2])
	_quad(st,pts[2],pts[6],pts[7],pts[3])
	_quad(st,pts[3],pts[7],pts[4],pts[0])
	st.generate_normals()
	return st.commit()

func _make_diamond_mesh(width: float,height: float) -> ArrayMesh:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top:=Vector3(0,height*0.5,0)
	var right:=Vector3(width*0.5,0,0)
	var bottom:=Vector3(0,-height*0.5,0)
	var left:=Vector3(-width*0.5,0,0)
	_tri(st,top,right,bottom)
	_tri(st,top,bottom,left)
	st.generate_normals()
	return st.commit()

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
