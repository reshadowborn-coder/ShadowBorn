extends SceneTree

const CANDIDATE_GLTF := "res://build/dcc_shadow/shadow_mesh_candidate.glb"
const REQUIRED_LAYERS := [
	"SHD_BODY_CANDIDATE",
	"SHD_HOOD_CANDIDATE",
	"SHD_FACE_VOID_CANDIDATE",
	"SHD_HIP_CLOTH_CANDIDATE",
]
const REQUIRED_IDLE := "SHD_IDLE_COMBAT_01"
const REQUIRED_A1 := "SHD_A1_SWORD_01"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures := 0
	failures += _expect(ResourceLoader.exists(CANDIDATE_GLTF),"original Shadow mesh candidate is imported by Godot 4.7.2")
	if failures > 0:
		_finish(failures)
		return

	var packed := load(CANDIDATE_GLTF) as PackedScene
	failures += _expect(packed != null,"Shadow candidate loads as PackedScene")
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

	failures += _expect(skeletons.size() == 1,"Shadow candidate contains exactly one Skeleton3D")
	var names := PackedStringArray()
	for mesh in meshes:
		names.append(mesh.name)

	for required in REQUIRED_LAYERS:
		var found := false
		for name in names:
			if str(name).begins_with(required):
				found = true
				break
		failures += _expect(found,"Shadow candidate preserves mesh layer %s" % required)

	var total_vertices := 0
	var skinned_meshes := 0
	var uses_8 := false
	var max_positive := 0
	for mesh_instance in meshes:
		if mesh_instance.skin != null:
			skinned_meshes += 1
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
			total_vertices += vertices.size()
			var format: int = mesh.surface_get_format(surface)
			var eight := (format & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS) != 0
			uses_8 = uses_8 or eight
			var influences := 8 if eight else 4
			if bones == null or weights == null or bones.size() != vertices.size()*influences:
				continue
			for vertex_index in range(vertices.size()):
				var positive := 0
				var base := vertex_index*influences
				for influence_index in range(influences):
					if float(weights[base+influence_index]) > 0.0001:
						positive += 1
				max_positive = maxi(max_positive,positive)

	failures += _expect(skinned_meshes >= 4,"Shadow candidate keeps all authored layers skinned")
	failures += _expect(total_vertices >= 500,"Shadow candidate has substantive imported geometry")
	failures += _expect(not uses_8,"Shadow candidate stays on four-influence path")
	failures += _expect(max_positive <= 4,"Shadow candidate uses at most four positive influences per vertex")

	var animation_names := PackedStringArray()
	for player in players:
		for animation_name in player.get_animation_list():
			if not animation_names.has(str(animation_name)):
				animation_names.append(str(animation_name))
	failures += _expect(animation_names.has(REQUIRED_IDLE),"Shadow candidate imports semantic idle")
	failures += _expect(animation_names.has(REQUIRED_A1),"Shadow candidate imports semantic A1")

	print("SHADOW_MESH_CANDIDATE_METRICS skeletons=%d meshes=%d skinned=%d vertices=%d max_influences=%d animations=%s" % [
		skeletons.size(),meshes.size(),skinned_meshes,total_vertices,max_positive,str(animation_names)
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

func _finish(failures: int) -> void:
	if failures == 0:
		print("Shadowborn original Shadow mesh candidate Godot import: PASS")
		quit(0)
	else:
		push_error("Shadowborn original Shadow mesh candidate Godot import: %d failure(s)" % failures)
		quit(1)

func _expect(condition: bool,label: String) -> int:
	if condition:
		print("PASS: "+label)
		return 0
	push_error("FAIL: "+label)
	return 1
