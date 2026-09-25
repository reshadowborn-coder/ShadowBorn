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

func _run()->void:
	await _test_launch_shell()
	await _test_chapter_scene()
	print("Act 0 scene smoke complete. failures=%d"%failures)
	quit(1 if failures>0 else 0)

func _test_launch_shell()->void:
	var packed:=load("res://scenes/app/launch_shell.tscn") as PackedScene
	_check(packed!=null,"launch shell scene loads")
	if packed==null:
		return
	var shell:=packed.instantiate()
	root.add_child(shell)
	await process_frame
	_check(shell is Control,"launch shell instantiates as Control")
	_check(shell.get_script()!=null,"launch shell script is attached")
	shell.queue_free()
	await process_frame

func _test_chapter_scene()->void:
	var packed:=load("res://scenes/chapter00/chapter00_graybox.tscn") as PackedScene
	_check(packed!=null,"Chapter 0 scene loads")
	if packed==null:
		return

	var chapter:=packed.instantiate()
	root.add_child(chapter)
	await process_frame
	await process_frame

	_check(chapter.get_node_or_null("Shadow") is CharacterBody3D,"Shadow body exists")
	_check(chapter.get_node_or_null("Game")!=null,"Chapter00Game node exists")
	_check(chapter.get_node_or_null("TempleInterior/TempleCollision") is StaticBody3D,"Temple collision body is generated")
	_check(chapter.get_node_or_null("Catacombs/CatacombCollision") is StaticBody3D,"Catacomb collision body is generated")
	_check(chapter.get_node_or_null("Game/MobileControls")!=null,"mobile controls are mounted")
	_check(chapter.get_node_or_null("Game/StoryToast")!=null,"story feedback layer is mounted")
	_check(chapter.get_node_or_null("Game/CovenantMenu")!=null,"Covenant menu is mounted")
	_check(get_nodes_in_group("encounter_visual").size()>=5,"Catacomb encounter visuals are generated")

	var triggers:=chapter.get_node_or_null("Act0Triggers")
	_check(triggers!=null and triggers.get_child_count()>=13,"Act 0 Temple/Catacomb/Sigil triggers are generated")
	if triggers:
		_check(triggers.get_node_or_null("FadedSigil")!=null,"Faded Sigil threshold trigger exists")
		var temple_gate:=triggers.get_node_or_null("TempleGate")
		_check(temple_gate!=null and temple_gate.get_node_or_null("ProgressionBlocker") is StaticBody3D,"Temple has a physical progression blocker")
		var cat_gate:=triggers.get_node_or_null("CatacombsEntry")
		_check(cat_gate!=null and cat_gate.get_node_or_null("ProgressionBlocker") is StaticBody3D,"Catacombs are physically blocked before first forge")
		if cat_gate:
			var cat_shape:=cat_gate.get_child(0) as CollisionShape3D
			var cat_box:=cat_shape.shape as BoxShape3D
			_check(cat_box!=null and cat_box.size.x>=7.0,"Catacomb entry trigger spans the full passage")
		var keeper:=triggers.get_node_or_null("Keeper")
		if keeper:
			var keeper_shape:=keeper.get_child(0) as CollisionShape3D
			var keeper_box:=keeper_shape.shape as BoxShape3D
			_check(keeper_box!=null and keeper_box.size.x>=12.5,"Keeper handoff spans the Temple nave")
		var covenant:=triggers.get_node_or_null("Covenant")
		if covenant:
			var covenant_shape:=covenant.get_child(0) as CollisionShape3D
			var covenant_box:=covenant_shape.shape as BoxShape3D
			_check(covenant_box!=null and covenant_box.size.x>=12.5,"Covenant handoff spans the Temple nave")
		var room1:=triggers.get_node_or_null("CatacombRoom1")
		if room1:
			var room_shape:=room1.get_child(0) as CollisionShape3D
			var room_box:=room_shape.shape as BoxShape3D
			_check(room_box!=null and room_box.size.x>=10.0,"Catacomb room trigger spans the playable corridor")

	var hound_trigger:=chapter.get_node_or_null("Graybox/ENC_HOUND")
	if hound_trigger:
		var hound_shape:=hound_trigger.get_child(0) as CollisionShape3D
		var hound_box:=hound_shape.shape as BoxShape3D
		_check(hound_box!=null and hound_box.size.x>=20.0,"exterior encounter trigger cannot be bypassed laterally")

	var reveal_trigger:=chapter.get_node_or_null("Graybox/REVEAL_TEMPLE")
	if reveal_trigger:
		var reveal_shape:=reveal_trigger.get_child(0) as CollisionShape3D
		var reveal_box:=reveal_shape.shape as BoxShape3D
		_check(reveal_box!=null and reveal_box.size.x>=20.0,"Temple reveal trigger spans the exterior route")

	var cat_wall:=chapter.get_node_or_null("Catacombs/CatacombVisual/Room01WallL") as MeshInstance3D
	if cat_wall and cat_wall.mesh is BoxMesh:
		_check((cat_wall.mesh as BoxMesh).size.z>=13.0,"Catacomb side walls close the inter-room bypass gaps")

	var game:=chapter.get_node_or_null("Game")
	if game:
		_check(game.act0.stage==Act0Contract.STAGE_EXTERIOR,"fresh scene restores exterior Act 0 stage")
		_check(not game.act0.temple_reveal_seen and not game.act0.faded_sigil_activated,"fresh scene keeps reveal and Temple threshold locked")
		_check(game.catacombs.room==0,"fresh scene has no Catacomb progress")
		_check(not game.room5_active,"Room 5 is inactive on fresh load")

	chapter.queue_free()
	await process_frame
