extends SceneTree

const CharacterFactory = preload("res://scripts/presentation/character_factory.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var shadow: Node3D = CharacterFactory.create_shadow(false)
	var sword: Node3D = CharacterFactory.create_sword_prop()
	root.add_child(shadow)
	root.add_child(sword)
	await process_frame

	var shadow_bounds: AABB = _combined_bounds(shadow)
	var sword_bounds: AABB = _combined_bounds(sword)
	var shadow_height: float = shadow_bounds.size.y
	var sword_length: float = maxf(sword_bounds.size.x,maxf(sword_bounds.size.y,sword_bounds.size.z))
	var raw_ratio: float = sword_length/maxf(shadow_height,0.0001)
	var sword_tier := str(sword.get_meta("shadowborn_visual_tier",""))
	var presented_ratio: float = raw_ratio if sword_tier == "production" else sword_length*CharacterFactory.DEV_SWORD_PRESENTATION_SCALE/maxf(shadow_height,0.0001)

	print("WEAPON_PROPORTION_PROBE shadow_bounds=",shadow_bounds)
	print("WEAPON_PROPORTION_PROBE sword_bounds=",sword_bounds)
	print("WEAPON_PROPORTION_PROBE shadow_height=%.4f sword_long_axis=%.4f raw_ratio=%.4f presented_ratio=%.4f" % [shadow_height,sword_length,raw_ratio,presented_ratio])

	var failures := 0
	if shadow_height <= 0.5:
		push_error("Shadow imported bounds are unexpectedly small/nonexistent")
		failures += 1
	if sword_length <= 0.2:
		push_error("Sword imported bounds are unexpectedly small/nonexistent")
		failures += 1
	if presented_ratio < 0.45 or presented_ratio > 0.52:
		push_error("Starter sword/body ratio escaped the 45-52%% visual target: %.4f" % presented_ratio)
		failures += 1

	if sword_tier == "production":
		var grip := sword.find_child("Grip",true,false) as Node3D
		var blade_tip := sword.find_child("BladeTip",true,false) as Node3D
		if grip == null:
			push_error("Production starter sword is missing authored Grip marker")
			failures += 1
		elif grip.position.length() > 0.001:
			push_error("Production Grip marker is not at the authored hand origin: %s" % grip.position)
			failures += 1
		if blade_tip == null:
			push_error("Production starter sword is missing BladeTip marker")
			failures += 1
		elif blade_tip.position.y < 0.74 or blade_tip.position.y > 0.79:
			push_error("Production BladeTip marker escaped shortened authored length: %s" % blade_tip.position)
			failures += 1

	var armed_shadow: Node3D = CharacterFactory.create_shadow(true)
	root.add_child(armed_shadow)
	await process_frame
	var attached := armed_shadow.find_child("ShadowbornWeapon",true,false) as Node3D
	if attached == null:
		push_error("Attached debug sword missing")
		failures += 1
	else:
		var tier := str(attached.get_meta("shadowborn_visual_tier",""))
		if tier == "production":
			var mount := attached.get_parent() as Node3D
			if mount == null or mount.name != "WeaponGripMount":
				push_error("Production sword is not attached through WeaponGripMount")
				failures += 1
			elif not mount.rotation_degrees.is_equal_approx(CharacterFactory.PRODUCTION_SWORD_WRIST_ROTATION):
				push_error("Production sword mount rotation drifted: %s" % mount.rotation_degrees)
				failures += 1
			if attached.position.length() > 0.001:
				push_error("Production sword root is not aligned to authored Grip: %s" % attached.position)
				failures += 1
		elif tier == "debug_vendor":
			if attached.position.length() > 0.001:
				push_error("Debug sword grip root is offset from Wrist.R: %s" % attached.position)
				failures += 1
			if not attached.rotation_degrees.is_equal_approx(CharacterFactory.DEV_SWORD_WRIST_ROTATION):
				push_error("Debug sword wrist rotation drifted: %s" % attached.rotation_degrees)
				failures += 1

	shadow.queue_free()
	sword.queue_free()
	armed_shadow.queue_free()
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
		var node: Node = stack.pop_back() as Node
		if node is MeshInstance3D:
			var mi := node as MeshInstance3D
			# Proportion acceptance must measure what the player can actually see.
			# Hidden vendor carrier meshes remain in the rig hierarchy but must not
			# inflate Shadow's visible body bounds.
			if mi.mesh != null and mi.is_visible_in_tree():
				var aabb: AABB = mi.get_aabb()
				for corner in _aabb_corners(aabb):
					var world_point: Vector3 = mi.to_global(corner)
					var p: Vector3 = root3d.to_local(world_point)
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
