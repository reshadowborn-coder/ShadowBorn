extends SceneTree

const Factory = preload("res://scripts/presentation/character_factory.gd")

func _init() -> void:
	var failures := 0
	failures += _check_scene("res://assets/vendor/quaternius/shadow_adventurer.gltf",["Idle_Sword","Sword_Slash","Roll","HitRecieve","Death","Interact"],"Shadow dev asset")
	failures += _check_scene("res://assets/vendor/quaternius/grave_wolf.gltf",["Idle","Attack","Idle_HitReact1","Death"],"Hound dev asset")
	failures += _check_resource("res://assets/vendor/quaternius/shadow_sword.gltf","Sword dev asset")
	failures += _check_hound_identity()

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

func _check_hound_identity() -> int:
	var hound := Factory.create_hound()
	if hound == null:
		push_error("Hound identity failed to instantiate")
		return 1
	var torso_identity := hound.find_child("UndeadTorsoIdentity",true,false)
	var head_identity := hound.find_child("UndeadHeadFX",true,false)
	var failures := 0
	if torso_identity == null:
		push_error("Hound undead torso identity missing")
		failures += 1
	elif torso_identity.get_child_count() < 8:
		push_error("Hound undead torso identity lost wound/rib dressing")
		failures += 1
	if head_identity == null or head_identity.get_child_count() < 2:
		push_error("Hound undead eye identity missing")
		failures += 1
	hound.free()
	if failures == 0:
		print("PASS: Hound undead visual identity")
	return failures

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
