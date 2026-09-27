extends SceneTree

const AwakeningStageScript = preload("res://scripts/presentation/awakening_stage.gd")
const BattleStageScript = preload("res://scripts/presentation/battle_stage.gd")
const MaterialLibrary = preload("res://scripts/presentation/act0_material_library.gd")
const EnvironmentAssetLibrary = preload("res://scripts/presentation/act0_environment_asset_library.gd")
const VisualPolicy = preload("res://scripts/presentation/visual_asset_policy.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures := 0
	failures += _expect(MaterialLibrary.has_cemetery_cobble(),"production cobble maps are available")
	failures += _expect(EnvironmentAssetLibrary.has_grave_marker_hero(),"original grave marker mesh is available")
	failures += _expect(EnvironmentAssetLibrary.has_wall_fragment_hero(),"authored wall fragment mesh is available")
	failures += _expect(EnvironmentAssetLibrary.has_rubble_cluster_hero(),"authored rubble cluster mesh is available")
	failures += _expect(EnvironmentAssetLibrary.has_boundary_wall_ruin_hero(),"authored boundary wall ruin mesh is available")

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
		var floor_tier := str(floor.get_meta("shadowborn_visual_tier",""))
		var production_path := VisualPolicy.AWAKENING_ENVIRONMENT if label == "Awakening" else VisualPolicy.BATTLE_ENVIRONMENT
		if ResourceLoader.exists(production_path):
			failures += _expect(floor_tier == "production","%s floor is tagged production when its authored environment scene exists" % label)
		else:
			failures += _expect(floor_tier == "production_preview","%s fallback floor is tagged production_preview" % label)

	var grave_count := _count_preview_assets(stage,EnvironmentAssetLibrary.GRAVE_MARKER_HERO)
	failures += _expect(grave_count >= min_grave_markers,"%s uses at least %d original grave markers (found %d)" % [label,min_grave_markers,grave_count])

	if label == "Awakening":
		var shadow := stage.find_child("AwakeningShadow",true,false) as Node3D
		var slab := stage.find_child("ProductionPreviewAwakeningSlab",true,false) as Node3D
		failures += _expect(shadow != null,"Awakening has stable Shadow root for corpse-clearance regression")
		failures += _expect(slab != null,"Awakening has the authored slab under the corpse")
		if shadow != null:
			var wall_clearance := shadow.global_position.z - AwakeningStageScript.DEBUG_CORPSE_WALL_FRONT_Z
			failures += _expect(
				wall_clearance >= AwakeningStageScript.DEBUG_MIN_CORPSE_WALL_CLEARANCE - 0.001,
				"Awakening corpse root keeps >= %.2fm clearance from wall front (found %.3fm)" % [AwakeningStageScript.DEBUG_MIN_CORPSE_WALL_CLEARANCE,wall_clearance]
			)
		if shadow != null and slab != null:
			failures += _expect(
				absf(shadow.global_position.z-slab.global_position.z) <= 0.20,
				"Awakening corpse remains staged over the slab instead of against masonry"
			)

	if label == "Battle":
		var wall_count := _count_preview_assets(stage,EnvironmentAssetLibrary.WALL_FRAGMENT_HERO)
		var rubble_count := _count_preview_assets(stage,EnvironmentAssetLibrary.RUBBLE_CLUSTER_HERO)
		var boundary_count := _count_preview_assets(stage,EnvironmentAssetLibrary.BOUNDARY_WALL_RUIN_HERO)
		failures += _expect(wall_count >= 3,"Battle uses authored wall fragments instead of one flat background BoxMesh (found %d)" % wall_count)
		failures += _expect(rubble_count >= 3,"Battle uses authored rubble clusters at the wall base (found %d)" % rubble_count)
		failures += _expect(boundary_count >= 8,"Battle side borders use authored boundary ruins instead of repeated BoxMesh slabs (found %d)" % boundary_count)
		failures += _expect(stage.find_child("ProductionPreviewWallFragment_00",true,false) != null,"Battle wall preview has stable named geometry for screenshot regression")
		failures += _expect(stage.find_child("ProductionPreviewBoundaryRuin_00",true,false) != null,"Battle boundary preview has stable named geometry for screenshot regression")
	return failures

func _count_preview_assets(node: Node,source_path: String) -> int:
	var count := 0
	if node is MeshInstance3D:
		if str(node.get_meta("shadowborn_visual_source","")) == source_path:
			count += 1
	for child in node.get_children():
		count += _count_preview_assets(child,source_path)
	return count

func _expect(condition: bool,label: String) -> int:
	if condition:
		print("PASS: "+label)
		return 0
	push_error("FAIL: "+label)
	return 1
