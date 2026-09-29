class_name CombatContactProbe
extends RefCounted

const EXPLICIT_SOURCE_MARKERS := {
	&"basic_slash": [&"BladeTip"],
	&"shadow_lunge": [&"BladeTip"],
	&"hound_bite": [&"BiteContact",&"JawContact"],
	&"hound_rend": [&"BiteContact",&"JawContact"]
}
const EXPLICIT_TARGET_MARKERS := [&"CombatImpactTarget",&"ImpactTarget"]

static func sample(attacker_root: Node3D,target_root: Node3D,skill_id: StringName,camera: Camera3D = null) -> Dictionary:
	var result := {
		"phase":"contact",
		"skill_id":String(skill_id),
		"attacker_root_global":attacker_root.global_position,
		"target_root_global":target_root.global_position,
		"root_gap_3d":attacker_root.global_position.distance_to(target_root.global_position),
		"source_found":false,
		"source_kind":"missing",
		"source_name":"",
		"source_global":Vector3.ZERO,
		"target_found":false,
		"target_kind":"missing",
		"target_name":"",
		"target_global":Vector3.ZERO,
		"contact_gap_3d":INF,
		"screen_gap_px":INF,
		"source_behind_camera":false,
		"target_behind_camera":false,
		"acceptance_markers_ready":false
	}

	var source := _source_point(attacker_root,target_root,skill_id)
	if bool(source.get("found",false)):
		result["source_found"] = true
		result["source_kind"] = str(source.get("kind","missing"))
		result["source_name"] = str(source.get("name",""))
		result["source_global"] = source.get("point",Vector3.ZERO)

	var target := _target_point(target_root,result["source_global"] if bool(result["source_found"]) else attacker_root.global_position)
	if bool(target.get("found",false)):
		result["target_found"] = true
		result["target_kind"] = str(target.get("kind","missing"))
		result["target_name"] = str(target.get("name",""))
		result["target_global"] = target.get("point",Vector3.ZERO)

	if bool(result["source_found"]) and bool(result["target_found"]):
		var source_point: Vector3 = result["source_global"]
		var target_point: Vector3 = result["target_global"]
		result["contact_gap_3d"] = source_point.distance_to(target_point)
		if camera != null:
			var source_behind := camera.is_position_behind(source_point)
			var target_behind := camera.is_position_behind(target_point)
			result["source_behind_camera"] = source_behind
			result["target_behind_camera"] = target_behind
			if not source_behind and not target_behind:
				result["screen_gap_px"] = camera.unproject_position(source_point).distance_to(camera.unproject_position(target_point))

	result["acceptance_markers_ready"] = (
		str(result["source_kind"]) == "marker"
		and str(result["target_kind"]) == "marker"
	)
	return result

static func recovery_sample(actor_root: Node3D,home_position: Vector3,actor_id: String) -> Dictionary:
	return {
		"phase":"recovery",
		"actor_id":actor_id,
		"actor_global":actor_root.global_position,
		"home_local":home_position,
		"recovery_root_error":actor_root.position.distance_to(home_position)
	}

static func _source_point(attacker_root: Node3D,target_root: Node3D,skill_id: StringName) -> Dictionary:
	var marker_names: Array = EXPLICIT_SOURCE_MARKERS.get(skill_id,[])
	for marker_name_variant in marker_names:
		var marker_name := String(marker_name_variant)
		var marker := attacker_root.find_child(marker_name,true,false) as Node3D
		if marker != null:
			return {"found":true,"kind":"marker","name":marker_name,"point":marker.global_position}

	if skill_id == &"hound_bite" or skill_id == &"hound_rend":
		var jaw_point := _bone_origin_world(attacker_root,["DEF-jaw","Jaw","jaw"])
		if bool(jaw_point.get("found",false)):
			return jaw_point

	if skill_id == &"basic_slash" or skill_id == &"shadow_lunge":
		var weapon := attacker_root.find_child("ShadowbornWeapon",true,false) as Node3D
		if weapon != null:
			var bounds := _visible_world_bounds(weapon)
			if bool(bounds.get("found",false)):
				return {
					"found":true,
					"kind":"weapon_bounds",
					"name":"ShadowbornWeapon visible bounds",
					"point":_closest_point_on_aabb(bounds["aabb"],target_root.global_position)
				}

	var attacker_bounds := _visible_world_bounds(attacker_root)
	if bool(attacker_bounds.get("found",false)):
		return {
			"found":true,
			"kind":"actor_bounds",
			"name":"attacker visible bounds",
			"point":_closest_point_on_aabb(attacker_bounds["aabb"],target_root.global_position)
		}
	return {"found":false}

static func _target_point(target_root: Node3D,source_point: Vector3) -> Dictionary:
	for marker_name_variant in EXPLICIT_TARGET_MARKERS:
		var marker_name := String(marker_name_variant)
		var marker := target_root.find_child(marker_name,true,false) as Node3D
		if marker != null:
			return {"found":true,"kind":"marker","name":marker_name,"point":marker.global_position}

	var chest := _bone_origin_world(target_root,["DEF-spine.007","Chest","chest","Spine2","spine_03"])
	if bool(chest.get("found",false)):
		chest["kind"] = "bone_origin"
		return chest

	var bounds := _visible_world_bounds(target_root)
	if bool(bounds.get("found",false)):
		return {
			"found":true,
			"kind":"target_bounds",
			"name":"target visible bounds",
			"point":_closest_point_on_aabb(bounds["aabb"],source_point)
		}
	return {"found":false}

static func _bone_origin_world(root: Node,skeleton_names: Array) -> Dictionary:
	var skeleton := _find_skeleton(root)
	if skeleton == null:
		return {"found":false}
	for bone_name_variant in skeleton_names:
		var bone_name := String(bone_name_variant)
		var bone_index := skeleton.find_bone(bone_name)
		if bone_index >= 0:
			var pose := skeleton.get_bone_global_pose(bone_index)
			return {
				"found":true,
				"kind":"bone_origin",
				"name":bone_name,
				"point":skeleton.global_transform * pose.origin
			}
	return {"found":false}

static func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null

static func _visible_world_bounds(root: Node3D) -> Dictionary:
	var found_any := false
	var min_v := Vector3.ZERO
	var max_v := Vector3.ZERO
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node := stack.pop_back()
		if node is MeshInstance3D:
			var mesh_instance := node as MeshInstance3D
			if mesh_instance.mesh != null and mesh_instance.is_visible_in_tree():
				for corner in _aabb_corners(mesh_instance.get_aabb()):
					var world_point := mesh_instance.to_global(corner)
					if not found_any:
						min_v = world_point
						max_v = world_point
						found_any = true
					else:
						min_v = min_v.min(world_point)
						max_v = max_v.max(world_point)
		for child in node.get_children():
			stack.append(child)
	if not found_any:
		return {"found":false}
	return {"found":true,"aabb":AABB(min_v,max_v-min_v)}

static func _closest_point_on_aabb(aabb: AABB,point: Vector3) -> Vector3:
	var min_v := aabb.position
	var max_v := aabb.position+aabb.size
	return Vector3(
		clampf(point.x,min_v.x,max_v.x),
		clampf(point.y,min_v.y,max_v.y),
		clampf(point.z,min_v.z,max_v.z)
	)

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
