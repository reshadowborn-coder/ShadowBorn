extends SceneTree

var failures:=0

func _init()->void:
	call_deferred("_run")

func _check(condition:bool,message:String)->void:
	if condition:
		print("PASS: "+message)
	else:
		failures+=1
		push_error("FAIL: "+message)

func _has_collision(node:Node)->bool:
	if node is CollisionShape3D or node is CollisionObject3D:
		return true
	for child in node.get_children():
		if _has_collision(child):
			return true
	return false

func _mesh_uses_emission(node:Node)->bool:
	if node is MeshInstance3D:
		var mesh_instance:=node as MeshInstance3D
		if mesh_instance.material_override is StandardMaterial3D:
			if (mesh_instance.material_override as StandardMaterial3D).emission_enabled:
				return true
		if mesh_instance.mesh!=null:
			for i in range(mesh_instance.mesh.get_surface_count()):
				var material:=mesh_instance.mesh.surface_get_material(i)
				if material is StandardMaterial3D and (material as StandardMaterial3D).emission_enabled:
					return true
	for child in node.get_children():
		if _mesh_uses_emission(child):
			return true
	return false

func _run()->void:
	var packed:=load("res://scenes/chapter00/chapter00_graybox.tscn") as PackedScene
	_check(packed!=null,"Chapter 0 loads for enemy ecology trace audit")
	if packed==null:
		quit(1)
		return

	var chapter:=packed.instantiate()
	root.add_child(chapter)
	await process_frame
	await process_frame

	var visual:=chapter.get_node_or_null("Graybox/VisualGeometry") as Node3D
	_check(visual!=null,"Exterior visual root exists")
	if visual:
		var specs=[
			["HoundEcologyTrace","TetherPost","VIS_HOUND",6.0],
			["ArmlessEcologyTrace","DisturbedBurialSlab","VIS_ARMLESS",7.0],
			["ShieldbearerEcologyTrace","ShieldDragMark","VIS_SHIELD_BOSS",7.0]
		]
		for spec in specs:
			var trace:=visual.get_node_or_null(str(spec[0])) as Node3D
			var cue:=visual.get_node_or_null("%s/%s"%[str(spec[0]),str(spec[1])]) as Node3D
			var enemy:=visual.get_node_or_null(str(spec[2])) as Node3D
			_check(trace!=null,"ecology trace exists: %s"%str(spec[0]))
			_check(cue!=null,"pre-contact hero cue exists: %s"%str(spec[1]))
			_check(enemy!=null,"paired encounter visual exists: %s"%str(spec[2]))
			if trace and cue and enemy:
				# Chapter 0 route moves toward increasingly negative Z. A larger Z
				# therefore means the clue is encountered before the enemy.
				_check(cue.global_position.z>enemy.global_position.z,"%s appears before its enemy along the authored route"%str(spec[0]))
				_check(cue.global_position.distance_to(enemy.global_position)<=float(spec[3]),"%s stays causally local instead of becoming unrelated background clutter"%str(spec[0]))
				_check(not _has_collision(trace),"%s remains non-blocking environmental evidence"%str(spec[0]))
				_check(not _mesh_uses_emission(trace),"%s does not become a glowing quest marker"%str(spec[0]))

		var hound_trace:=visual.get_node_or_null("HoundEcologyTrace") as Node3D
		if hound_trace:
			_check(hound_trace.get_node_or_null("ClawScrape00") is MeshInstance3D,"Hound trace combines tether evidence with claw damage")
		var armless_trace:=visual.get_node_or_null("ArmlessEcologyTrace") as Node3D
		if armless_trace:
			_check(armless_trace.get_node_or_null("OpenBurialDark") is MeshInstance3D,"Armless trace links the enemy to a disturbed burial")
			_check(armless_trace.get_node_or_null("LungeGouge00") is MeshInstance3D,"Armless trace foreshadows whole-body lunge motion")
		var shield_trace:=visual.get_node_or_null("ShieldbearerEcologyTrace") as Node3D
		if shield_trace:
			_check(shield_trace.get_node_or_null("GuardStandingWear") is MeshInstance3D,"Shieldbearer trace implies repeated defensive occupation")
			_check(shield_trace.get_node_or_null("ShieldBraceScar") is MeshInstance3D,"Shieldbearer trace ties wear to the Temple forecourt")

	chapter.queue_free()
	await process_frame
	print("Act 0 enemy ecology trace tests complete. failures=%d"%failures)
	quit(1 if failures>0 else 0)
