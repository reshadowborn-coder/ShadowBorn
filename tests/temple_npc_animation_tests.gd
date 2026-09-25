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
	var packed:=load("res://scenes/chapter00/chapter00_graybox.tscn") as PackedScene
	_check(packed!=null,"Temple NPC animation scene loads")
	if packed==null:
		quit(1)
		return

	var chapter:=packed.instantiate()
	root.add_child(chapter)
	await process_frame
	await process_frame

	var paths:={
		"keeper":"TempleInterior/TempleVisual/Keeper",
		"smith":"TempleInterior/TempleVisual/SmithStation/SmithNPC",
		"merchant":"TempleInterior/TempleVisual/MerchantStation/MerchantNPC",
		"engraver":"TempleInterior/TempleVisual/EngraverStation/EngraverNPC"
	}

	for profile in paths:
		var npc:=chapter.get_node_or_null(paths[profile]) as TempleNpcIdle
		_check(npc!=null,"Temple NPC exists with idle controller: "+profile)
		if npc==null:
			continue
		_check(npc.motion_profile==profile,"Temple NPC uses its authored motion profile: "+profile)
		for child_name in ["Body","Head","ArmL","ArmR"]:
			_check(npc.get_node_or_null(child_name) is Node3D,"%s has articulated %s"%[profile,child_name])

		npc.set_process(false)
		var head:=npc.get_node("Head") as Node3D
		var before:=head.basis
		npc.elapsed=0.0
		npc.set_reduced_motion(false)
		npc._process(1.37)
		_check(not head.basis.is_equal_approx(before),"%s idle cycle changes pose instead of remaining statue-still"%profile)

	var smith:=chapter.get_node_or_null(paths["smith"]) as TempleNpcIdle
	if smith:
		_check(smith.get_node_or_null("Tool") is Node3D,"Smith owns an articulated hammer root")
		_check(smith.get_node_or_null("Tool/HammerHead") is MeshInstance3D,"Smith hammer head follows the animated tool root")
		var smith_head:=smith.get_node("Head") as Node3D
		var smith_head_before:=smith_head.basis
		smith.elapsed=0.0
		smith.play_interaction_reaction()
		smith._process(0.35)
		_check(smith.reaction_remaining>0.0,"Smith interaction starts a bounded reaction window")
		_check(not smith_head.basis.is_equal_approx(smith_head_before),"Smith interaction reaction changes the idle pose")

	var engraver:=chapter.get_node_or_null(paths["engraver"]) as TempleNpcIdle
	if engraver:
		_check(engraver.get_node_or_null("Tool") is Node3D,"Engraver owns an animated stylus/tool")

	var temple_visual:=chapter.get_node_or_null("TempleInterior/TempleVisual")
	if temple_visual:
		for node_name in ["CovenantSpineL","CovenantSpineR","CovenantCrown","CovenantRuneCore"]:
			_check(temple_visual.get_node_or_null(node_name) is MeshInstance3D,"Covenant focal architecture exists: "+node_name)
		for ruined_detail in ["BrokenRoofRibL","BrokenRoofRibR","TornBannerL","TornBannerR","BrokenPewL","BrokenPewR"]:
			_check(temple_visual.get_node_or_null(ruined_detail) is MeshInstance3D,"Temple keeps low-cost ruined nave storytelling: "+ruined_detail)
		var rune_core:=temple_visual.get_node_or_null("CovenantRuneCore") as MeshInstance3D
		if rune_core:
			var material:=rune_core.material_override as StandardMaterial3D
			_check(material!=null and material.emission_enabled,"Covenant rune core uses emissive focus without an extra Light3D")
		var ember:=temple_visual.get_node_or_null("SmithStation/Ember") as MeshInstance3D
		if ember:
			var ember_material:=ember.material_override as StandardMaterial3D
			_check(ember_material!=null and ember_material.emission_enabled,"Smith ember uses emissive material instead of a dynamic light")

	var game:=chapter.get_node_or_null("Game")
	if game:
		var merchant:=chapter.get_node_or_null(paths["merchant"]) as TempleNpcIdle
		if merchant:
			merchant.reaction_remaining=0.0
			game._react_temple_npc("merchant")
			_check(merchant.reaction_remaining>0.0,"Temple interaction routes a reaction to the matching NPC only")
		game.reduced_motion=true
		game._apply_presentation_settings()
		for npc_node in get_nodes_in_group("temple_npc_idle"):
			_check(bool(npc_node.reduced_motion),"Reduced Motion propagates to Temple NPC ambience")
		game.reduced_motion=false
		game._apply_presentation_settings()

	chapter.queue_free()
	await process_frame
	print("Temple NPC animation tests complete. failures=%d"%failures)
	quit(1 if failures>0 else 0)
