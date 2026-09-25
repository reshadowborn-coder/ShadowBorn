class_name Chapter01Game
extends Node

@onready var shadow:CharacterBody3D=get_parent().get_node("Shadow")
@onready var shadow_proxy:ShadowProxy=get_parent().get_node("Shadow/ShadowProxy")
@onready var camera_rig:CameraDirector=get_parent().get_node("CameraRig")
@onready var encounter:EncounterController=$EncounterController
@onready var presenter:CombatPresenter=$CombatPresenter
@onready var hud:CombatHUD=$CombatHUD
@onready var pack_combat:MultiEnemyEncounter=$PackCombat
@onready var pack_hud:MultiTargetHUD=$MultiTargetHUD
@onready var mobile_controls:MobileControls=$MobileControls
@onready var settings_menu:SettingsMenu=$SettingsMenu
@onready var settings_button:Button=$CombatHUD/SettingsButton
@onready var story_toast:StoryToast=$StoryToast
@onready var iphone_ui_layout:IPhoneUILayout=$IPhoneUILayout
@onready var watch_menu:TempleWatchMenu=$TempleWatchMenu
@onready var platform_runtime:PlatformRuntimeService=get_node("/root/PlatformRuntime") as PlatformRuntimeService

var progression:=Act1Progression.new()
var cleared_encounters:Array[String]=[]
var checkpoint_position:=Act1Layout.SEWER_ENTRY
var performance_mode:="smooth60"
var reduced_motion:=false
var active_enemy_visual:Node3D
var pack_visual_cache:Array[Node3D]=[]
var pack_active:=false
var combat_trace:CombatFrameTrace
var last_committed_state:Dictionary={}
var mobile_reflow_pending:=false

func _ready()->void:
	add_to_group("chapter01_game")
	add_child(progression)
	var state:=SaveManager.load_state()
	if not bool(state.get("act0_complete",false)):
		push_error("Act 1 scene requires a completed Act 0 save")
		return
	progression.restore(state)
	_restore_state(state)
	last_committed_state=state.duplicate(true)
	_apply_identity_and_equipment(state)
	_apply_world_state(state)
	_connect_runtime()
	_report_gameplay_state()
	_show_resume_objective()

func _connect_runtime()->void:
	encounter.reset_shadow()
	encounter.set_reduced_motion(reduced_motion)
	encounter.set_turn_meter_mode_enabled(true)
	pack_combat.set_reduced_motion(reduced_motion)
	pack_combat.set_presentation_timeline_enabled(true)
	pack_combat.set_turn_meter_mode_enabled(true)
	hud.skill_pressed.connect(_on_skill)
	encounter.encounter_started.connect(_on_single_started)
	encounter.combat_state_changed.connect(hud.render_state)
	encounter.shadow_attack_presented.connect(presenter.play_shadow_attack)
	encounter.enemy_attack_presented.connect(presenter.play_enemy_attack)
	encounter.enemy_attack_presented.connect(_on_enemy_attack_visual)
	encounter.encounter_finished.connect(_on_single_finished)
	encounter.encounter_failed.connect(_on_single_failed)
	pack_combat.finished.connect(_on_pack_unexpected_finish)
	pack_combat.failed.connect(_resolve_pack_defeat)
	pack_combat.solo_limit_reached.connect(_resolve_pack_defeat)
	pack_combat.state_changed.connect(pack_hud.render)
	pack_combat.shadow_attack_presented.connect(_on_pack_shadow_attack_presented)
	pack_combat.enemy_attack_presented.connect(_on_pack_enemy_attack_visual)
	pack_combat.semantic_contact.connect(_on_pack_semantic_contact)
	pack_hud.target_selected.connect(_select_pack_target)
	pack_hud.skill_pressed.connect(_pack_action)
	mobile_controls.direction_changed.connect(_on_mobile_direction)
	settings_button.pressed.connect(_open_settings)
	settings_menu.performance_mode_changed.connect(_on_performance_mode_changed)
	settings_menu.reduced_motion_changed.connect(_on_reduced_motion_changed)
	settings_menu.menu_opened.connect(_refresh_navigation)
	settings_menu.menu_closed.connect(_refresh_navigation)
	if not platform_runtime.memory_pressure.is_connected(_on_platform_memory_pressure):
		platform_runtime.memory_pressure.connect(_on_platform_memory_pressure)
	platform_runtime.report_state("com.shadowborn.presentation",performance_mode,{"reduced_motion":reduced_motion})
	watch_menu.accepted.connect(_accept_temple_watch)
	watch_menu.menu_opened.connect(_refresh_navigation)
	watch_menu.menu_closed.connect(_refresh_navigation)
	if OS.is_debug_build():
		combat_trace=CombatFrameTrace.new()
		var trace_console:=bool(ProjectSettings.get_setting("debug/shadowborn/combat_trace_console",true))
		if "--shadowborn-trace-quiet" in OS.get_cmdline_user_args() or "--shadowborn-trace-quiet" in OS.get_cmdline_args():
			trace_console=false
		combat_trace.set_console_output(trace_console)
		add_child(combat_trace)
		combat_trace.attach(encounter,presenter,hud)
		combat_trace.attach_multi(pack_combat)
		combat_trace.set_context(performance_mode,reduced_motion)

func _restore_state(state:Dictionary)->void:
	cleared_encounters.assign(state.get("cleared_encounters",[]))
	var p:Array=state.get("checkpoint_position",[Act1Layout.SEWER_ENTRY.x,Act1Layout.SEWER_ENTRY.y,Act1Layout.SEWER_ENTRY.z])
	checkpoint_position=Vector3(float(p[0]),float(p[1]),float(p[2]))
	shadow.global_position=checkpoint_position
	shadow.velocity=Vector3.ZERO
	performance_mode=str(state.get("performance_mode","smooth60"))
	reduced_motion=bool(state.get("reduced_motion",false))
	_apply_performance_mode()
	_apply_presentation_settings()

func _apply_identity_and_equipment(state:Dictionary)->void:
	shadow_proxy.apply_identity(str(state.get("shadow_identity","male")))
	var family:=str(state.get("weapon_family",""))
	shadow_proxy.set_weapon_family(family)
	encounter.set_loadout(family)
	pack_combat.set_loadout(family)

func _apply_world_state(state:Dictionary)->void:
	for node in get_tree().get_nodes_in_group("encounter_visual"):
		var id:=str(node.get_meta("encounter_id",""))
		if id in Act1Contract.all_encounter_ids():
			node.visible=id not in cleared_encounters
	for companion in get_tree().get_nodes_in_group("story_companion_visual"):
		if companion is Node3D:
			(companion as Node3D).visible=bool(state.get("story_summon_unlocked",false))

func _build_save_state()->Dictionary:
	var state:=SaveManager.load_state()
	state.checkpoint_position=[checkpoint_position.x,checkpoint_position.y,checkpoint_position.z]
	state.cleared_encounters=cleared_encounters.duplicate()
	state.performance_mode=performance_mode
	state.reduced_motion=reduced_motion
	var progression_state:=progression.snapshot()
	for key in progression_state:
		state[key]=progression_state[key]
	return state

func _save_progress()->bool:
	var candidate:=_build_save_state()
	if not SaveManager.save_state(candidate):
		push_error("Act 1 save transaction failed")
		return false
	last_committed_state=SaveManager._migrate(candidate.duplicate(true))
	return true

func _restore_runtime(state:Dictionary)->void:
	progression.restore(state)
	cleared_encounters.assign(state.get("cleared_encounters",[]))
	var p:Array=state.get("checkpoint_position",[Act1Layout.SEWER_ENTRY.x,.9,Act1Layout.SEWER_ENTRY.z])
	checkpoint_position=Vector3(float(p[0]),float(p[1]),float(p[2]))
	shadow.global_position=checkpoint_position
	shadow.velocity=Vector3.ZERO
	_apply_world_state(state)

func enter_sewer_room(room:int)->void:
	if pack_active or encounter.active or progression.stage in [Act1Contract.STAGE_TEMPLE_RETURN,Act1Contract.STAGE_KEEPER_BRIEFING,Act1Contract.STAGE_SMITH_HANDOFF,Act1Contract.STAGE_GUARD_COVENANT,Act1Contract.STAGE_ACT1_1_COMPLETE]:
		return
	if room!=progression.sewer_room or Act1Contract.room_for_stage(progression.stage)!=room:
		return
	var enemies:=SewerEncounterPlan.enemies(room)
	if room in [1,2] and enemies.size()==1:
		_start_single(room,Dictionary(enemies[0]))
	elif room==3 and enemies.size()==2:
		_start_pack(enemies)

func _on_single_started(id:String)->void:
	hud.show_combat(id)
	platform_runtime.report_state("com.shadowborn.encounter","single",{"id":id})

func _report_gameplay_state()->void:
	var in_temple:=progression.stage in [
		Act1Contract.STAGE_TEMPLE_RETURN,
		Act1Contract.STAGE_KEEPER_BRIEFING,
		Act1Contract.STAGE_SMITH_HANDOFF,
		Act1Contract.STAGE_GUARD_COVENANT,
		Act1Contract.STAGE_ACT1_1_COMPLETE
	]
	platform_runtime.report_state(
		"com.shadowborn.gameplay",
		"temple" if in_temple else "act1_sewer",
		{"chapter":"act1"}
	)

func _start_single(_room:int,profile:Dictionary)->void:
	var id:=str(profile.get("id",""))
	if id in cleared_encounters:
		return
	var visual:=_find_enemy_visual(id)
	if not is_instance_valid(visual):
		push_error("Act 1 encounter visual missing: "+id)
		return
	shadow.set_physics_process(false)
	active_enemy_visual=visual
	if not visual.has_meta("combat_home_transform"):
		visual.set_meta("combat_home_transform",visual.global_transform)
	var center:=visual.global_position
	shadow.global_position=center+Vector3(-2.6,0,1.0)
	visual.look_at(Vector3(shadow.global_position.x,visual.global_position.y,shadow.global_position.z),Vector3.UP)
	camera_rig.enter_combat(shadow.global_position,visual.global_position)
	presenter.bind_combatants(shadow,visual)
	if not encounter.start_encounter(id,profile):
		_restore_single_visual()
		active_enemy_visual=null
		presenter.clear()
		camera_rig.exit_combat()
		shadow.set_physics_process(true)
		_refresh_navigation()
		return
	_refresh_navigation()

func _restore_single_visual()->void:
	if not is_instance_valid(active_enemy_visual): return
	if active_enemy_visual.has_meta("combat_home_transform"):
		active_enemy_visual.global_transform=active_enemy_visual.get_meta("combat_home_transform")

func _find_enemy_visual(id:String)->Node3D:
	for node in get_tree().get_nodes_in_group("encounter_visual"):
		if str(node.get_meta("encounter_id",""))==id:
			return node as Node3D
	return null

func _room_for_enemy(id:String)->int:
	for room in range(1,3):
		if id in Act1Contract.encounter_ids(room): return room
	return 0

func _on_single_finished(id:String)->void:
	platform_runtime.report_state("com.shadowborn.encounter","none",{})
	var room:=_room_for_enemy(id)
	if room==0: return
	var before:=_build_save_state()
	var defeated:=active_enemy_visual
	hud.hide_combat()
	camera_rig.exit_combat()
	if not progression.room_cleared(room):
		shadow.set_physics_process(true)
		_refresh_navigation()
		return
	if id not in cleared_encounters: cleared_encounters.append(id)
	checkpoint_position=Act1Layout.room_checkpoint(room+1)
	var checkpoint_id:="act1_room1_cleared" if room==1 else "act1_room2_cleared"
	var candidate:=_build_save_state()
	candidate.checkpoint=checkpoint_id
	if not SaveManager.save_state(candidate):
		_restore_runtime(before)
		_restore_single_visual()
		story_toast.show_message("The sewer checkpoint could not be saved. The room remains unresolved.")
	else:
		last_committed_state=SaveManager._migrate(candidate.duplicate(true))
		presenter.play_enemy_death()
		await get_tree().create_timer(.08 if reduced_motion else .30).timeout
		if is_instance_valid(defeated): defeated.visible=false
		story_toast.show_message("A fouler scent drifts from the next chamber." if room==1 else "Scratching multiplies beyond the next arch.")
	active_enemy_visual=null
	presenter.clear()
	shadow.global_position=checkpoint_position
	shadow.velocity=Vector3.ZERO
	shadow.set_physics_process(true)
	_refresh_navigation()

func _on_single_failed(_id:String)->void:
	platform_runtime.report_state("com.shadowborn.encounter","none",{})
	hud.hide_combat()
	camera_rig.exit_combat()
	_restore_single_visual()
	active_enemy_visual=null
	presenter.clear()
	shadow.global_position=checkpoint_position
	shadow.velocity=Vector3.ZERO
	shadow.set_physics_process(true)
	story_toast.show_message("The sewer rejects you. The last committed checkpoint still holds.")
	_refresh_navigation()

func _pack_visuals()->Array[Node3D]:
	if pack_visual_cache.size()==2 and is_instance_valid(pack_visual_cache[0]) and is_instance_valid(pack_visual_cache[1]):
		return pack_visual_cache
	pack_visual_cache.clear()
	for id in ["a1_r3_rat_a","a1_r3_rat_b"]:
		var v:=_find_enemy_visual(id)
		if v: pack_visual_cache.append(v)
	return pack_visual_cache

func _start_pack(enemies:Array)->void:
	if _pack_visuals().size()!=2:
		push_error("Act 1 pack chamber requires exactly two rat visuals")
		return
	if not pack_combat.start(enemies,false,true):
		return
	pack_active=true
	platform_runtime.report_state("com.shadowborn.encounter","pack",{"id":"a1_room3_pack"})
	shadow.set_physics_process(false)
	shadow.global_position=Act1Layout.ROOM3_SHADOW_POSITION
	for v in _pack_visuals():
		v.visible=true
		v.scale=Vector3.ONE
		v.look_at(Vector3(shadow.global_position.x,v.global_position.y,shadow.global_position.z),Vector3.UP)
		if v.has_method("play_threat_cue"):
			v.play_threat_cue()
	camera_rig.enter_combat(shadow.global_position,Act1Layout.ROOM3_FOCUS)
	pack_hud.open()
	_refresh_navigation()

func _select_pack_target(index:int)->void:
	if not pack_active or _ui_modal_open(): return
	pack_combat.select_target(index)
	var visuals:=_pack_visuals()
	for i in range(visuals.size()):
		visuals[i].scale=Vector3.ONE*1.08 if i==index else Vector3.ONE

func _pack_action(skill:String)->void:
	if pack_active and not _ui_modal_open():
		pack_combat.shadow_action(skill)

func _on_pack_shadow_attack_presented(target_index:int,skill:String,damage:float)->void:
	var visuals:=_pack_visuals()
	if target_index<0 or target_index>=visuals.size():
		return
	var target:=visuals[target_index]
	if not is_instance_valid(target):
		return
	presenter.bind_combatants(shadow,target)
	presenter.play_shadow_attack(skill,damage,false)

func _on_pack_enemy_attack_visual(enemy_index:int,damage:float)->void:
	var visuals:=_pack_visuals()
	if enemy_index>=0 and enemy_index<visuals.size():
		var attacker:=visuals[enemy_index]
		if is_instance_valid(attacker):
			presenter.bind_combatants(shadow,attacker)
			presenter.play_enemy_attack(damage)
			if attacker.has_method("play_attack_cue"):
				attacker.play_attack_cue()

func _on_pack_semantic_contact(actor:String,index:int,_action:String)->void:
	if actor not in ["shadow","companion"]:
		return
	var visuals:=_pack_visuals()
	if index>=0 and index<visuals.size():
		var target:=visuals[index]
		if is_instance_valid(target) and target.has_method("play_hit_cue"):
			target.play_hit_cue()

func _resolve_pack_defeat()->void:
	if not pack_active and progression.stage!=Act1Contract.STAGE_SEWER_ROOM3:
		return
	platform_runtime.report_state("com.shadowborn.encounter","none",{})
	var before:=_build_save_state()
	pack_hud.close()
	pack_active=false
	camera_rig.exit_combat()
	presenter.clear()
	if not progression.commit_pack_defeat():
		shadow.set_physics_process(true)
		_refresh_navigation()
		return
	checkpoint_position=Act1Layout.TEMPLE_RETURN
	var candidate:=_build_save_state()
	candidate.checkpoint="act1_temple_return"
	if not SaveManager.save_state(candidate):
		_restore_runtime(before)
		story_toast.show_message("The retreat could not be anchored. Enter the pack chamber again.")
	else:
		last_committed_state=SaveManager._migrate(candidate.duplicate(true))
		shadow.global_position=checkpoint_position
		shadow.velocity=Vector3.ZERO
		story_toast.show_message("Two rats move as one pack. You cannot hold them alone. Return to the Keeper.",4.5)
	_report_gameplay_state()
	shadow.set_physics_process(true)
	_refresh_navigation()

func _on_pack_unexpected_finish()->void:
	# The first pack chamber is a story limit. Even extreme future damage cannot
	# turn it into a progression skip.
	_resolve_pack_defeat()

func temple_interact(kind:String)->void:
	match kind:
		"keeper": _keeper_handoff()
		"smith": _smith_handoff()
		"guard": _guard_offer()

func _keeper_handoff()->void:
	if progression.stage!=Act1Contract.STAGE_TEMPLE_RETURN:
		return
	var before:=_build_save_state()
	if not progression.keeper_briefing(): return
	checkpoint_position=Act1Layout.TEMPLE_RETURN
	var candidate:=_build_save_state()
	candidate.checkpoint="act1_keeper_briefed"
	if not SaveManager.save_state(candidate):
		_restore_runtime(before)
		return
	last_committed_state=SaveManager._migrate(candidate.duplicate(true))
	story_toast.show_message("Keeper: Those were scouts. Packs answer to something deeper. See the Smith, then swear before the Temple Guard.",5.0)

func _smith_handoff()->void:
	if progression.stage!=Act1Contract.STAGE_KEEPER_BRIEFING:
		return
	var before:=_build_save_state()
	if not progression.smith_handoff(): return
	checkpoint_position=Vector3(Act1Layout.SMITH_HANDOFF.x,.9,Act1Layout.SMITH_HANDOFF.z)
	var candidate:=_build_save_state()
	candidate.checkpoint="act1_smith_handoff"
	if not SaveManager.save_state(candidate):
		_restore_runtime(before)
		return
	last_committed_state=SaveManager._migrate(candidate.duplicate(true))
	story_toast.show_message("Smith: Steel is not the problem. You need a bond that can hold formation. The Guard keeps that oath.",4.6)

func _guard_offer()->void:
	if progression.stage==Act1Contract.STAGE_GUARD_COVENANT:
		_recover_temple_watch_completion()
		return
	if progression.stage!=Act1Contract.STAGE_SMITH_HANDOFF:
		return
	watch_menu.open()
	_refresh_navigation()

func _commit_temple_watch_completion(before:Dictionary,success_message:String,failure_message:String)->bool:
	if not progression.complete_act1_1():
		_restore_runtime(before)
		return false
	checkpoint_position=Vector3(Act1Layout.GUARD_POSITION.x,.9,Act1Layout.GUARD_POSITION.z)
	var candidate:=_build_save_state()
	candidate.checkpoint="act1_guard_covenant"
	if not SaveManager.save_state(candidate):
		_restore_runtime(before)
		story_toast.show_message(failure_message)
		return false
	last_committed_state=SaveManager._migrate(candidate.duplicate(true))
	story_toast.show_message(success_message,5.0)
	return true

func _recover_temple_watch_completion()->void:
	if not progression.temple_watch_covenant_joined or progression.act1_1_complete:
		return
	var before:=_build_save_state()
	_commit_temple_watch_completion(
		before,
		"Temple Guard: Your oath already stands. The Watch record is sealed.",
		"The Watch record could not be sealed. Your committed oath remains safe."
	)
	_refresh_navigation()

func _accept_temple_watch()->void:
	if not progression.guard_offer_ready():
		watch_menu.close()
		return
	var before:=_build_save_state()
	if not progression.join_temple_watch():
		_restore_runtime(before)
		watch_menu.close()
		return
	_commit_temple_watch_completion(
		before,
		"Temple Guard: Rise under the Watch. The next descent will not be made as a lone shadow.",
		"The oath could not be written. The Temple Watch has not accepted you."
	)
	watch_menu.close()
	_refresh_navigation()

func _on_enemy_attack_visual(_damage:float)->void:
	if is_instance_valid(active_enemy_visual) and active_enemy_visual.has_method("play_attack_cue"):
		active_enemy_visual.play_attack_cue()

func _show_resume_objective()->void:
	var message:=""
	match progression.stage:
		Act1Contract.STAGE_SEWER_ROOM1:
			message="ACT 1 — Beneath the Temple. Follow the gutter to the first chamber."
		Act1Contract.STAGE_SEWER_ROOM2:
			message="The air has turned sour. The next chamber is tainted."
		Act1Contract.STAGE_SEWER_ROOM3:
			message="Scratching multiplies ahead. Something is moving as a pack."
		Act1Contract.STAGE_TEMPLE_RETURN:
			message="The pack forced you back. Speak with the Keeper."
		Act1Contract.STAGE_KEEPER_BRIEFING:
			message="The Keeper has warned you. Take her message to the Smith."
		Act1Contract.STAGE_SMITH_HANDOFF:
			message="Steel alone will not hold. Find the Temple Guard."
		Act1Contract.STAGE_GUARD_COVENANT:
			message="Your Temple Watch oath stands. Return to the Guard to seal the Watch record."
		Act1Contract.STAGE_ACT1_1_COMPLETE:
			message="The Temple Watch oath is sealed. The next descent is not yet open."
	if not message.is_empty():
		story_toast.show_message(message,4.2)

func _ui_modal_open()->bool:
	return settings_menu.panel.visible or watch_menu.visible

func _refresh_navigation()->void:
	var enabled:=not _ui_modal_open() and not encounter.active and not pack_active
	settings_button.disabled=encounter.active or pack_active or watch_menu.visible
	shadow.set_input_enabled(enabled)
	mobile_controls.set_enabled(enabled)

func _on_skill(skill:String)->void:
	if not _ui_modal_open(): encounter.shadow_action(skill)

func _on_mobile_direction(direction:Vector2)->void:
	shadow.set_virtual_direction(direction)

func _open_settings()->void:
	if encounter.active or pack_active or watch_menu.visible: return
	settings_menu.open(performance_mode,reduced_motion)

func _on_performance_mode_changed(mode:String)->void:
	performance_mode=mode
	_apply_performance_mode()
	if combat_trace:
		combat_trace.set_context(performance_mode,reduced_motion)
	platform_runtime.report_state("com.shadowborn.presentation",performance_mode,{"reduced_motion":reduced_motion})
	_save_progress()

func _on_reduced_motion_changed(value:bool)->void:
	reduced_motion=value
	_apply_presentation_settings()
	if combat_trace:
		combat_trace.set_context(performance_mode,reduced_motion)
	platform_runtime.report_state("com.shadowborn.presentation",performance_mode,{"reduced_motion":reduced_motion})
	_save_progress()

func _apply_performance_mode()->void:
	platform_runtime.set_requested_mode(performance_mode)

func _apply_presentation_settings()->void:
	camera_rig.set_reduced_motion(reduced_motion)
	presenter.set_reduced_motion(reduced_motion)
	encounter.set_reduced_motion(reduced_motion)
	pack_combat.set_reduced_motion(reduced_motion)
	for npc in get_tree().get_nodes_in_group("temple_npc_idle"):
		if npc.has_method("set_reduced_motion"): npc.set_reduced_motion(reduced_motion)
	for rat in get_tree().get_nodes_in_group("act1_rat_visual"):
		if rat.has_method("set_reduced_motion"): rat.set_reduced_motion(reduced_motion)

func _notification(what:int)->void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:
		if not is_node_ready(): return
		mobile_controls.reset_input()
		if what==NOTIFICATION_APPLICATION_PAUSED and not last_committed_state.is_empty():
			if not SaveManager.save_state(last_committed_state.duplicate(true)):
				push_error("iOS suspend save failed; last committed Act 1 state remains in memory")
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN,NOTIFICATION_APPLICATION_RESUMED]:
		if is_node_ready(): _queue_mobile_reflow()

func _on_platform_memory_pressure(_count:int)->void:
	# PlatformRuntime owns the OS notification. Act 1 only releases its own
	# reconstructible visual lookup cache.
	pack_visual_cache.clear()

func _queue_mobile_reflow()->void:
	if mobile_reflow_pending: return
	mobile_reflow_pending=true
	call_deferred("_resume_mobile_session")

func _resume_mobile_session()->void:
	mobile_reflow_pending=false
	if not is_inside_tree(): return
	iphone_ui_layout.apply_safe_area()
	_refresh_navigation()