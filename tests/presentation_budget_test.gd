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
	failures += _expect(int(box_stats["box_count"]) >= 10,"cemetery contains reusable stone box geometry")
	failures += _expect(int(box_stats["unique_shader_materials"]) <= 1,"cemetery stone boxes share one shader material")

	stage.queue_free()
	await process_frame

	var battle_stage := BattleStageScript.new()
	root.add_child(battle_stage)
	await process_frame
	failures += _expect(_count_shadowed_lights(battle_stage) <= 1,"battle keeps one real-time shadow-casting light")
	var battle_box_stats := _box_material_stats(battle_stage)
	failures += _expect(int(battle_box_stats["box_count"]) >= 10,"battle arena contains reusable stone box geometry")
	failures += _expect(int(battle_box_stats["unique_shader_materials"]) <= 1,"battle stone boxes share one shader material")
	battle_stage.queue_free()
	await process_frame

	if failures == 0:
		print("Shadowborn presentation budget: PASS")
		quit(0)
	else:
		push_error("Shadowborn presentation budget: %d failure(s)" % failures)
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

func _expect(condition: bool,label: String) -> int:
	if condition:
		print("PASS: "+label)
		return 0
	push_error("FAIL: "+label)
	return 1
