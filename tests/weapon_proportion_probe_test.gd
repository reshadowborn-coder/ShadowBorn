extends SceneTree

const CharacterFactory = preload("res://scripts/presentation/character_factory.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var shadow := CharacterFactory.create_shadow(false)
	var sword := CharacterFactory.create_sword_prop()
	root.add_child(shadow)
	root.add_child(sword)
	await process_frame

	var shadow_bounds := _combined_bounds(shadow)
	var sword_bounds := _combined_bounds(sword)
	var shadow_height := shadow_bounds.size.y
	var sword_length := max(sword_bounds.size.x,max(sword_bounds.size.y,sword_bounds.size.z))
	var ratio := sword_length/max(shadow_height,0.0001)

	print("WEAPON_PROPORTION_PROBE shadow_bounds=",shadow_bounds)
	print("WEAPON_PROPORTION_PROBE sword_bounds=",sword_bounds)
	print("WEAPON_PROPORTION_PROBE shadow_height=%.4f sword_long_axis=%.4f ratio=%.4f" % [shadow_height,sword_length,ratio])

	var failures := 0
	if shadow_height <= 0.5:
		push_error("Shadow imported bounds are unexpectedly small/nonexistent")
		failures += 1
	if sword_length <= 0.2:
		push_error("Sword imported bounds are unexpectedly small/nonexistent")
		failures += 1

	shadow.queue_free()
	sword.queue_free()
	await process_frame
	if failures == 0:
		print("Shadowborn weapon proportion probe: PASS")
		quit(0)
	else:
		quit(1)

func _combined_bounds(root3d: Node3D) -> AABB:
	var has_point := false
	var min_v := Vector3.ZERO
	var max_v := Vector3.ZERO
	var stack: Array[Node] = [root3d]
	while not stack.is_empty():
		var node := stack.pop_back()
		if node is MeshInstance3D:
			var mi := node as MeshInstance3D
			if mi.mesh != null:
				var aabb := mi.get_aabb()
				for corner in _aabb_corners(aabb):
					var world_point := mi.to_global(corner)
					var p := root3d.to_local(world_point)
					if not has_point:
						min_v = p
						max_v = p
						has_point = true
					else:
						min_v = min_v.min(p)
						max_v = max_v.max(p)
		for child in node.get_children():
			stack.append(child)
	if not has_point:
		return AABB()
	return AABB(min_v,max_v-min_v)

func _aabb_corners(aabb: AABB) -> Array[Vector3]:
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
