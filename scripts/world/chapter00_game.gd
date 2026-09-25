class_name Chapter00Game
extends Node

@onready var encounter: EncounterController = $EncounterController
@onready var hud: CombatHUD = $CombatHUD
@onready var shadow: CharacterBody3D = get_parent().get_node("Shadow")
@onready var director: Chapter00Director = get_parent().get_node("Director")
@onready var camera_rig: CameraDirector = get_parent().get_node("CameraRig")
@onready var presenter: CombatPresenter = $CombatPresenter
@onready var settings_menu: SettingsMenu = $SettingsMenu
@onready var settings_button: Button = $CombatHUD/SettingsButton
@onready var covenant_menu:CovenantMenu=$CovenantMenu
@onready var mobile_controls:MobileControls=$MobileControls
@onready var shadow_proxy:ShadowProxy=get_parent().get_node("Shadow/ShadowProxy")
@onready var story_toast:StoryToast=$StoryToast
@onready var iphone_ui_layout:IPhoneUILayout=$IPhoneUILayout
var checkpoint_position := Vector3(0,0.9,8)
var active_enemy_visual: Node3D
var cleared_encounters: Array[String] = []
var performance_mode := "smooth60"
var reduced_motion:=false
var act0 := Act0Progression.new()
var catacombs := CatacombProgression.new()
var team := TeamState.new()
var act0_flow := Act0Orchestrator.new()
@onready var room5_combat:MultiEnemyEncounter=$Room5Combat
@onready var room5_hud:MultiTargetHUD=$MultiTargetHUD
var room5_active := false
var room5_solo_attempt := false
var room5_visual_cache:Array[Node3D]=[]
var combat_trace:CombatFrameTrace
var last_committed_state:Dictionary={}
var mobile_reflow_pending:=false

func _ready() -> void:
	add_to_group("chapter00_game")
	add_child(act0); add_child(catacombs); add_child(team); add_child(act0_flow)
	var persisted := SaveManager.load_state()
	_restore_save(persisted)
	last_committed_state=persisted.duplicate(true)
	act0_flow.setup(act0, catacombs, get_parent().get_node("SaveManager"))
	act0_flow.restore(persisted); team.restore(persisted)
	_apply_identity_state(persisted)
	_apply_equipment_state()
	_restore_act0_position()
	_apply_threshold_visual_state()
	act0_flow.companion_ready.connect(_on_companion_ready)
	room5_combat.finished.connect(_on_room5_finished)
	room5_combat.failed.connect(_on_room5_failed)
	room5_combat.solo_limit_reached.connect(_on_room5_solo_limit)
	room5_combat.state_changed.connect(room5_hud.render)
	room5_hud.target_selected.connect(room5_select_target)
	room5_hud.skill_pressed.connect(room5_action)
	covenant_menu.weapon_requested.connect(_on_covenant_weapon_requested)
	covenant_menu.menu_opened.connect(_refresh_navigation)
	covenant_menu.menu_closed.connect(_refresh_navigation)
	settings_menu.menu_opened.connect(_refresh_navigation)
	settings_menu.menu_closed.connect(_refresh_navigation)
	mobile_controls.direction_changed.connect(_on_mobile_direction)
	encounter.reset_shadow()
	hud.skill_pressed.connect(_on_combat_skill_requested)
	encounter.encounter_started.connect(_on_started)
	encounter.combat_state_changed.connect(hud.render_state)
	encounter.combat_state_changed.connect(_on_combat_state)
	encounter.shadow_attack_presented.connect(presenter.play_shadow_attack)
	encounter.enemy_attack_presented.connect(presenter.play_enemy_attack)
	encounter.enemy_beat_presented.connect(presenter.play_enemy_beat)
	encounter.encounter_finished.connect(_on_finished)
	encounter.encounter_failed.connect(_on_failed)
	settings_button.pressed.connect(_open_settings)
	settings_menu.performance_mode_changed.connect(_on_performance_mode_changed)
	settings_menu.reduced_motion_changed.connect(_on_reduced_motion_changed)
	if OS.is_debug_build():
		combat_trace=CombatFrameTrace.new()
		var trace_console:=bool(ProjectSettings.get_setting("debug/shadowborn/combat_trace_console",true))
		if "--shadowborn-trace-quiet" in OS.get_cmdline_user_args() or "--shadowborn-trace-quiet" in OS.get_cmdline_args():
			trace_console=false
		combat_trace.set_console_output(trace_console)
		add_child(combat_trace)
		combat_trace.attach(encounter,presenter,hud)
		combat_trace.set_context(performance_mode,reduced_motion)
	call_deferred("_apply_cleared_visuals")
	call_deferred("_apply_presentation_settings")

func _restore_save(state:Dictionary) -> void:
	director.checkpoint = str(state.checkpoint)
	director.set_route_index(int(state.route_index))
	var p: Array = state.checkpoint_position
	checkpoint_position = Vector3(float(p[0]),float(p[1]),float(p[2]))
	shadow.global_position = checkpoint_position
	cleared_encounters.assign(state.cleared_encounters)
	performance_mode = str(state.performance_mode)
	reduced_motion=bool(state.get("reduced_motion",false))
	_apply_performance_mode()
	_apply_presentation_settings()

func _apply_performance_mode() -> void:
	Engine.max_fps = 30 if performance_mode == "battery30" else 60

func _open_settings() -> void:
	if encounter.active or room5_active or covenant_menu.panel.visible:
		return
	settings_menu.open(performance_mode,reduced_motion)

func _on_performance_mode_changed(mode: String) -> void:
	performance_mode = mode
	_apply_performance_mode()
	if combat_trace:
		combat_trace.set_context(performance_mode,reduced_motion)
	_save_progress()

func _on_reduced_motion_changed(value:bool)->void:
	reduced_motion=value
	_apply_presentation_settings()
	if combat_trace:
		combat_trace.set_context(performance_mode,reduced_motion)
	_save_progress()

func _apply_presentation_settings()->void:
	camera_rig.set_reduced_motion(reduced_motion)
	presenter.set_reduced_motion(reduced_motion)
	encounter.set_reduced_motion(reduced_motion)
	for npc in get_tree().get_nodes_in_group("temple_npc_idle"):
		if npc.has_method("set_reduced_motion"):
			npc.set_reduced_motion(reduced_motion)

func _build_save_state()->Dictionary:
	var state := SaveManager.load_state()
	state.merge({"version":SaveManager.SAVE_VERSION,"checkpoint":director.checkpoint,"route_index":director.route_index,"checkpoint_position":[checkpoint_position.x,checkpoint_position.y,checkpoint_position.z],"cleared_encounters":cleared_encounters,"performance_mode":performance_mode,"reduced_motion":reduced_motion}, true)
	var temple_state:=act0.snapshot()
	var cat_state:=catacombs.snapshot()
	for k in temple_state:
		state[k]=temple_state[k]
	for k in cat_state:
		state[k]=cat_state[k]
	return state

func _save_progress()->bool:
	var candidate:=_build_save_state()
	var ok:=SaveManager.save_state(candidate)
	if ok:
		last_committed_state=SaveManager._migrate(candidate.duplicate(true))
	else:
		push_error("Act 0 save transaction failed")
	return ok

func _notification(what:int)->void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:
		if not is_node_ready():
			return
		# iOS system overlays can steal a held touch without delivering the
		# matching release event. Always neutralize virtual movement.
		mobile_controls.reset_input()
		if what==NOTIFICATION_APPLICATION_PAUSED:
			if not last_committed_state.is_empty() and not SaveManager.save_state(last_committed_state.duplicate(true)):
				push_error("iOS suspend save failed; last committed Act 0 state remains in memory")
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN,NOTIFICATION_APPLICATION_RESUMED]:
		if not is_node_ready():
			return
		_queue_mobile_reflow()
	elif what==NOTIFICATION_OS_MEMORY_WARNING:
		# iOS can request memory relief at any point. Only clear rebuildable
		# references; progression and committed save state remain untouched.
		room5_visual_cache.clear()

func _queue_mobile_reflow()->void:
	if mobile_reflow_pending:
		return
	mobile_reflow_pending=true
	call_deferred("_resume_mobile_session")

func _resume_mobile_session()->void:
	mobile_reflow_pending=false
	if not is_inside_tree():
		return
	iphone_ui_layout.apply_safe_area()
	_refresh_navigation()

func _restore_runtime_snapshot(state:Dictionary,restore_position:bool=true)->void:
	act0.restore(state)
	catacombs.restore(state)
	team.restore(state)
	act0_flow.restore(state)
	cleared_encounters.assign(state.get("cleared_encounters",[]))
	director.set_route_index(int(state.get("route_index",0)))
	director.set_checkpoint(str(state.get("checkpoint","awakening")))
	var p:Array=state.get("checkpoint_position",[0.0,0.9,8.0])
	checkpoint_position=Vector3(float(p[0]),float(p[1]),float(p[2]))
	_apply_equipment_state()
	_apply_threshold_visual_state()
	if restore_position:
		shadow.global_position=checkpoint_position
		shadow.velocity=Vector3.ZERO

func _commit_first_forge_transaction()->bool:
	var candidate:=act0.first_forge_candidate()
	if candidate.is_empty():
		return false
	var state:=_build_save_state()
	state["silver"]=act0.silver-1
	state["forged_item"]=candidate.duplicate(true)
	state["first_forge_done"]=true
	state["act0_stage"]=Act0Contract.STAGE_CATACOMBS
	if not SaveManager.save_state(state):
		return false
	last_committed_state=SaveManager._migrate(state.duplicate(true))
	if act0.apply_first_forge(candidate):
		_apply_equipment_state()
		return true
	# Disk is authoritative once promotion succeeds. If an unexpected
	# in-memory precondition changes, converge to the committed snapshot.
	act0.restore(state)
	_apply_equipment_state()
	return true

func is_encounter_cleared(id: String) -> bool:
	return id in cleared_encounters

func begin_encounter(id: String, profile: Dictionary) -> bool:
	if encounter.active or room5_active or is_encounter_cleared(id):
		return false
	if Act0Contract.is_exterior_encounter(id) and not Act0Contract.can_start_exterior_encounter(id,cleared_encounters,act0.temple_reveal_seen):
		story_toast.show_message("The path refuses to advance. An earlier threat still remains.")
		return false

	var visual:=_find_enemy_visual(id)
	if visual==null:
		push_error("Encounter has no world visual: "+id)
		return false

	shadow.set_physics_process(false)
	active_enemy_visual=visual
	_position_combatants(active_enemy_visual)
	camera_rig.enter_combat(shadow.global_position,active_enemy_visual.global_position)
	presenter.bind_combatants(shadow,active_enemy_visual)

	if not encounter.start_encounter(id,profile):
		_restore_enemy_visual_home()
		active_enemy_visual=null
		presenter.clear()
		camera_rig.exit_combat()
		shadow.set_physics_process(true)
		_refresh_navigation()
		return false
	return true

func _find_enemy_visual(id: String) -> Node3D:
	for node in get_tree().get_nodes_in_group("encounter_visual"):
		if node.get_meta("encounter_id", "") == id: return node as Node3D
	return null

func _apply_cleared_visuals() -> void:
	for node in get_tree().get_nodes_in_group("encounter_visual"):
		if is_encounter_cleared(str(node.get_meta("encounter_id", ""))): node.visible = false

func _position_combatants(enemy_visual: Node3D) -> void:
	if not enemy_visual.has_meta("combat_home_transform"):
		enemy_visual.set_meta("combat_home_transform",enemy_visual.global_transform)
	if not enemy_visual.has_meta("combat_home_position"):
		enemy_visual.set_meta("combat_home_position",enemy_visual.global_position)
	var center:Vector3=enemy_visual.get_meta("combat_home_position")
	shadow.global_position = center + Vector3(-2.8, 0.0, 1.1)
	enemy_visual.global_position = center + Vector3(2.4, 0.0, -0.6)
	shadow.look_at(Vector3(enemy_visual.global_position.x, shadow.global_position.y, enemy_visual.global_position.z), Vector3.UP)
	enemy_visual.look_at(Vector3(shadow.global_position.x, enemy_visual.global_position.y, shadow.global_position.z), Vector3.UP)

func _restore_visual_home(visual:Node3D)->void:
	if not is_instance_valid(visual):
		return
	if visual.has_meta("combat_home_transform"):
		var home=visual.get_meta("combat_home_transform")
		if typeof(home)==TYPE_TRANSFORM3D:
			visual.global_transform=home
			return
	if visual.has_meta("combat_home_position"):
		visual.global_position=visual.get_meta("combat_home_position")
	visual.scale=Vector3.ONE

func _restore_enemy_visual_home()->void:
	_restore_visual_home(active_enemy_visual)

func _on_started(id: String) -> void:
	hud.show_combat(id)
	_refresh_navigation()

func _on_combat_state(state: Dictionary) -> void:
	if not is_instance_valid(active_enemy_visual): return
	var e: Dictionary = state.get("enemy", {})
	var shield := active_enemy_visual.get_node_or_null("Shield") as Node3D
	if shield:
		var guarded: bool = bool(e.get("guard", false))
		shield.rotation_degrees.x = -18.0 if guarded else 8.0
		shield.position.z = -0.42 if guarded else -0.18

func _on_finished(id: String) -> void:
	var before_state:=_build_save_state()
	var first_clear := id not in cleared_encounters
	var cat_room := _catacomb_room_for_encounter(id)
	var residual_beat:=false
	var shield_threshold_beat:=false
	var transition_valid:=true
	var defeated_visual:=active_enemy_visual
	presenter.play_enemy_death()
	await get_tree().create_timer(0.30).timeout
	hud.hide_combat()
	if is_instance_valid(defeated_visual):
		defeated_visual.visible=false
	active_enemy_visual = null
	presenter.clear()
	camera_rig.exit_combat()
	shadow.set_physics_process(true)
	_refresh_navigation()

	if first_clear:
		cleared_encounters.append(id)
		if id=="hound":
			residual_beat=act0.mark_hound_residual_absorbed()
			transition_valid=residual_beat
		elif id=="shield_boss":
			act0.silver+=1
			transition_valid=act0.transition_to(Act0Contract.STAGE_TEMPLE_ENTRY)
			shield_threshold_beat=transition_valid

	checkpoint_position=shadow.global_position
	director.set_checkpoint(id+"_cleared")
	if first_clear and Act0Contract.is_exterior_encounter(id):
		director.mark_exterior_encounter_cleared(id)
	if cat_room>0:
		transition_valid=act0_flow.room_cleared(cat_room) and transition_valid

	if not transition_valid or not _save_progress():
		_restore_runtime_snapshot(before_state)
		if is_instance_valid(defeated_visual):
			defeated_visual.visible=true
			_restore_visual_home(defeated_visual)
		encounter.reset_shadow()
		story_toast.show_message("The victory could not be anchored. The encounter must be faced again.")
		_refresh_navigation()
		return

	if residual_beat:
		shadow_proxy.play_residual_absorption()
		story_toast.show_message("The fading residual answers the Shadow. Its echo is absorbed.",2.8)
	elif shield_threshold_beat:
		story_toast.show_message("Silver remains in the broken shield. Ahead, a Faded Sigil stirs at the Temple threshold.",3.6)

func _on_failed(_id: String) -> void:
	hud.hide_combat()
	_restore_enemy_visual_home()
	active_enemy_visual = null
	presenter.clear()
	camera_rig.exit_combat()
	encounter.reset_shadow()
	shadow.global_position = checkpoint_position
	shadow.velocity = Vector3.ZERO
	shadow.set_physics_process(true)
	_refresh_navigation()

func play_world_reveal(id:String)->bool:
	if id!="temple" or encounter.active or act0.temple_reveal_seen:
		return false
	if not is_encounter_cleared("armless") or act0.stage!=Act0Contract.STAGE_EXTERIOR:
		return false

	var before:=act0.snapshot()
	var previous_route:=director.route_index
	var previous_checkpoint:=director.checkpoint
	var previous_checkpoint_position:=checkpoint_position

	if not act0.mark_temple_reveal_seen():
		return false
	director.mark_temple_reveal_seen()
	checkpoint_position=shadow.global_position
	director.set_checkpoint("temple_reveal_seen")
	if not _save_progress():
		act0.restore(before)
		director.set_route_index(previous_route)
		director.set_checkpoint(previous_checkpoint)
		checkpoint_position=previous_checkpoint_position
		story_toast.show_message("The vision fractures. Progress could not be saved.")
		return false

	mobile_controls.set_enabled(false)
	shadow.set_physics_process(false)
	camera_rig.enter_reveal(Act0Layout.TEMPLE_REVEAL_CAMERA_TARGET)
	await get_tree().create_timer(0.45 if reduced_motion else 1.65).timeout
	camera_rig.exit_reveal()
	if not reduced_motion:
		await get_tree().create_timer(0.35).timeout
	shadow.set_physics_process(true)
	_refresh_navigation()
	return true


func activate_faded_sigil()->bool:
	if not is_encounter_cleared("shield_boss") or act0.stage!=Act0Contract.STAGE_TEMPLE_ENTRY:
		return false
	var before:=act0.snapshot()
	var previous_checkpoint:=checkpoint_position
	var previous_checkpoint_id:=director.checkpoint
	if not act0.activate_faded_sigil():
		return false
	checkpoint_position=Vector3(Act0Layout.FADED_SIGIL_TRIGGER.x,0.9,Act0Layout.FADED_SIGIL_TRIGGER.z)
	director.set_checkpoint("faded_sigil")
	if not _save_progress():
		act0.restore(before)
		checkpoint_position=previous_checkpoint
		director.set_checkpoint(previous_checkpoint_id)
		story_toast.show_message("The Sigil recoils. Progress could not be saved.")
		return false
	_apply_threshold_visual_state()
	shadow_proxy.play_residual_absorption()
	story_toast.show_message("The Faded Sigil recognizes the wounded Shadow. The Temple threshold yields.",3.2)
	return true

func enter_temple()->bool:
	if not is_encounter_cleared("shield_boss") or not act0.faded_sigil_activated:
		return false
	if act0.stage!=Act0Contract.STAGE_TEMPLE_ENTRY:
		return false
	var before_state:=_build_save_state()
	checkpoint_position=Act0Layout.TEMPLE_ENTRY_CHECKPOINT
	shadow.global_position=checkpoint_position
	shadow.velocity=Vector3.ZERO
	director.set_checkpoint("temple_entry")
	if not _save_progress():
		_restore_runtime_snapshot(before_state)
		story_toast.show_message("The Temple threshold rejects the crossing. Progress could not be saved.")
		return false
	story_toast.show_message("The Temple is quiet. A lone Keeper waits beyond the nave.")
	return true

func temple_interact(kind:String) -> void:
	_react_temple_npc(kind)
	match kind:
		"keeper":
			if act0.stage==Act0Contract.STAGE_TEMPLE_ENTRY:
				var before:=act0.snapshot()
				if act0.join_covenant():
					if _save_progress():
						story_toast.show_message("Keeper: The dead do not fear the dark. Only what wakes inside it. Bind your shape to the Forgotten Covenant.")
					else:
						act0.restore(before)
						story_toast.show_message("The Keeper falls silent. Progress could not be saved.")
			elif act0.stage==Act0Contract.STAGE_ROOM5_RETURN:
				var before_state:=_build_save_state()
				var before_checkpoint:=checkpoint_position
				var before_checkpoint_id:=director.checkpoint
				if act0_flow.temple_story_handoff():
					checkpoint_position=Act0Layout.ROOM5_RETURN_CHECKPOINT
					director.set_checkpoint("room5_rematch")
					if _save_progress():
						if not act0_flow.commit_story_handoff_presentation():
							push_error("Committed Room 5 story handoff could not emit presentation")
						var companion:=StoryCompanion.profile()
						story_toast.show_message("Keeper: One shadow has found its limit. %s answers the call. Formation slot 2 is active."%str(companion.get("name","A forgotten guardian")))
					else:
						act0.restore(before_state)
						catacombs.restore(before_state)
						team.restore(before_state)
						checkpoint_position=before_checkpoint
						director.set_checkpoint(before_checkpoint_id)
						story_toast.show_message("The summoning breaks before it settles. Progress could not be saved.")
		"covenant":
			if act0.covenant_joined and act0.weapon_family.is_empty():
				covenant_menu.open()
			elif not act0.covenant_joined:
				story_toast.show_message("The Covenant stone is silent. The Keeper has not named you yet.")
		"smith":
			if act0.stage==Act0Contract.STAGE_FIRST_FORGE:
				if _commit_first_forge_transaction():
					story_toast.show_message("Smith: Silver remembers heat. Your chosen form has an edge now. The lower passage will answer you.")
				else:
					story_toast.show_message("The forge cannot bind this state. Check the Silver and try again.")
			elif not act0.first_forge_done:
				story_toast.show_message("The forge waits for a Covenant weapon and one piece of Silver.")
		"merchant":
			story_toast.show_message("Merchant: The shelves are nearly bare. Trade opens after the first descent.")
		"engraver":
			story_toast.show_message("The engraver's stones are dormant. Runes will answer later.")
		"catacombs":
			var before_state:=_build_save_state()
			var before_position:=shadow.global_position
			var before_checkpoint:=checkpoint_position
			var before_checkpoint_id:=director.checkpoint
			if act0_flow.enter_catacombs():
				var current_room:=clampi(catacombs.room,1,5)
				checkpoint_position=Act0Layout.catacomb_room_resume_position(current_room)
				shadow.global_position=checkpoint_position
				shadow.velocity=Vector3.ZERO
				director.set_checkpoint(Act0Contract.catacomb_checkpoint_id(current_room))
				if _save_progress():
					story_toast.show_message("The lower passage opens. The air below carries old bone-dust.")
				else:
					act0.restore(before_state)
					catacombs.restore(before_state)
					checkpoint_position=before_checkpoint
					director.set_checkpoint(before_checkpoint_id)
					shadow.global_position=before_position
					shadow.velocity=Vector3.ZERO
					story_toast.show_message("The lower passage closes again. Progress could not be saved.")
			else:
				story_toast.show_message("The passage does not answer an unbound, unforged shadow.")

func _react_temple_npc(kind:String)->void:
	if kind not in ["keeper","smith","merchant","engraver"]:
		return
	for npc in get_tree().get_nodes_in_group("temple_npc_idle"):
		if str(npc.get("motion_profile"))==kind and npc.has_method("play_interaction_reaction"):
			npc.play_interaction_reaction()
			return

func choose_covenant_weapon(family:String) -> bool:
	var before:=act0.snapshot()
	if not act0.choose_weapon(family):
		return false
	if not _save_progress():
		act0.restore(before)
		story_toast.show_message("The Covenant rejects an unsaved choice. Choose again.")
		return false
	return true

func enter_catacomb_room(room:int) -> void:
	if catacombs.complete or act0.stage==Act0Contract.STAGE_COMPLETE:
		return
	if room!=catacombs.room:
		return
	var enemies:=CatacombEncounterPlan.enemies(room)
	if room==5 and not catacombs.summon_unlocked:
		if catacombs.room5_solo_limit_seen:
			var before_state:=_build_save_state()
			checkpoint_position=Act0Layout.ROOM5_RETURN_CHECKPOINT
			shadow.global_position=checkpoint_position
			shadow.velocity=Vector3.ZERO
			director.set_checkpoint("room5_return")
			if not _save_progress():
				_restore_runtime_snapshot(before_state)
				story_toast.show_message("The retreat point could not be saved. Progress remains at the last safe checkpoint.")
			return
		_start_room5_solo_attempt(enemies)
		return
	if enemies.size()==1:
		begin_encounter(str(enemies[0].id),enemies[0])
	elif room==5 and catacombs.summon_unlocked and catacombs.rematch_ready:
		_start_room5_rematch(enemies)


func _room5_visuals()->Array[Node3D]:
	if room5_visual_cache.size()==2 and is_instance_valid(room5_visual_cache[0]) and is_instance_valid(room5_visual_cache[1]):
		return room5_visual_cache
	room5_visual_cache.clear()
	for id in ["cat_r5_skeleton_a","cat_r5_skeleton_b"]:
		var v:=_find_enemy_visual(id)
		if v:
			room5_visual_cache.append(v)
	return room5_visual_cache

func _stage_room5_scene()->void:
	var visuals:=_room5_visuals()
	var focus:=Act0Layout.ROOM5_FOCUS_ANCHOR
	for v in visuals:
		v.visible=true
		v.scale=Vector3.ONE
		focus+=v.global_position
	if not visuals.is_empty():
		focus/=float(visuals.size()+1)
	shadow.global_position=Act0Layout.ROOM5_SHADOW_POSITION
	shadow.look_at(Vector3(focus.x,shadow.global_position.y,focus.z),Vector3.UP)
	for v in visuals:
		v.look_at(Vector3(shadow.global_position.x,v.global_position.y,shadow.global_position.z),Vector3.UP)
	camera_rig.enter_combat(shadow.global_position,focus)

func _set_room5_target_visual(index:int)->void:
	var visuals:=_room5_visuals()
	for i in range(visuals.size()):
		visuals[i].scale=Vector3.ONE*1.08 if i==index else Vector3.ONE

func _show_room5_visuals(value:bool)->void:
	for v in _room5_visuals():
		v.visible=value
		v.scale=Vector3.ONE

func _start_room5_solo_attempt(enemies:Array)->void:
	if room5_active:
		return
	if _room5_visuals().size()!=2:
		room5_hud.close()
		shadow.set_physics_process(true)
		_refresh_navigation()
		story_toast.show_message("Room 5 cannot stage safely. The encounter remains uncommitted.")
		push_error("Room 5 requires exactly two valid encounter visuals")
		return
	if not room5_combat.start(enemies,false,true):
		room5_active=false
		room5_solo_attempt=false
		room5_hud.close()
		camera_rig.exit_combat()
		shadow.set_physics_process(true)
		_refresh_navigation()
		story_toast.show_message("The Room 5 encounter could not start safely. Try again.")
		return
	room5_active=true
	room5_solo_attempt=true
	shadow.set_physics_process(false)
	_refresh_navigation()
	_stage_room5_scene()
	_set_room5_target_visual(0)
	room5_hud.open()

func _start_room5_rematch(enemies:Array) -> void:
	if room5_active:
		return
	if _room5_visuals().size()!=2:
		room5_hud.close()
		shadow.set_physics_process(true)
		_refresh_navigation()
		story_toast.show_message("Room 5 cannot stage safely. The rematch remains uncommitted.")
		push_error("Room 5 rematch requires exactly two valid encounter visuals")
		return
	if not room5_combat.start(enemies,true,false):
		room5_active=false
		room5_solo_attempt=false
		room5_hud.close()
		camera_rig.exit_combat()
		shadow.set_physics_process(true)
		_refresh_navigation()
		story_toast.show_message("The Room 5 rematch could not start safely. Try again.")
		return
	room5_active=true
	room5_solo_attempt=false
	shadow.set_physics_process(false)
	_refresh_navigation()
	_stage_room5_scene()
	_set_room5_target_visual(0)
	room5_hud.open()

func room5_select_target(index:int) -> void:
	if room5_active and not _ui_modal_open():
		room5_combat.select_target(index)
		_set_room5_target_visual(index)

func room5_action(skill:String) -> void:
	if room5_active and not _ui_modal_open():
		room5_combat.shadow_action(skill)

func _on_room5_finished() -> void:
	var before_state:=_build_save_state()
	room5_hud.close()
	room5_active=false
	room5_solo_attempt=false
	camera_rig.exit_combat()
	if not act0_flow.room_cleared(5):
		shadow.set_physics_process(true)
		_refresh_navigation()
		return
	for id in ["cat_r5_skeleton_a","cat_r5_skeleton_b"]:
		if id not in cleared_encounters:
			cleared_encounters.append(id)
	_show_room5_visuals(false)
	director.set_checkpoint("act0_complete")
	checkpoint_position=shadow.global_position
	shadow.set_physics_process(true)
	_refresh_navigation()
	if not _save_progress():
		_restore_runtime_snapshot(before_state)
		_show_room5_visuals(true)
		story_toast.show_message("The final seal cannot hold without a save. The rematch remains unresolved.")
		return
	if not act0_flow.commit_act0_completion_presentation():
		push_error("Committed Act 0 completion could not emit presentation")
	story_toast.show_message("The seal yields. The Cradle of Shadows is behind you.",4.2)

func _on_room5_solo_limit()->void:
	await get_tree().create_timer(0.70).timeout
	_resolve_room5_solo_limit()

func _resolve_room5_solo_limit()->void:
	var before_state:=_build_save_state()
	room5_hud.close()
	room5_active=false
	room5_solo_attempt=false
	camera_rig.exit_combat()
	_show_room5_visuals(true)
	if act0_flow.room5_first_contact():
		checkpoint_position=Act0Layout.ROOM5_RETURN_CHECKPOINT
		shadow.global_position=checkpoint_position
		shadow.velocity=Vector3.ZERO
		director.set_checkpoint("room5_return")
		shadow.set_physics_process(true)
		_refresh_navigation()
		if not _save_progress():
			_restore_runtime_snapshot(before_state)
			story_toast.show_message("The retreat could not be anchored. Room 5 remains uncommitted.")
			return
		if not act0_flow.commit_solo_limit_presentation():
			push_error("Committed Room 5 solo-limit could not emit presentation")
		story_toast.show_message("One shadow was not enough. Return to the Keeper.")
		return
	shadow.set_physics_process(true)
	_refresh_navigation()

func _on_room5_failed() -> void:
	if room5_solo_attempt:
		_resolve_room5_solo_limit()
		return
	room5_hud.close()
	room5_active=false
	camera_rig.exit_combat()
	_show_room5_visuals(true)
	shadow.global_position=checkpoint_position
	shadow.velocity=Vector3.ZERO
	shadow.set_physics_process(true)
	_refresh_navigation()
	if not _save_progress():
		story_toast.show_message("The defeat checkpoint could not be refreshed. Continue will use the previous committed checkpoint.")


func _on_covenant_weapon_requested(family:String)->void:
	if choose_covenant_weapon(family):
		var chosen:Dictionary=Act0Progression.WEAPONS.get(family,{})
		covenant_menu.close()
		story_toast.show_message("The Covenant remembers %s. Return to the Smith and bind it in Silver."%str(chosen.get("label",family)))


func _catacomb_room_for_encounter(id:String)->int:
	for room in range(1,5):
		var profiles:=CatacombEncounterPlan.enemies(room)
		if profiles.size()==1 and str(profiles[0].id)==id:return room
	return 0


func _on_companion_ready(_profile:Dictionary)->void:
	# This signal is emitted only after the story-handoff save commits.
	team.unlock_story_slot()
	_apply_threshold_visual_state()

func _restore_act0_position()->void:
	if act0.stage in [Act0Contract.STAGE_ROOM5_RETURN,Act0Contract.STAGE_ROOM5_REMATCH]:
		checkpoint_position=Act0Layout.ROOM5_RETURN_CHECKPOINT
	elif act0.stage==Act0Contract.STAGE_COMPLETE:
		return
	shadow.global_position=checkpoint_position
	shadow.velocity=Vector3.ZERO


func _apply_threshold_visual_state()->void:
	var door:=get_parent().get_node_or_null("Graybox/VisualGeometry/TempleDoor") as Node3D
	if door:
		door.visible=not act0.faded_sigil_activated
	for companion_visual in get_tree().get_nodes_in_group("story_companion_visual"):
		if companion_visual is Node3D:
			(companion_visual as Node3D).visible=catacombs.summon_unlocked

func _apply_equipment_state()->void:
	var family:=""
	if act0.first_forge_done:
		family=act0.weapon_family
	encounter.set_loadout(family)
	room5_combat.set_loadout(family)
	shadow_proxy.set_weapon_family(family)

func _on_mobile_direction(direction:Vector2)->void:
	if shadow.has_method("set_virtual_direction"):
		shadow.set_virtual_direction(direction)

func _ui_modal_open()->bool:
	return settings_menu.panel.visible or covenant_menu.panel.visible

func _refresh_navigation()->void:
	var enabled:=not _ui_modal_open() and not encounter.active and not room5_active
	settings_button.disabled=encounter.active or room5_active or covenant_menu.panel.visible
	if shadow.has_method("set_input_enabled"):
		shadow.set_input_enabled(enabled)
	mobile_controls.set_enabled(enabled)

func _on_combat_skill_requested(skill:String)->void:
	if _ui_modal_open():
		return
	encounter.shadow_action(skill)


func _apply_identity_state(state:Dictionary)->void:
	shadow_proxy.apply_identity(str(state.get("shadow_identity","male")))
