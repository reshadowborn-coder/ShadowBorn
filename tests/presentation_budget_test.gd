extends SceneTree

const AwakeningStageScript = preload("res://scripts/presentation/awakening_stage.gd")
const BattleStageScript = preload("res://scripts/presentation/battle_stage.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures := 0
	var stage := AwakeningStageScript.new()
	root.add_child(stage)
	await process_frame

	var shadowed_lights := _count_shadowed_lights(stage)
	failures += _expect(shadowed_lights <= 1,"awakening keeps one real-time shadow-casting light")

	var motes := stage.find_child("AmbientMotes",true,false)
	failures += _expect(motes is GPUParticles3D,"ambient cemetery motes use one GPU particle emitter")

	var box_stats := _box_material_stats(stage)
	# Production Awakening must not regress to the old BoxMesh crypt.
	failures += _expect(int(box_stats["box_count"]) <= 2,"awakening does not regress to repeated BoxMesh blockout geometry")
	var awakening_authored := _authored_checkpoint_mesh_stats(stage)
	failures += _expect(int(awakening_authored["mesh_count"]) >= 18,"awakening uses the authored Checkpoint 01 funerary/masonry kit")
	failures += _expect(int(awakening_authored["unique_override_materials"]) <= 1,"awakening authored stone meshes share one override material")

	stage.queue_free()
	await process_frame

	var battle_stage := BattleStageScript.new()
	root.add_child(battle_stage)
	await process_frame
	failures += _expect(_count_shadowed_lights(battle_stage) <= 1,"battle keeps one real-time shadow-casting light")
	var battle_box_stats := _box_material_stats(battle_stage)
	# The old prototype budget required >=10 BoxMesh nodes, which accidentally
	# protected the blockout representation. The visual rebuild intentionally
	# removes those boxes. Budget the authored replacement instead: fewer primitive
	# stand-ins, enough reusable authored modules, and one shared stone material.
	failures += _expect(int(battle_box_stats["box_count"]) <= 4,"battle does not regress to repeated BoxMesh blockout geometry")
	var authored_stats := _authored_checkpoint_mesh_stats(battle_stage)
	failures += _expect(int(authored_stats["mesh_count"]) >= 19,"battle uses the authored Checkpoint 01 masonry/grave kit")
	failures += _expect(int(authored_stats["unique_override_materials"]) <= 1,"authored Checkpoint 01 stone meshes share one override material")
	battle_stage.queue_free()
	await process_frame

	if failures == 0:
		print("Shadowborn DEBUG presentation performance budget: PASS (not a visual-quality gate)")
		quit(0)
	else:
		push_error("Shadowborn DEBUG presentation performance budget: %d failure(s)" % failures)
		quit(1)

func _count_shadowed_lights(node: Node) -> int:
	var count := 0
	if node is Light3D and (node as Light3D).shadow_enabled:
		count += 1
	for child in node.get_children():
		count += _count_shadowed_lights(child)
	return count

func _box_material_stats(node: Node) -> Dictionary:
	var box_count := 0
	var material_ids: Dictionary = {}
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh is BoxMesh:
			box_count += 1
			var box_mesh := mesh_instance.mesh as BoxMesh
			var material: Material = box_mesh.material
			if material is ShaderMaterial:
				material_ids[material.get_instance_id()] = true
	for child in node.get_children():
		var nested := _box_material_stats(child)
		box_count += int(nested["box_count"])
		for key in (nested["material_ids"] as Dictionary).keys():
			material_ids[key] = true
	return {
		"box_count": box_count,
		"unique_shader_materials": material_ids.size(),
		"material_ids": material_ids
	}

func _authored_checkpoint_mesh_stats(node: Node) -> Dictionary:
	var mesh_count := 0
	var material_ids: Dictionary = {}
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var source := str(mesh_instance.get_meta("shadowborn_visual_source",""))
		if source.begins_with("res://assets/environments/checkpoint01/") and source.ends_with(".obj"):
			mesh_count += 1
			var override_material := mesh_instance.material_override
			if override_material != null:
				material_ids[override_material.get_instance_id()] = true
	for child in node.get_children():
		var nested := _authored_checkpoint_mesh_stats(child)
		mesh_count += int(nested["mesh_count"])
		for key in (nested["material_ids"] as Dictionary).keys():
			material_ids[key] = true
	return {
		"mesh_count": mesh_count,
		"unique_override_materials": material_ids.size(),
		"material_ids": material_ids
	}

func _expect(condition: bool,label: String) -> int:
	if condition:
		print("PASS: "+label)
		return 0
	push_error("FAIL: "+label)
	return 1
