extends SceneTree

const EnvironmentAssetLibrary = preload("res://scripts/presentation/act0_environment_asset_library.gd")
const AwakeningStageScript = preload("res://scripts/presentation/awakening_stage.gd")
const BattleStageScript = preload("res://scripts/presentation/battle_stage.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures := 0
	failures += _expect(EnvironmentAssetLibrary.has_grave_marker_hero(),"authored hero grave mesh exists")
	failures += _expect(ResourceLoader.exists(EnvironmentAssetLibrary.BROKEN_ARCH_HERO),"authored broken arch mesh exists")

	var mesh := load(EnvironmentAssetLibrary.GRAVE_MARKER_HERO) as Mesh
	failures += _expect(mesh != null,"authored hero grave imports as Mesh")
	if mesh != null:
		var size := mesh.get_aabb().size
		failures += _expect(size.x >= 0.70 and size.y >= 1.35 and size.z >= 0.30,"hero grave has non-trivial camera-readable volume")
		failures += _expect(mesh.get_surface_count() >= 1,"hero grave contains renderable surface")

	var arch_mesh := load(EnvironmentAssetLibrary.BROKEN_ARCH_HERO) as Mesh
	failures += _expect(arch_mesh != null,"broken arch imports as Mesh")
	if arch_mesh != null:
		var arch_size := arch_mesh.get_aabb().size
		failures += _expect(arch_size.x >= 2.2 and arch_size.y >= 2.5 and arch_size.z >= 0.40,"broken arch has camera-readable architectural volume")

	var grave_a := EnvironmentAssetLibrary.create_grave_marker_hero()
	var grave_b := EnvironmentAssetLibrary.create_grave_marker_hero()
	failures += _expect(grave_a != null and grave_b != null,"hero grave factory instantiates")
	if grave_a != null and grave_b != null:
		failures += _expect(grave_a.material_override is ShaderMaterial,"hero grave uses authored damp-stone shader")
		failures += _expect(
			grave_a.material_override.get_instance_id() == grave_b.material_override.get_instance_id(),
			"hero graves reuse one material resource"
		)
	grave_a.free()
	grave_b.free()

	var awakening := AwakeningStageScript.new()
	root.add_child(awakening)
	await process_frame
	failures += _expect(_count_prefix(awakening,"ProductionPreviewGraveMarker_") >= 4,"awakening uses authored graves in camera envelope")
	awakening.queue_free()
	await process_frame

	var battle := BattleStageScript.new()
	root.add_child(battle)
	await process_frame
	failures += _expect(_count_prefix(battle,"ProductionPreviewGraveMarker_") >= 4,"battle edges use authored grave silhouettes")
	failures += _expect(battle.find_child("ProductionPreviewBrokenArch",true,false) != null,"battle landmark uses authored broken arch")
	battle.queue_free()
	await process_frame

	if failures == 0:
		print("Shadowborn environment mesh pipeline: PASS")
		quit(0)
	else:
		push_error("Shadowborn environment mesh pipeline: %d failure(s)" % failures)
		quit(1)

func _count_prefix(node: Node,prefix: String) -> int:
	var count := 1 if node.name.begins_with(prefix) else 0
	for child in node.get_children():
		count += _count_prefix(child,prefix)
	return count

func _expect(condition: bool,label: String) -> int:
	if condition:
		print("PASS: "+label)
		return 0
	push_error("FAIL: "+label)
	return 1
