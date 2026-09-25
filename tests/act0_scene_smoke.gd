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
	_check(chapter.get_node_or_null("Game/IPhoneUILayout") is IPhoneUILayout,"iPhone Safe Area layout coordinator is mounted")
	_check(chapter.get_node_or_null("Game/StoryToast")!=null,"story feedback layer is mounted")
	_check(chapter.get_node_or_null("Game/CovenantMenu")!=null,"Covenant menu is mounted")
	_check(get_nodes_in_group("encounter_visual").size()>=5,"Catacomb encounter visuals are generated")

	var triggers:=chapter.get_node_or_null("Act0Triggers")
	_check(triggers!=null and triggers.get_child_count()>=13,"Act 0 Temple/Catacomb/Sigil triggers are generated")
	if triggers:
		_check(triggers.get_node_or_null("FadedSigil")!=null,"Faded Sigil threshold trigger exists")
		var temple_gate:=triggers.get_node_or_null("TempleGate")
		_check(temple_gate!=null and temple_gate.get_node_or_null("ProgressionBlocker") is StaticBody3D,"Temple has a physical progression blocker")
		if temple_gate:
			var gate_shape:=temple_gate.get_child(0) as CollisionShape3D
			var gate_box:=gate_shape.shape as BoxShape3D
			_check(gate_box!=null and gate_box.size.x>=27.5,"Temple gate trigger spans the entire exterior route after the blocker opens")
			var gate_shadow:=chapter.get_node_or_null("Shadow") as Node3D
			if gate_shadow and temple_gate.has_method("_approaching_from_exterior"):
				gate_shadow.global_position=temple_gate.global_position+Vector3(0,0,1.0)
				_check(temple_gate._approaching_from_exterior(gate_shadow),"exterior-side Temple crossing activates the entrance transition")
				gate_shadow.global_position=temple_gate.global_position+Vector3(0,0,-1.0)
				_check(not temple_gate._approaching_from_exterior(gate_shadow),"Temple-side crossing remains free after resume/backtracking")
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

	var exterior_collision:=chapter.get_node_or_null("Graybox/GameplayCollision")
	if exterior_collision:
		for boundary_name in ["ExteriorStartBoundary","CemeteryRouteL","CemeteryRouteR","RuinRouteL","RuinRouteR","CemeteryToRuinLeftSeam","TempleExteriorRouteL","TempleExteriorRouteR"]:
			_check(exterior_collision.get_node_or_null(boundary_name) is StaticBody3D,"exterior containment collider exists: %s"%boundary_name)

	var nave_wall:=chapter.get_node_or_null("TempleInterior/TempleVisual/NaveWall") as MeshInstance3D
	if nave_wall and nave_wall.mesh is BoxMesh:
		_check((nave_wall.mesh as BoxMesh).size.z>=38.0,"Temple nave walls reach continuously to the rear wall")

	var cat_wall:=chapter.get_node_or_null("Catacombs/CatacombVisual/Room01WallL") as MeshInstance3D
	if cat_wall and cat_wall.mesh is BoxMesh:
		_check((cat_wall.mesh as BoxMesh).size.z>=13.0,"Catacomb side walls close the inter-room bypass gaps")
	var room5_seal:=chapter.get_node_or_null("Catacombs/CatacombVisual/Room5Seal") as MeshInstance3D
	if room5_seal and room5_seal.mesh is BoxMesh:
		_check((room5_seal.mesh as BoxMesh).size.x>=11.2,"Room 5 terminal seal spans the full playable corridor")

	var game:=chapter.get_node_or_null("Game")
	if game:
		var hound_visual:=chapter.get_node_or_null("Graybox/VisualGeometry/VIS_HOUND") as Node3D
		if hound_visual:
			var hound_home:=hound_visual.global_transform
			game._position_combatants(hound_visual)
			hound_visual.rotation_degrees=Vector3(78,33,12)
			hound_visual.scale=Vector3(0.2,0.3,0.4)
			game._restore_visual_home(hound_visual)
			_check(hound_visual.global_transform.is_equal_approx(hound_home),"failed combat commit can restore full enemy transform, not only position")
			game._restore_act0_position()

		var toast_panel:=game.get_node_or_null("StoryToast/Panel") as Control
		var toast_text:=game.get_node_or_null("StoryToast/Panel/Text") as Control
		_check(toast_panel!=null and toast_panel.mouse_filter==Control.MOUSE_FILTER_IGNORE,"story toast cannot intercept world/touch input")
		_check(toast_text!=null and toast_text.mouse_filter==Control.MOUSE_FILTER_IGNORE,"story toast text cannot intercept world/touch input")

		var menu:=game.get_node_or_null("CovenantMenu") as CovenantMenu
		if menu:
			menu.open()
			for child in menu.get_node("Panel/Weapons").get_children():
				if child is Button:
					_check(child.custom_minimum_size.y>=64.0,"Covenant weapon button keeps an iPhone-sized touch target: %s"%str(child.get_meta("family")))
					child.emit_signal("pressed")
					_check(menu.selected==str(child.get_meta("family")),"Covenant button maps to its own weapon family: %s"%str(child.get_meta("family")))
			menu.close()

		var mobile:=game.get_node_or_null("MobileControls") as MobileControls
		if mobile and mobile.root:
			for name in ["Left","Right","Up","Down"]:
				var touch_button:=mobile.root.get_node_or_null(name) as Button
				_check(touch_button!=null and touch_button.size.x>=80.0 and touch_button.size.y>=80.0,"iPhone movement touch target keeps the desktop-test fallback size: %s"%name)

			mobile._set_held("left",true)
			var shadow_controller:=chapter.get_node_or_null("Shadow") as ShadowController
			_check(bool(mobile.held.get("left",false)),"focus-loss fixture starts with a held mobile direction")
			game._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
			_check(not bool(mobile.held.get("left",false)),"iPhone focus loss clears held touch state")
			if shadow_controller:
				_check(shadow_controller.virtual_direction==Vector2.ZERO,"iPhone focus loss neutralizes Shadow virtual movement")
			game._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
			game._notification(NOTIFICATION_APPLICATION_RESUMED)
			await process_frame
			_check(not game.mobile_reflow_pending,"duplicate iPhone focus/resume callbacks coalesce into one completed reflow")

		for path in [
			"CombatHUD/Panel/A1",
			"CombatHUD/Panel/A2",
			"MultiTargetHUD/Panel/TargetA",
			"MultiTargetHUD/Panel/TargetB",
			"MultiTargetHUD/Panel/A1",
			"MultiTargetHUD/Panel/A2",
			"SettingsMenu/Panel/Battery30",
			"SettingsMenu/Panel/Smooth60",
			"SettingsMenu/Panel/ReducedMotion",
			"SettingsMenu/Panel/Close"
		]:
			var iphone_button:=game.get_node_or_null(path) as Button
			_check(iphone_button!=null and iphone_button.size.y>=80.0,"iPhone interactive control keeps the fallback hit target: %s"%path)

		_check(game.act0.stage==Act0Contract.STAGE_EXTERIOR,"fresh scene restores exterior Act 0 stage")
		_check(not game.act0.temple_reveal_seen and not game.act0.faded_sigil_activated,"fresh scene keeps reveal and Temple threshold locked")
		_check(game.catacombs.room==0,"fresh scene has no Catacomb progress")
		_check(not game.room5_active,"Room 5 is inactive on fresh load")
		game._start_room5_solo_attempt([])
		_check(not game.room5_active and not game.room5_solo_attempt,"rejected Room 5 startup cannot leave the game in an active combat state")
		_check((chapter.get_node_or_null("Shadow") as CharacterBody3D).is_physics_processing(),"rejected Room 5 startup restores Shadow movement processing")
		_check(not game.room5_hud.visible,"rejected Room 5 startup keeps the multi-target HUD closed")

		var cat_gate_runtime:=triggers.get_node_or_null("CatacombsEntry") if triggers else null
		if cat_gate_runtime and cat_gate_runtime.has_method("_should_trigger_interaction"):
			var shadow:=chapter.get_node_or_null("Shadow") as Node3D
			if shadow:
				shadow.global_position=cat_gate_runtime.global_position+Vector3(0,0,1.0)
				_check(cat_gate_runtime._should_trigger_interaction(shadow),"Temple-side Catacomb threshold crossing activates descent/resume")
				shadow.global_position=cat_gate_runtime.global_position+Vector3(0,0,-1.0)
				_check(not cat_gate_runtime._should_trigger_interaction(shadow),"Catacomb-side threshold crossing allows free return to the Temple")

		if cat_gate_runtime and cat_gate_runtime.has_method("_sync_catacomb_blocker"):
			game.act0.first_forge_done=true
			game.act0.stage=Act0Contract.STAGE_CATACOMBS
			cat_gate_runtime._sync_catacomb_blocker()
			await process_frame
			_check(cat_gate_runtime.get_node_or_null("ProgressionBlocker")==null,"first forge opens the Catacomb passage during normal descent")

			game.act0.stage=Act0Contract.STAGE_ROOM5_RETURN
			cat_gate_runtime._sync_catacomb_blocker()
			await process_frame
			_check(cat_gate_runtime.get_node_or_null("ProgressionBlocker") is StaticBody3D,"Room 5 forced return physically re-locks the Catacomb passage")

			game.act0.stage=Act0Contract.STAGE_ROOM5_REMATCH
			cat_gate_runtime._sync_catacomb_blocker()
			await process_frame
			_check(cat_gate_runtime.get_node_or_null("ProgressionBlocker")==null,"story summon re-opens the Catacomb passage for the Room 5 rematch")

			game.act0.stage=Act0Contract.STAGE_COMPLETE
			cat_gate_runtime._sync_catacomb_blocker()
			await process_frame
			_check(cat_gate_runtime.get_node_or_null("ProgressionBlocker")==null,"Act 0 completion keeps the return route to the Temple open")

	chapter.queue_free()
	await process_frame
