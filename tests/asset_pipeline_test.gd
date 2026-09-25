extends SceneTree

const Factory = preload("res://scripts/presentation/character_factory.gd")

func _init() -> void:
	var failures := 0
	failures += _check_scene("res://assets/vendor/quaternius/shadow_adventurer.gltf",["Idle_Sword","Sword_Slash","HitRecieve","Death","Interact"],"Shadow dev asset")
	failures += _check_scene("res://assets/vendor/quaternius/grave_wolf.gltf",["Idle","Attack","Idle_HitReact1","Death"],"Hound dev asset")
	failures += _check_resource("res://assets/vendor/quaternius/shadow_sword.gltf","Sword dev asset")

	if failures == 0:
		print("Shadowborn asset pipeline: PASS")
		quit(0)
	else:
		push_error("Shadowborn asset pipeline: %d failure(s)" % failures)
		quit(1)

func _check_scene(path: String,required: Array[String],label: String) -> int:
	if not ResourceLoader.exists(path):
		push_error("%s missing: %s" % [label,path])
		return 1
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("%s failed to load as PackedScene" % label)
		return 1
	var instance := packed.instantiate()
	var names := Factory.animation_names(instance)
	var missing: Array[String] = []
	for name in required:
		if StringName(name) not in names:
			missing.append(name)
	instance.free()
	if not missing.is_empty():
		push_error("%s missing animations: %s" % [label,", ".join(missing)])
		return 1
	print("PASS: %s (%d animations)" % [label,names.size()])
	return 0

func _check_resource(path: String,label: String) -> int:
	if not ResourceLoader.exists(path):
		push_error("%s missing: %s" % [label,path])
		return 1
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("%s failed to load as PackedScene" % label)
		return 1
	var instance := packed.instantiate()
	instance.free()
	print("PASS: %s" % label)
	return 0
