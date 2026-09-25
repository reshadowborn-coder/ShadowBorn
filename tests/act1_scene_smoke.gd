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

func _cleanup_save()->void:
	for path in [SaveManager.SAVE_PATH,SaveManager.TMP_PATH,SaveManager.BAK_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _completed_act0_state()->Dictionary:
	var s:=SaveManager.default_state()
	s.shadow_identity="female"
	s.covenant_joined=true
	s.weapon_family="bow"
	s.forged_item=Act0Progression.canonical_first_forge_item("bow")
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
	s.checkpoint="act0_complete"
	s.checkpoint_position=[Act0Layout.ROOM5_SHADOW_POSITION.x,Act0Layout.ROOM5_SHADOW_POSITION.y,Act0Layout.ROOM5_SHADOW_POSITION.z]
	return s

func _run()->void:
	_cleanup_save()
	_check(SaveManager.save_state(_completed_act0_state()),"Act 1 scene fixture commits a completed Act 0 save")
	var packed:=load("res://scenes/chapter01/chapter01_sewer_graybox.tscn") as PackedScene
	_check(packed!=null,"Act 1.1 sewer scene loads")
	if packed==null:
		_cleanup_save()
		quit(1)
		return
	var chapter:=packed.instantiate()
	root.add_child(chapter)
	await process_frame
	await process_frame
	await process_frame

	_check(chapter.get_node_or_null("Sewer/SewerCollision") is StaticBody3D,"Act 1 sewer collision is generated")
	for marker in ["Room1DryThreshold","Room2ToxicRunoff","Room2Overflow","Room3FloodL","Room3FloodR","Room3OutflowCross"]:
		_check(chapter.get_node_or_null("Sewer/SewerVisual/"+marker) is MeshInstance3D,"Act 1 chamber readability marker exists: "+marker)
	_check(chapter.get_node_or_null("TempleInterior/TempleCollision") is StaticBody3D,"Act 1 reuses the safe Temple hub")
	_check(chapter.get_node_or_null("TempleInterior/TempleVisual/TempleGuard") is TempleNpcIdle,"Temple Guard is present as an animated NPC")
	_check(chapter.get_node_or_null("Game/TempleWatchMenu") is TempleWatchMenu,"Temple Watch covenant confirmation UI is mounted")
	var game:=chapter.get_node_or_null("Game") as Chapter01Game
	_check(game!=null,"Chapter01Game coordinator is mounted")
	if game:
		_check(game.progression.stage==Act1Contract.STAGE_SEWER_ROOM1,"Act 1 scene restores first sewer stage")
		_check(game.shadow.global_position.is_equal_approx(Act1Layout.SEWER_ENTRY),"Act 1 scene restores the sewer entry checkpoint")
		_check(str(game.shadow_proxy.weapon_root.name)=="WeaponVisual" if game.shadow_proxy.weapon_root else false,"Act 1 preserves the forged weapon visual")

	var triggers:=chapter.get_node_or_null("Act1Triggers")
	if triggers:
		for name in ["SewerRoom1","SewerRoom2","SewerRoom3","KeeperAct1","SmithAct1","GuardAct1"]:
			_check(triggers.get_node_or_null(name) is Area3D,"Act 1 trigger exists: "+name)

	for id in Act1Contract.all_encounter_ids():
		var found:=false
		for node in get_nodes_in_group("encounter_visual"):
			if str(node.get_meta("encounter_id",""))==str(id): found=true
		_check(found,"Act 1 rat visual exists: "+str(id))

	var poison_visual:Node3D=null
	for node in get_nodes_in_group("encounter_visual"):
		if str(node.get_meta("encounter_id",""))=="a1_r2_poison_rat": poison_visual=node as Node3D
	_check(poison_visual is SewerRatVisual and str((poison_visual as SewerRatVisual).variant)=="poison","Poison Rat uses the poison visual variant")
	if poison_visual:
		poison_visual.scale=Vector3.ONE*1.08
		await process_frame
		_check(poison_visual.scale.is_equal_approx(Vector3.ONE*1.08),"rat idle animation preserves root scale owned by combat/target selection")
		_check(poison_visual.has_method("play_attack_cue") and poison_visual.has_method("set_reduced_motion"),"rat visual exposes lightweight combat/accessibility animation hooks")

	var watch:=chapter.get_node_or_null("Game/TempleWatchMenu") as TempleWatchMenu
	if watch:
		_check(watch.join_button.custom_minimum_size.y>=80.0,"Temple Watch JOIN keeps an iPhone-sized touch target")
		_check(watch.later_button.custom_minimum_size.y>=80.0,"Temple Watch NOT YET keeps an iPhone-sized touch target")

	chapter.queue_free()
	await process_frame
	_cleanup_save()
	print("Act 1.1 scene smoke complete. failures=%d"%failures)
	quit(1 if failures>0 else 0)