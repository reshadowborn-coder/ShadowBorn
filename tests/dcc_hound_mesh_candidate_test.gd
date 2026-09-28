extends SceneTree

const CANDIDATE_GLTF := "res://build/dcc_hound/grave_hound_mesh_candidate.glb"
const BODY_PREFIX := "HND_BODY_CANDIDATE"
const REQUIRED_IDLE := "HND_IDLE_LOW_01"
const REQUIRED_BITE := "HND_BITE_01"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures := 0
	failures += _expect(ResourceLoader.exists(CANDIDATE_GLTF),"original Hound mesh candidate is imported by Godot 4.7.2")
	if failures > 0:
		_finish(failures)
		return

	var packed := load(CANDIDATE_GLTF) as PackedScene
	failures += _expect(packed != null,"Hound mesh candidate loads as PackedScene")
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

	failures += _expect(skeletons.size() == 1,"Hound mesh candidate contains one Skeleton3D")
	var body: MeshInstance3D = null
	for mesh_instance in meshes:
		if mesh_instance.name.begins_with(BODY_PREFIX):
			body = mesh_instance
			break
	failures += _expect(body != null,"Godot preserves HND_BODY_CANDIDATE mesh")

	if body != null and body.mesh != null:
		var vertex_count := 0
		var surface_count := body.mesh.get_surface_count()
		var uses_8 := false
		var max_positive := 0
		var all_vertices_weighted := true
		for surface in range(surface_count):
			var arrays := body.mesh.surface_get_arrays(surface)
			var vertices = arrays[Mesh.ARRAY_VERTEX]
			var bones = arrays[Mesh.ARRAY_BONES]
			var weights = arrays[Mesh.ARRAY_WEIGHTS]
			vertex_count += vertices.size()
			var format: int = body.mesh.surface_get_format(surface)
			var eight := (format & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS) != 0
			uses_8 = uses_8 or eight
			var influences := 8 if eight else 4
			if bones == null or weights == null or bones.size() != vertices.size()*influences:
				all_vertices_weighted = false
				continue
			for vertex_index in range(vertices.size()):
				var positive := 0
				var base := vertex_index*influences
				for influence_index in range(influences):
					if float(weights[base+influence_index]) > 0.0001:
						positive += 1
				max_positive = maxi(max_positive,positive)
				if positive == 0:
					all_vertices_weighted = false

		var aabb := body.mesh.get_aabb()
		failures += _expect(vertex_count >= 500,"Hound candidate has substantive authored geometry (found %d imported vertices)" % vertex_count)
		# Do not invent a platform vertex ceiling here. glTF can split vertices at
		# normals/UVs/skin boundaries; record the Godot runtime count and set the
		# shipping budget only after fixed-camera iPhone profiling.
		failures += _expect(body.skin != null,"Hound candidate has imported Skin")
		failures += _expect(not uses_8,"Hound candidate remains on four-influence path")
		failures += _expect(max_positive <= 4,"Hound candidate uses at most four positive influences per vertex")
		failures += _expect(all_vertices_weighted,"Hound candidate has no unweighted imported vertices")
		failures += _expect(aabb.size.y > 0.45,"Hound candidate has meaningful vertical canine mass")
		failures += _expect(aabb.size.z > 0.90,"Hound candidate has meaningful head-to-tail length")
		failures += _expect(aabb.size.x > 0.20,"Hound candidate has meaningful chest/pelvis width")

		var names := _animation_names(players)
		failures += _expect(names.has(REQUIRED_IDLE),"Hound candidate imports semantic idle action")
		failures += _expect(names.has(REQUIRED_BITE),"Hound candidate imports semantic bite action")

		print("HOUND_MESH_CANDIDATE_METRICS vertices=%d surfaces=%d aabb=%s skin=%s max_positive_influences=%d animations=%s" % [
			vertex_count,
			surface_count,
			str(aabb.size),
			str(body.skin != null),
			max_positive,
			str(names)
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

func _animation_names(players: Array[AnimationPlayer]) -> PackedStringArray:
	var names := PackedStringArray()
	for player in players:
		for animation_name in player.get_animation_list():
			if not names.has(str(animation_name)):
				names.append(str(animation_name))
	return names

func _finish(failures: int) -> void:
	if failures == 0:
		print("Shadowborn original Hound mesh candidate Godot import: PASS")
		quit(0)
	else:
		push_error("Shadowborn original Hound mesh candidate Godot import: %d failure(s)" % failures)
		quit(1)

func _expect(condition: bool,label: String) -> int:
	if condition:
		print("PASS: "+label)
		return 0
	push_error("FAIL: "+label)
	return 1
