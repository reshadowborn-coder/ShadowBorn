extends SceneTree

const Factory = preload("res://scripts/presentation/character_factory.gd")

func _init() -> void:
	var failures := 0
	failures += _check_scene("res://assets/vendor/quaternius/shadow_adventurer.gltf",["Idle_Sword","Sword_Slash","Roll","HitRecieve","Death","Interact"],"Shadow dev asset")
	failures += _check_scene("res://assets/vendor/quaternius/grave_wolf.gltf",["Idle","Attack","Idle_HitReact1","Death"],"Hound dev asset")
	failures += _check_resource("res://assets/vendor/quaternius/shadow_sword.gltf","Sword dev asset")
	failures += _check_hound_identity()

	if failures == 0:
		print("Shadowborn DEBUG fallback asset pipeline: PASS (not production-art acceptance)")
		quit(0)
	else:
		push_error("Shadowborn DEBUG fallback asset pipeline: %d failure(s)" % failures)
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
	var tier := str(hound.get_meta("shadowborn_visual_tier",""))
	var failures := 0

	if tier == "production_preview":
		# The main non-acceptance path now hides vendor geometry and builds the
		# original Shadowborn visible shell in _ready(). Exercise that authored
		# preview contract instead of protecting the retired debug overlays.
		hound.call("_ready")
		failures += _expect(hound.find_child("GraveHoundSkinnedBodyV1",true,false) != null,"Hound production preview exposes original skinned body")
		failures += _expect(hound.find_child("HoundSkull",true,false) != null,"Hound production preview exposes authored skull identity")
		failures += _expect(hound.find_child("HoundMuzzle",true,false) != null,"Hound production preview exposes authored muzzle identity")
		failures += _expect(hound.find_child("ExposedRibsSocket",true,false) != null,"Hound production preview keeps exposed-rib undead language")
		failures += _expect(hound.find_child("HoundWoundsSocket",true,false) != null,"Hound production preview keeps wound undead language")
	elif tier == "debug_vendor":
		var torso_identity := hound.find_child("UndeadTorsoIdentity",true,false)
		var head_identity := hound.find_child("UndeadHeadFX",true,false)
		if torso_identity == null:
			push_error("Hound debug undead torso identity missing")
			failures += 1
		elif torso_identity.get_child_count() < 8:
			push_error("Hound debug undead torso identity lost wound/rib dressing")
			failures += 1
		if head_identity == null or head_identity.get_child_count() < 2:
			push_error("Hound debug undead eye identity missing")
			failures += 1
	else:
		push_error("Unexpected Hound visual tier in asset pipeline test: %s" % tier)
		failures += 1

	hound.free()
	if failures == 0:
		print("PASS: Hound identity contract (%s)" % tier)
	return failures

func _expect(condition: bool,label: String) -> int:
	if condition:
		print("PASS: "+label)
		return 0
	push_error("FAIL: "+label)
	return 1

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
