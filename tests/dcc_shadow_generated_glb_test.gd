extends SceneTree

const GENERATED_SHADOW_GLTF := "res://build/dcc_shadow/shadow_game_rig_smoke.glb"
const MIN_BONES := 20
const MAX_BONES := 48
const REQUIRED_IDLE := "SHD_IDLE_COMBAT_01"
const REQUIRED_A1 := "SHD_A1_SWORD_01"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures := 0
	failures += _expect(ResourceLoader.exists(GENERATED_SHADOW_GLTF),"generated Shadow GLB is imported by Godot 4.7.2")
	if failures > 0:
		_finish(failures)
		return

	var packed := load(GENERATED_SHADOW_GLTF) as PackedScene
	failures += _expect(packed != null,"generated Shadow GLB loads as PackedScene")
	if packed == null:
		_finish(failures)
		return

	var instance := packed.instantiate()
	root.add_child(instance)
	await process_frame

	var skeletons: Array[Skeleton3D] = []
	var meshes: Array[MeshInstance3D] = []
	var players: Array[AnimationPlayer] = []
	_collect(instance,skeletons,meshes,players)

	failures += _expect(skeletons.size() == 1,"generated Shadow GLB contains exactly one Skeleton3D")
	failures += _expect(meshes.size() >= 1,"generated Shadow GLB preserves skinned proxy geometry")

	if skeletons.size() == 1:
		var skeleton := skeletons[0]
		var bone_count := skeleton.get_bone_count()
		failures += _expect(
			bone_count >= MIN_BONES and bone_count <= MAX_BONES,
			"Shadow skeleton stays in candidate game-rig envelope (%d..%d, found %d)" %
				[MIN_BONES,MAX_BONES,bone_count]
		)
		failures += _expect(_duplicate_bone_names(skeleton).is_empty(),"Shadow skeleton has unique bone names")

		var skin_stats := _skin_stats(meshes)
		failures += _expect(int(skin_stats["skinned_surface_count"]) >= 1,"Shadow imported surfaces contain bone weights")
		failures += _expect(int(skin_stats["mesh_instances_with_skin"]) >= 1,"Shadow proxy has imported Skin")
		failures += _expect(not bool(skin_stats["uses_8_influences"]),"Shadow remains on 4-influence mobile-compatible path")
		failures += _expect(bool(skin_stats["four_influence_vertex_found"]),"Shadow preserves intentional four-influence probe")
		failures += _expect(bool(skin_stats["bone_weight_array_lengths_valid"]),"Shadow bone/weight arrays match imported influence format")

	var names := _animation_names(players)
	failures += _expect(names.has(REQUIRED_IDLE),"Godot imports semantic Shadow idle action")
	failures += _expect(names.has(REQUIRED_A1),"Godot imports semantic Shadow A1 action")

	print("SHADOW_DCC_GODOT_METRICS skeletons=%d meshes=%d animations=%s" % [
		skeletons.size(),meshes.size(),str(names)
	])

	instance.queue_free()
	await process_frame
	_finish(failures)

func _collect(node: Node,skeletons: Array[Skeleton3D],meshes: Array[MeshInstance3D],players: Array[AnimationPlayer]) -> void:
	if node is Skeleton3D:
		skeletons.append(node as Skeleton3D)
	if node is MeshInstance3D:
		meshes.append(node as MeshInstance3D)
	if node is AnimationPlayer:
		players.append(node as AnimationPlayer)
	for child in node.get_children():
		_collect(child,skeletons,meshes,players)

func _skin_stats(meshes: Array[MeshInstance3D]) -> Dictionary:
	var skinned_surface_count := 0
	var mesh_instances_with_skin := 0
	var uses_8_influences := false
	var four_influence_vertex_found := false
	var bone_weight_array_lengths_valid := true

	for mesh_instance in meshes:
		if mesh_instance.skin != null:
			mesh_instances_with_skin += 1
		var mesh := mesh_instance.mesh
		if mesh == null:
			continue
		for surface in range(mesh.get_surface_count()):
			var arrays := mesh.surface_get_arrays(surface)
			if arrays.size() <= Mesh.ARRAY_WEIGHTS:
				continue
			var vertices = arrays[Mesh.ARRAY_VERTEX]
			var bones = arrays[Mesh.ARRAY_BONES]
			var weights = arrays[Mesh.ARRAY_WEIGHTS]
			if bones == null or weights == null or bones.size() == 0:
				continue
			skinned_surface_count += 1
			var format: int = mesh.surface_get_format(surface)
			var eight := (format & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS) != 0
			uses_8_influences = uses_8_influences or eight
			var influences := 8 if eight else 4
			if bones.size() != vertices.size()*influences or weights.size() != bones.size():
				bone_weight_array_lengths_valid = false
				continue
			for vertex_index in range(vertices.size()):
				var positive := 0
				var base := vertex_index*influences
				for influence_index in range(influences):
					if float(weights[base+influence_index]) > 0.0001:
						positive += 1
				if positive == 4:
					four_influence_vertex_found = true

	return {
		"skinned_surface_count":skinned_surface_count,
		"mesh_instances_with_skin":mesh_instances_with_skin,
		"uses_8_influences":uses_8_influences,
		"four_influence_vertex_found":four_influence_vertex_found,
		"bone_weight_array_lengths_valid":bone_weight_array_lengths_valid,
	}

func _animation_names(players: Array[AnimationPlayer]) -> PackedStringArray:
	var names := PackedStringArray()
	for player in players:
		for animation_name in player.get_animation_list():
			if not names.has(str(animation_name)):
				names.append(str(animation_name))
	return names

func _duplicate_bone_names(skeleton: Skeleton3D) -> PackedStringArray:
	var seen: Dictionary = {}
	var duplicates := PackedStringArray()
	for i in range(skeleton.get_bone_count()):
		var name := skeleton.get_bone_name(i)
		if seen.has(name):
			duplicates.append(name)
		else:
			seen[name]=true
	return duplicates

func _finish(failures: int) -> void:
	if failures == 0:
		print("Shadowborn generated Shadow GLB Godot import: PASS")
		quit(0)
	else:
		push_error("Shadowborn generated Shadow GLB Godot import: %d failure(s)" % failures)
		quit(1)

func _expect(condition: bool,label: String) -> int:
	if condition:
		print("PASS: "+label)
		return 0
	push_error("FAIL: "+label)
	return 1
