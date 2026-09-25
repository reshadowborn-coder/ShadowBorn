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
	s.shadow_identity="male"
	s.covenant_joined=true
	s.weapon_family="sword_shield"
	s.forged_item=Act0Progression.canonical_first_forge_item("sword_shield")
	s.first_forge_done=true
	s.silver=0
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

func _room3_state()->Dictionary:
	var s:=_completed_act0_state()
	s.act1_stage=Act1Contract.STAGE_SEWER_ROOM3
	s.act1_sewer_room=3
	s.checkpoint="act1_room2_cleared"
	s.checkpoint_position=SaveManager._vector3_array(Act1Layout.room_checkpoint(3))
	return s

func _load_chapter()->Node:
	var packed:=load("res://scenes/chapter01/chapter01_sewer_graybox.tscn") as PackedScene
	_check(packed!=null,"Act 1 scene loads for iOS suspend recovery")
	if packed==null:
		return null
	var chapter:=packed.instantiate()
	root.add_child(chapter)
	await process_frame
	await process_frame
	await process_frame
	return chapter

func _run()->void:
	_cleanup_save()

	# A suspended app may be killed by iOS. An active 1v1 is transient: Continue
	# must return to the last committed room checkpoint rather than serialize a
	# half-finished combat.
	_check(SaveManager.save_state(_completed_act0_state()),"suspend fixture commits completed Act 0")
	var chapter=await _load_chapter()
	if chapter:
		var game:=chapter.get_node_or_null("Game") as Chapter01Game
		_check(game!=null,"Act 1 coordinator exists for suspend recovery")
		if game:
			game.enter_sewer_room(1)
			_check(game.encounter.active,"Room 1 combat is active before simulated iOS suspend")
			game._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
			var resumed:=SaveManager.load_state()
			_check(str(resumed.act1_stage)==Act1Contract.STAGE_SEWER_ROOM1,"suspend during 1v1 preserves the committed Room 1 stage")
			_check(str(resumed.checkpoint)=="act1_sewer_entry","suspend during 1v1 preserves the committed sewer-entry checkpoint")
			_check("a1_r1_rat" not in resumed.cleared_encounters,"suspend during 1v1 cannot invent an enemy clear")
		chapter.queue_free()
		await process_frame

	_cleanup_save()

	# The pack's first accepted round is also transient. Only the authored
	# second-round solo-limit transition may commit Temple return.
	_check(SaveManager.save_state(_room3_state()),"Room 3 suspend fixture commits canonical pack checkpoint")
	chapter=await _load_chapter()
	if chapter:
		var game:=chapter.get_node_or_null("Game") as Chapter01Game
		_check(game!=null,"Room 3 coordinator exists for suspend recovery")
		if game:
			_check(game.progression.stage==Act1Contract.STAGE_SEWER_ROOM3,"Room 3 fixture restores the pack stage")
			game.enter_sewer_room(3)
			_check(game.pack_active and game.pack_combat.active,"pack encounter is active before suspend")
			game.pack_combat.shadow_action("A1")
			_check(game.pack_combat.rounds==1 and game.pack_combat.action_locked,"first pack round is accepted but still inside presentation lock")
			game._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
			var mid_pack:=SaveManager.load_state()
			_check(str(mid_pack.act1_stage)==Act1Contract.STAGE_SEWER_ROOM3,"suspend after pack round 1 preserves Room 3")
			_check(not bool(mid_pack.act1_sewer_defeat_seen),"suspend after pack round 1 cannot commit the authored defeat early")
			_check(str(mid_pack.checkpoint)=="act1_room2_cleared","suspend after pack round 1 preserves the pre-pack checkpoint")

			await create_timer(MultiEnemyEncounter.ACTION_LOCK_SECONDS+.05).timeout
			game.pack_combat.shadow_action("A1")
			await process_frame
			var committed:=SaveManager.load_state()
			_check(str(committed.act1_stage)==Act1Contract.STAGE_TEMPLE_RETURN and bool(committed.act1_sewer_defeat_seen),"second accepted pack round atomically commits Temple return")
			_check(str(committed.checkpoint)=="act1_temple_return","forced retreat commits the canonical Temple checkpoint")

			game._notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
			var after_suspend:=SaveManager.load_state()
			_check(str(after_suspend.act1_stage)==Act1Contract.STAGE_TEMPLE_RETURN and bool(after_suspend.act1_sewer_defeat_seen),"suspend after committed retreat preserves the irreversible transition")
		chapter.queue_free()
		await process_frame

	_cleanup_save()
	print("Act 1 iOS suspend recovery tests complete. failures=%d"%failures)
	quit(1 if failures>0 else 0)
