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

func _memory_nodes()->Array[Node]:
	return get_nodes_in_group("temple_memory_room5_failure")

func _all_memory_visible(expected:bool)->bool:
	var nodes:=_memory_nodes()
	if nodes.size()<2:
		return false
	for node in nodes:
		if not (node is Node3D) or (node as Node3D).visible!=expected:
			return false
	return true

func _run()->void:
	var packed:=load("res://scenes/chapter00/chapter00_graybox.tscn") as PackedScene
	_check(packed!=null,"Temple memory scene loads")
	if packed==null:
		quit(1)
		return

	var chapter:=packed.instantiate()
	root.add_child(chapter)
	await process_frame
	await process_frame

	var game:=chapter.get_node_or_null("Game")
	var returned_gear:=chapter.get_node_or_null("TempleInterior/TempleVisual/Room5ReturnedGear") as Node3D
	var vigil:=chapter.get_node_or_null("TempleInterior/TempleVisual/Room5Vigil") as Node3D
	var warden:=chapter.get_node_or_null("TempleInterior/TempleVisual/GraveboundWarden") as Node3D
	_check(game!=null,"Chapter game exists for Temple memory state")
	_check(returned_gear!=null and vigil!=null,"Temple contains two independent Room 5 memory zones")
	_check(_memory_nodes().size()>=2,"Room 5 memory props share one deterministic state group")
	_check(_all_memory_visible(false),"Fresh Temple hides failed-descent memory props")
	_check(warden!=null and not warden.visible,"Fresh Temple hides story companion")

	if game:
		game.catacombs.room=5
		var changed:bool=bool(game.catacombs.trigger_room5_solo_limit())
		_check(changed,"Room 5 solo-limit flag commits through CatacombProgression")
		game._apply_threshold_visual_state()
		_check(_all_memory_visible(true),"Room 5 solo-limit reveals Temple memory props")
		_check(warden!=null and not warden.visible,"Failure memory appears before the story companion")

		# Save-state authority is the existing CatacombProgression snapshot.
		var saved:Dictionary=game.catacombs.snapshot()
		game.catacombs.restore({
			"catacomb_room":5,
			"room5_solo_limit_seen":false,
			"story_summon_unlocked":false,
			"room5_rematch_ready":false,
			"act0_complete":false
		})
		game._apply_threshold_visual_state()
		_check(_all_memory_visible(false),"Rolling progression back removes Room 5 memory visuals")

		game.catacombs.restore(saved)
		game._apply_threshold_visual_state()
		_check(_all_memory_visible(true),"Restoring saved Room 5 state restores Temple memory visuals")

		var summon_changed:bool=bool(game.catacombs.unlock_story_summon())
		_check(summon_changed,"Story summon unlock succeeds from restored Room 5 state")
		game._apply_threshold_visual_state()
		_check(_all_memory_visible(true),"Story summon does not erase the earlier failed-descent memory")
		_check(warden!=null and warden.visible,"Story summon adds the Warden as a second accumulated hub-memory state")

	chapter.queue_free()
	await process_frame
	print("Temple memory state tests complete. failures=%d"%failures)
	quit(1 if failures>0 else 0)
