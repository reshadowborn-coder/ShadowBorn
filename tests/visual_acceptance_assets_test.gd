extends SceneTree

const Policy = preload("res://scripts/presentation/visual_asset_policy.gd")
const Factory = preload("res://scripts/presentation/character_factory.gd")

func _init() -> void:
	var failures := 0
	if not Policy.is_acceptance_mode():
		push_error("Visual acceptance test must run with SHADOWBORN_VISUAL_ACCEPTANCE=1")
		failures += 1

	var missing := Policy.missing_required_assets()
	for path in missing:
		push_error("Missing required production visual asset: %s" % path)
		failures += 1

	if missing.is_empty():
		failures += _check_environment_contract(
			Policy.AWAKENING_ENVIRONMENT,
			["AwakeningCamera","ShadowSpawn","SwordSpawn"],
			"Awakening environment"
		)
		failures += _check_environment_contract(
			Policy.BATTLE_ENVIRONMENT,
			["BattleCamera","PlayerHome","EnemyHome","CameraTarget"],
			"Grave Hound arena"
		)
		failures += _check_production_factory("Shadow",func(): return Factory.create_shadow(false))
		failures += _check_production_factory("Grave Hound",func(): return Factory.create_hound())
		failures += _check_production_factory("Shadow Sword",func(): return Factory.create_sword_prop())

	if failures == 0:
		print("Shadowborn visual acceptance assets: PASS")
		quit(0)
	else:
		push_error("Shadowborn visual acceptance assets: %d failure(s)" % failures)
		quit(1)

func _check_environment_contract(path: String,required_nodes: Array[String],label: String) -> int:
	var root := Policy.instantiate_scene(path)
	if root == null:
		push_error("%s failed to instantiate: %s" % [label,path])
		return 1
	var failures := 0
	for node_name in required_nodes:
		if root.find_child(node_name,true,false) == null:
			push_error("%s missing required anchor/node: %s" % [label,node_name])
			failures += 1
	root.free()
	if failures == 0:
		print("PASS: %s anchors" % label)
	return failures

func _check_production_factory(label: String,builder: Callable) -> int:
	var node := builder.call() as Node3D
	if node == null:
		push_error("%s factory returned null" % label)
		return 1
	var tier := str(node.get_meta("shadowborn_visual_tier",""))
	var has_acceptance_error := bool(node.get_meta("visual_acceptance_error",false))
	node.free()
	if tier != "production" or has_acceptance_error:
		push_error("%s is not production visual content in acceptance mode: tier=%s" % [label,tier])
		return 1
	print("PASS: %s production provenance" % label)
	return 0
