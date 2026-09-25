extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _sorted_strings(values) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	result.sort()
	return result

func _run() -> void:
	var contract_families := _sorted_strings(Act0Contract.WEAPON_FAMILIES)
	var progression_families := _sorted_strings(Act0Progression.WEAPONS.keys())
	var loadout_families := _sorted_strings(ShadowLoadout.PROFILES.keys())

	_check(contract_families == progression_families, "Act 0 weapon contract and progression catalog expose the same starter families")
	_check(contract_families == loadout_families, "Every Act 0 starter weapon family has a combat loadout profile")

	var packed := load("res://scenes/chapter00/chapter00_graybox.tscn") as PackedScene
	_check(packed != null, "Chapter 0 scene loads for weapon visual contract audit")
	if packed == null:
		quit(1)
		return

	var chapter := packed.instantiate()
	root.add_child(chapter)
	await process_frame
	var weapons := chapter.get_node_or_null("Game/CovenantMenu/Panel/Weapons")
	_check(weapons != null, "Covenant starter weapon UI exists")

	var ui_families: Array[String] = []
	if weapons != null:
		for child in weapons.get_children():
			if child is Button and child.has_meta("family"):
				ui_families.append(str(child.get_meta("family")))
		ui_families.sort()
	_check(ui_families == contract_families, "Covenant UI exposes exactly the weapon families supported by the Act 0 contract")

	var proxy := ShadowProxy.new()
	root.add_child(proxy)
	await process_frame
	for family in contract_families:
		proxy.set_weapon_family(family)
		_check(proxy.weapon_root != null, "%s creates a Shadow weapon visual root" % family)
		_check(proxy.weapon_root != null and proxy.weapon_root.get_child_count() > 0, "%s has at least one visible proxy component" % family)

	proxy.queue_free()
	chapter.queue_free()
	await process_frame

	print("Starter weapon visual contract tests complete. failures=%d" % failures)
	quit(1 if failures > 0 else 0)
