class_name CharacterAssetAudit
extends RefCounted

# Runtime/DCC handoff audit. These numbers are intentionally collected from
# Godot-imported resources, because UV seams, hard normals, material splits and
# import processing can make DCC face counts differ from the actual runtime mesh.

static func audit_scene(path: String, scene_parent: Node = null) -> Dictionary:
	var report := _empty_report(path)
	if not ResourceLoader.exists(path):
		report["status"] = "missing"
		return report
	var packed := load(path) as PackedScene
	if packed == null:
		report["status"] = "not_packed_scene"
		return report
	var instance := packed.instantiate() as Node3D
	if instance == null:
		report["status"] = "not_node3d"
		return report

	var owned_parent := false
	if scene_parent != null:
		scene_parent.add_child(instance)
	else:
		var tree := Engine.get_main_loop() as SceneTree
		if tree == null:
			instance.free()
			report["status"] = "no_scene_tree"
			return report
		var holder := Node3D.new()
		holder.name = "CharacterAssetAuditHolder"
		tree.root.add_child(holder)
		holder.add_child(instance)
		scene_parent = holder
		owned_parent = true

	_report_node(instance,instance,report)
	report["animation_names"] = Array((report["animation_name_set"] as Dictionary).keys())
	report.erase("animation_name_set")
	report["unique_material_count"] = (report["material_ids"] as Dictionary).size()
	report.erase("material_ids")
	if bool(report["has_bounds"]):
		var min_v: Vector3 = report["bounds_min"]
		var max_v: Vector3 = report["bounds_max"]
		report["visual_size_m"] = max_v-min_v
		report["visual_height_m"] = (max_v-min_v).y
	else:
		report["visual_size_m"] = Vector3.ZERO
		report["visual_height_m"] = 0.0
	report.erase("has_bounds")
	report.erase("bounds_min")
	report.erase("bounds_max")
	report["status"] = "ok"

	instance.queue_free()
	if owned_parent and scene_parent != null:
		scene_parent.queue_free()
	return report

static func _empty_report(path: String) -> Dictionary:
	return {
		"source_path":path,
		"status":"unscanned",
		"mesh_instance_count":0,
		"surface_count":0,
		"vertex_count":0,
		"index_count":0,
		"triangle_count":0,
		"material_slot_count":0,
		"material_ids":{},
		"skeleton_count":0,
		"bone_count_total":0,
		"bone_count_max":0,
		"skinned_mesh_count":0,
		"animation_player_count":0,
		"animation_count":0,
		"animation_name_set":{},
		"has_bounds":false,
		"bounds_min":Vector3.ZERO,
		"bounds_max":Vector3.ZERO
	}

static func _report_node(root3d: Node3D,node: Node,report: Dictionary) -> void:
	if node is MeshInstance3D:
		_report_mesh(root3d,node as MeshInstance3D,report)
	elif node is Skeleton3D:
		var skeleton := node as Skeleton3D
		var bones := skeleton.get_bone_count()
		report["skeleton_count"] = int(report["skeleton_count"])+1
		report["bone_count_total"] = int(report["bone_count_total"])+bones
		report["bone_count_max"] = maxi(int(report["bone_count_max"]),bones)
	elif node is AnimationPlayer:
		var player := node as AnimationPlayer
		report["animation_player_count"] = int(report["animation_player_count"])+1
		for animation_name in player.get_animation_list():
			var names: Dictionary = report["animation_name_set"]
			names[str(animation_name)] = true

	for child in node.get_children():
		_report_node(root3d,child,report)

static func _report_mesh(root3d: Node3D,mesh_instance: MeshInstance3D,report: Dictionary) -> void:
	var mesh := mesh_instance.mesh
	if mesh == null:
		return
	report["mesh_instance_count"] = int(report["mesh_instance_count"])+1
	if not mesh_instance.skeleton.is_empty():
		report["skinned_mesh_count"] = int(report["skinned_mesh_count"])+1

	var surfaces := mesh.get_surface_count()
	report["surface_count"] = int(report["surface_count"])+surfaces
	report["material_slot_count"] = int(report["material_slot_count"])+surfaces
	for surface_idx in range(surfaces):
		var arrays := mesh.surface_get_arrays(surface_idx)
		if arrays.size() > Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX] != null:
			var vertices = arrays[Mesh.ARRAY_VERTEX]
			report["vertex_count"] = int(report["vertex_count"])+vertices.size()
		var surface_indices := 0
		if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] != null:
			var indices = arrays[Mesh.ARRAY_INDEX]
			surface_indices = indices.size()
			report["index_count"] = int(report["index_count"])+surface_indices
		if mesh.surface_get_primitive_type(surface_idx) == Mesh.PRIMITIVE_TRIANGLES:
			if surface_indices > 0:
				report["triangle_count"] = int(report["triangle_count"])+surface_indices/3
			elif arrays.size() > Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX] != null:
				report["triangle_count"] = int(report["triangle_count"])+arrays[Mesh.ARRAY_VERTEX].size()/3

		var material := mesh_instance.get_surface_override_material(surface_idx)
		if material == null:
			material = mesh.surface_get_material(surface_idx)
		if material != null:
			var ids: Dictionary = report["material_ids"]
			ids[material.get_instance_id()] = true

	if mesh_instance.is_visible_in_tree():
		var aabb := mesh_instance.get_aabb()
		for corner in _aabb_corners(aabb):
			var p := root3d.to_local(mesh_instance.to_global(corner))
			_accumulate_bound(report,p)

static func _accumulate_bound(report: Dictionary,p: Vector3) -> void:
	if not bool(report["has_bounds"]):
		report["has_bounds"] = true
		report["bounds_min"] = p
		report["bounds_max"] = p
		return
	report["bounds_min"] = (report["bounds_min"] as Vector3).min(p)
	report["bounds_max"] = (report["bounds_max"] as Vector3).max(p)

static func _aabb_corners(aabb: AABB) -> Array[Vector3]:
	var p := aabb.position
	var s := aabb.size
	return [
		p,
		p+Vector3(s.x,0,0),
		p+Vector3(0,s.y,0),
		p+Vector3(0,0,s.z),
		p+Vector3(s.x,s.y,0),
		p+Vector3(s.x,0,s.z),
		p+Vector3(0,s.y,s.z),
		p+s
	]

static func concise(report: Dictionary) -> String:
	return "%s status=%s meshes=%d surfaces=%d vertices=%d triangles=%d materials=%d skeletons=%d bones_max=%d skinned=%d animations=%d height=%.3fm" % [
		str(report.get("source_path","")),
		str(report.get("status","")),
		int(report.get("mesh_instance_count",0)),
		int(report.get("surface_count",0)),
		int(report.get("vertex_count",0)),
		int(report.get("triangle_count",0)),
		int(report.get("unique_material_count",0)),
		int(report.get("skeleton_count",0)),
		int(report.get("bone_count_max",0)),
		int(report.get("skinned_mesh_count",0)),
		int((report.get("animation_names",[]) as Array).size()),
		float(report.get("visual_height_m",0.0))
	]
