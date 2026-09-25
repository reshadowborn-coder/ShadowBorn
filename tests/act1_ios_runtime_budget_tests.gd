extends SceneTree

const MAX_TOTAL_NODES:=900
const MAX_MESH_INSTANCES:=460
const MAX_COLLISION_SHAPES:=180
const MAX_LIGHTS:=4
const MAX_RENDER_SURFACES:=700

var failures:=0
var nodes:=0
var meshes:=0
var collisions:=0
var lights:=0
var surfaces:=0

func _init()->void:
	call_deferred("_run")

func _check(condition:bool,message:String)->void:
	if condition:
		print("PASS: "+message)
	else:
		failures+=1
		push_error("FAIL: "+message)

func _cleanup_save()->void:
	for path in [SaveManager.SAVE_PATH,SaveManager.TMP_PATH,SaveManager.BAK_PATH]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _fixture()->Dictionary:
	var s:=SaveManager.default_state()
	s.shadow_identity="male"
	s.covenant_joined=true
	s.weapon_family="sword_shield"
	s.forged_item=Act0Progression.canonical_first_forge_item("sword_shield")
	s.first_forge_done=true
	s.hound_residual_absorbed=true
	s.temple_reveal_seen=true
	s.faded_sigil_activated=true
	s.catacomb_room=5
	s.room5_solo_limit_seen=true
	s.story_summon_unlocked=true
	s.room5_rematch_ready=true
	s.act0_complete=true
	s.act0_stage=Act0Contract.STAGE_COMPLETE
	s.cleared_encounters=Act0Contract.all_encounter_ids()
	return s

func _collect(node:Node)->void:
	nodes+=1
	if node is MeshInstance3D:
		meshes+=1
		var mesh:Mesh=(node as MeshInstance3D).mesh
		if mesh: surfaces+=mesh.get_surface_count()
	if node is CollisionShape3D: collisions+=1
	if node is Light3D: lights+=1
	for child in node.get_children(): _collect(child)

func _run()->void:
	_cleanup_save()
	_check(SaveManager.save_state(_fixture()),"Act 1 budget fixture saves")
	var packed:=load("res://scenes/chapter01/chapter01_sewer_graybox.tscn") as PackedScene
	_check(packed!=null,"Act 1 runtime budget scene loads")
	if packed==null:
		_cleanup_save()
		quit(1)
		return
	var chapter:=packed.instantiate()
	root.add_child(chapter)
	await process_frame
	await process_frame
	_collect(chapter)
	print("ACT1_IPHONE_RUNTIME_BUDGET nodes=%d meshes=%d collisions=%d lights=%d surfaces=%d"%[nodes,meshes,collisions,lights,surfaces])
	_check(nodes<=MAX_TOTAL_NODES,"Act 1.1 total node count stays within provisional iPhone budget")
	_check(meshes<=MAX_MESH_INSTANCES,"Act 1.1 MeshInstance count stays bounded")
	_check(collisions<=MAX_COLLISION_SHAPES,"Act 1.1 collision count stays bounded")
	_check(lights<=MAX_LIGHTS,"Act 1.1 light count stays bounded")
	_check(surfaces<=MAX_RENDER_SURFACES,"Act 1.1 render-surface count stays bounded")
	chapter.queue_free()
	await process_frame
	_cleanup_save()
	print("Act 1 iPhone runtime budget tests complete. failures=%d"%failures)
	quit(1 if failures>0 else 0)