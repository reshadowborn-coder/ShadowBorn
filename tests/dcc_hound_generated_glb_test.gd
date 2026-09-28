extends SceneTree

const GENERATED_HOUND_GLTF := "res://build/dcc_hound/grave_hound_game_rig_smoke.glb"
const MIN_GAME_BONES := 32
const MAX_GAME_BONES := 48
const REQUIRED_BONE := "DEF-jaw"

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
	_collect_skeletons(instance,skeletons)
	failures += _expect(skeletons.size() == 1,"generated Hound GLB contains exactly one Skeleton3D")

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

		print("HOUND_DCC_GODOT_METRICS bone_count=%d jaw_index=%d skeleton=%s" % [
			bone_count,
			skeleton.find_bone(REQUIRED_BONE),
			skeleton.name
		])

	instance.queue_free()
	await process_frame
	_finish(failures)

func _collect_skeletons(node: Node,skeletons: Array[Skeleton3D]) -> void:
	if node is Skeleton3D:
		skeletons.append(node as Skeleton3D)
	for child in node.get_children():
		_collect_skeletons(child,skeletons)

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
