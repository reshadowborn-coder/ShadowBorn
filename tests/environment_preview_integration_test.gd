extends SceneTree

const AwakeningStageScript = preload("res://scripts/presentation/awakening_stage.gd")
const BattleStageScript = preload("res://scripts/presentation/battle_stage.gd")
const MaterialLibrary = preload("res://scripts/presentation/act0_material_library.gd")
const EnvironmentAssetLibrary = preload("res://scripts/presentation/act0_environment_asset_library.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures := 0
	failures += _expect(MaterialLibrary.has_cemetery_cobble(),"production cobble maps are available")
	failures += _expect(EnvironmentAssetLibrary.has_grave_marker_hero(),"original grave marker mesh is available")

	var awakening := AwakeningStageScript.new()
	root.add_child(awakening)
	await process_frame
	failures += _check_stage_preview_assets(awakening,"Awakening",6)
	awakening.queue_free()
	await process_frame

	var battle := BattleStageScript.new()
	root.add_child(battle)
	await process_frame
	failures += _check_stage_preview_assets(battle,"Battle",4)
	battle.queue_free()
	await process_frame

	if failures == 0:
		print("Shadowborn environment production-preview integration: PASS")
		quit(0)
	else:
		push_error("Shadowborn environment production-preview integration: %d failure(s)" % failures)
		quit(1)

func _check_stage_preview_assets(stage: Node,label: String,min_grave_markers: int) -> int:
	var failures := 0
	var floor := stage.find_child("ProductionCobblePreviewFloor",true,false) as MeshInstance3D
	failures += _expect(floor != null,"%s has named production cobble preview floor" % label)
	if floor != null and floor.mesh is PlaneMesh:
		var material := (floor.mesh as PlaneMesh).material
		failures += _expect(material is ORMMaterial3D,"%s floor uses production ORMMaterial3D" % label)
		failures += _expect(str(floor.get_meta("shadowborn_visual_tier","")) == "production_preview","%s floor is tagged production_preview" % label)

	var grave_count := _count_preview_graves(stage)
	failures += _expect(grave_count >= min_grave_markers,"%s uses at least %d original grave markers (found %d)" % [label,min_grave_markers,grave_count])
	return failures

func _count_preview_graves(node: Node) -> int:
	var count := 0
	if node is MeshInstance3D:
		if str(node.get_meta("shadowborn_visual_source","")) == EnvironmentAssetLibrary.GRAVE_MARKER_HERO:
			count += 1
	for child in node.get_children():
		count += _count_preview_graves(child)
	return count

func _expect(condition: bool,label: String) -> int:
	if condition:
		print("PASS: "+label)
		return 0
	push_error("FAIL: "+label)
	return 1
