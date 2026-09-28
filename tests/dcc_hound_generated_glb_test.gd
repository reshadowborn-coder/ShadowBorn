extends SceneTree

const GENERATED_HOUND_GLTF := "res://build/dcc_hound/grave_hound_game_rig_smoke.glb"
const MIN_GAME_BONES := 32
const MAX_GAME_BONES := 48
const REQUIRED_BONE := "DEF-jaw"
const REQUIRED_IDLE_ACTION := "HND_IDLE_LOW_01"
const REQUIRED_BITE_ACTION := "HND_BITE_01"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures := 0
	failures += _expect(ResourceLoader.exists(GENERATED_HOUND_GLTF),"generated Hound GLB is imported by Godot 4.7.2")
	if failures > 0:
		_finish(failures)
		return

	var packed := load(GENERATED_HOUND_GLTF) as PackedScene
	failures += _expect(packed != null,"generated Hound GLB loads as PackedScene")
	if packed == null:
		_finish(failures)
		return

	var instance := packed.instantiate()
	root.add_child(instance)
	await process_frame

	var skeletons: Array[Skeleton3D] = []
	var meshes: Array[MeshInstance3D] = []
	var animation_players: Array[AnimationPlayer] = []
	_collect_nodes(instance,skeletons,meshes,animation_players)
	failures += _expect(skeletons.size() == 1,"generated Hound GLB contains exactly one Skeleton3D")
	failures += _expect(meshes.size() >= 1,"generated Hound GLB preserves skinned proxy geometry")

	if skeletons.size() == 1:
		var skeleton := skeletons[0]
		var bone_count := skeleton.get_bone_count()
		failures += _expect(
			bone_count >= MIN_GAME_BONES and bone_count <= MAX_GAME_BONES,
			"Godot Hound skeleton stays in candidate game-rig envelope (%d..%d, found %d)" %
				[MIN_GAME_BONES,MAX_GAME_BONES,bone_count]
		)
		failures += _expect(
			skeleton.find_bone(REQUIRED_BONE) >= 0,
			"Godot Hound skeleton preserves required %s bone" % REQUIRED_BONE
		)

		var duplicate_names := _duplicate_bone_names(skeleton)
		failures += _expect(
			duplicate_names.is_empty(),
			"Godot Hound skeleton has unique bone names%s" %
				[(" (duplicates: %s)" % str(duplicate_names)) if not duplicate_names.is_empty() else ""]
		)

		var skin_stats := _skin_stats(meshes)
		failures += _expect(int(skin_stats["skinned_surface_count"]) >= 1,"Godot imported Hound proxy surfaces contain bone weights")
		failures += _expect(int(skin_stats["mesh_instances_with_skin"]) >= 1,"Godot Hound proxy has an imported Skin resource")
		failures += _expect(not bool(skin_stats["uses_8_influences"]),"Hound candidate stays on the 4-influence mobile-compatible mesh path")
		failures += _expect(bool(skin_stats["four_influence_vertex_found"]),"Godot preserves the intentional four-influence skin probe")
		failures += _expect(bool(skin_stats["bone_weight_array_lengths_valid"]),"Godot bone/weight arrays match four influences per vertex")

		var animation_stats := _animation_stats(animation_players)
		failures += _expect(bool(animation_stats["required_actions_found"]),"Godot imports semantic Hound idle and bite actions by name")
		failures += _expect(bool(animation_stats["bite_has_jaw_track"]),"HND_BITE_01 contains an imported DEF-jaw animation track")
		failures += _expect(bool(animation_stats["bite_has_body_track"]),"HND_BITE_01 contains imported torso/neck deformation, not jaw-only motion")
		failures += _expect(float(animation_stats["bite_length"]) > 0.05,"HND_BITE_01 has non-zero imported duration")

		print("HOUND_DCC_GODOT_METRICS bone_count=%d jaw_index=%d skeleton=%s mesh_instances=%d skinned_surfaces=%d four_influence_probe=%s animations=%s bite_length=%.3f bite_jaw_track=%s" % [
			bone_count,
			skeleton.find_bone(REQUIRED_BONE),
			skeleton.name,
			meshes.size(),
			int(skin_stats["skinned_surface_count"]),
			str(bool(skin_stats["four_influence_vertex_found"])),
			str(animation_stats["animation_names"]),
			float(animation_stats["bite_length"]),
			str(bool(animation_stats["bite_has_jaw_track"]))
		])

	instance.queue_free()
	await process_frame
	_finish(failures)

func _collect_nodes(node: Node,skeletons: Array[Skeleton3D],meshes: Array[MeshInstance3D],animation_players: Array[AnimationPlayer]) -> void:
	if node is Skeleton3D:
		skeletons.append(node as Skeleton3D)
	if node is MeshInstance3D:
		meshes.append(node as MeshInstance3D)
	if node is AnimationPlayer:
		animation_players.append(node as AnimationPlayer)
	for child in node.get_children():
		_collect_nodes(child,skeletons,meshes,animation_players)

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
			var eight: bool = (format & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS) != 0
			uses_8_influences = uses_8_influences or eight
			var influences_per_vertex := 8 if eight else 4
			if bones.size() != vertices.size()*influences_per_vertex or weights.size() != bones.size():
				bone_weight_array_lengths_valid = false
				continue

			for vertex_index in range(vertices.size()):
				var positive := 0
				var base := vertex_index*influences_per_vertex
				for influence_index in range(influences_per_vertex):
					if float(weights[base+influence_index]) > 0.0001:
						positive += 1
				if positive == 4:
					four_influence_vertex_found = true

	return {
		"skinned_surface_count": skinned_surface_count,
		"mesh_instances_with_skin": mesh_instances_with_skin,
		"uses_8_influences": uses_8_influences,
		"four_influence_vertex_found": four_influence_vertex_found,
		"bone_weight_array_lengths_valid": bone_weight_array_lengths_valid,
	}

func _animation_stats(players: Array[AnimationPlayer]) -> Dictionary:
	var names := PackedStringArray()
	var bite_has_jaw_track := false
	var bite_has_body_track := false
	var bite_length := 0.0

	for player in players:
		for animation_name in player.get_animation_list():
			if not names.has(str(animation_name)):
				names.append(str(animation_name))
			if str(animation_name) != REQUIRED_BITE_ACTION:
				continue
			var animation := player.get_animation(animation_name)
			if animation == null:
				continue
			bite_length = maxf(bite_length,animation.length)
			for track_index in range(animation.get_track_count()):
				var track_path := str(animation.track_get_path(track_index))
				if "DEF-jaw" in track_path:
					bite_has_jaw_track = true
				if "DEF-spine.008" in track_path or "DEF-spine.009" in track_path or "DEF-spine.010" in track_path:
					bite_has_body_track = true

	var required_found := true
	for required_name in [REQUIRED_IDLE_ACTION,REQUIRED_BITE_ACTION]:
		if not names.has(required_name):
			required_found = false

	return {
		"animation_names": names,
		"required_actions_found": required_found,
		"bite_has_jaw_track": bite_has_jaw_track,
		"bite_has_body_track": bite_has_body_track,
		"bite_length": bite_length,
	}


func _duplicate_bone_names(skeleton: Skeleton3D) -> PackedStringArray:
	var seen: Dictionary = {}
	var duplicates := PackedStringArray()
	for i in range(skeleton.get_bone_count()):
		var bone_name := skeleton.get_bone_name(i)
		if seen.has(bone_name):
			duplicates.append(bone_name)
		else:
			seen[bone_name] = true
	return duplicates

func _finish(failures: int) -> void:
	if failures == 0:
		print("Shadowborn generated Hound GLB Godot import: PASS")
		quit(0)
	else:
		push_error("Shadowborn generated Hound GLB Godot import: %d failure(s)" % failures)
		quit(1)

func _expect(condition: bool,label: String) -> int:
	if condition:
		print("PASS: "+label)
		return 0
	push_error("FAIL: "+label)
	return 1
