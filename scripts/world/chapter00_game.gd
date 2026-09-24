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

func _ready() -> void:
	add_to_group("chapter00_game")
	add_child(act0); add_child(catacombs); add_child(team); add_child(act0_flow)
	_restore_save()
	var persisted := SaveManager.load_state()
	act0_flow.setup(act0, catacombs, get_parent().get_node("SaveManager"))
	act0_flow.restore(persisted); team.restore(persisted)
	_apply_identity_state(persisted)
	_apply_equipment_state()
	_restore_act0_position()
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
	encounter.encounter_finished.connect(_on_finished)
	encounter.encounter_failed.connect(_on_failed)
	settings_button.pressed.connect(_open_settings)
	settings_menu.performance_mode_changed.connect(_on_performance_mode_changed)
	settings_menu.reduced_motion_changed.connect(_on_reduced_motion_changed)
	call_deferred("_apply_cleared_visuals")

func _restore_save() -> void:
	var state := SaveManager.load_state()
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
	settings_menu.open(performance_mode,reduced_motion)

func _on_performance_mode_changed(mode: String) -> void:
	performance_mode = mode
	_apply_performance_mode()
	_save_progress()

func _on_reduced_motion_changed(value:bool)->void:
	reduced_motion=value
	_apply_presentation_settings()
	_save_progress()

func _apply_presentation_settings()->void:
	camera_rig.set_reduced_motion(reduced_motion)
	presenter.set_reduced_motion(reduced_motion)

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
	return SaveManager.save_state(_build_save_state())

func _commit_first_forge_transaction()->bool:
	var candidate:=act0.first_forge_candidate()
	if candidate.is_empty():
		return false
	var state:=_build_save_state()
	state["silver"]=act0.silver-1
	state["forged_item"]=candidate.duplicate(true)
	state["first_forge_done"]=true
	state["act0_stage"]="catacombs"
	if not SaveManager.save_state(state):
		return false
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

func begin_encounter(id: String, profile: Dictionary) -> void:
	if is_encounter_cleared(id): return
	shadow.set_physics_process(false)
	active_enemy_visual = _find_enemy_visual(id)
	if active_enemy_visual:
		_position_combatants(active_enemy_visual)
		camera_rig.enter_combat(shadow.global_position, active_enemy_visual.global_position)
		presenter.bind_combatants(shadow, active_enemy_visual)
	encounter.start_encounter(id, profile)

func _find_enemy_visual(id: String) -> Node3D:
	for node in get_tree().get_nodes_in_group("encounter_visual"):
		if node.get_meta("encounter_id", "") == id: return node as Node3D
	return null

func _apply_cleared_visuals() -> void:
	for node in get_tree().get_nodes_in_group("encounter_visual"):
		if is_encounter_cleared(str(node.get_meta("encounter_id", ""))): node.visible = false

func _position_combatants(enemy_visual: Node3D) -> void:
	if not enemy_visual.has_meta("combat_home_position"):
		enemy_visual.set_meta("combat_home_position",enemy_visual.global_position)
	var center:Vector3=enemy_visual.get_meta("combat_home_position")
	shadow.global_position = center + Vector3(-2.8, 0.0, 1.1)
	enemy_visual.global_position = center + Vector3(2.4, 0.0, -0.6)
	shadow.look_at(Vector3(enemy_visual.global_position.x, shadow.global_position.y, enemy_visual.global_position.z), Vector3.UP)
	enemy_visual.look_at(Vector3(shadow.global_position.x, enemy_visual.global_position.y, shadow.global_position.z), Vector3.UP)

func _restore_enemy_visual_home()->void:
	if active_enemy_visual and active_enemy_visual.has_meta("combat_home_position"):
		active_enemy_visual.global_position=active_enemy_visual.get_meta("combat_home_position")

func _on_started(id: String) -> void:
	hud.show_combat(id)
	_refresh_navigation()

func _on_combat_state(state: Dictionary) -> void:
	if not active_enemy_visual: return
	var e: Dictionary = state.get("enemy", {})
	var shield := active_enemy_visual.get_node_or_null("Shield") as Node3D
	if shield:
		var guarded := e.get("guard", false)
		shield.rotation_degrees.x = -18.0 if guarded else 8.0
		shield.position.z = -0.42 if guarded else -0.18

func _on_finished(id: String) -> void:
	var first_clear := id not in cleared_encounters
	var cat_room := _catacomb_room_for_encounter(id)
	presenter.play_enemy_death()
	await get_tree().create_timer(0.30).timeout
	hud.hide_combat()
	if active_enemy_visual: active_enemy_visual.visible = false
	active_enemy_visual = null; presenter.clear(); camera_rig.exit_combat(); shadow.set_physics_process(true)
	_refresh_navigation()
	if first_clear:
		cleared_encounters.append(id)
		if id == "shield_boss":
			act0.silver += 1
			act0.stage = "temple_entry"
	checkpoint_position = shadow.global_position
	director.set_checkpoint(id + "_cleared")
	director.advance()
	if cat_room > 0: act0_flow.room_cleared(cat_room)
	_save_progress()

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

func play_world_reveal(id: String) -> void:
	if id != "temple" or encounter.active: return
	mobile_controls.set_enabled(false)
	shadow.set_physics_process(false)
	camera_rig.enter_reveal(Vector3(0, 5.5, -70.0))
	await get_tree().create_timer(0.45 if reduced_motion else 1.65).timeout
	camera_rig.exit_reveal()
	if not reduced_motion:
		await get_tree().create_timer(0.35).timeout
	shadow.set_physics_process(true)
	_refresh_navigation()


func enter_temple() -> void:
	if not is_encounter_cleared("shield_boss"): return
	if act0.stage not in ["exterior","temple_entry"]: return
	act0.stage="temple_entry"; checkpoint_position=Vector3(0,0.9,-78); shadow.global_position=checkpoint_position
	director.set_checkpoint("temple_entry"); _save_progress()

func temple_interact(kind:String) -> void:
	match kind:
		"keeper":
			if act0.stage=="temple_entry" and act0.join_covenant():
				story_toast.show_message("Keeper: The dead do not fear the dark. Only what wakes inside it. Bind your shape to the Forgotten Covenant.")
				_save_progress()
			elif act0.stage=="room5_return" and act0_flow.temple_story_handoff():
				story_toast.show_message("Keeper: One shadow has found its limit. Call the one who still answers beneath the stone.")
				_save_progress()
		"covenant":
			if act0.covenant_joined and act0.weapon_family.is_empty():
				covenant_menu.open()
			elif not act0.covenant_joined:
				story_toast.show_message("The Covenant stone is silent. The Keeper has not named you yet.")
		"smith":
			if act0.stage=="first_forge":
				if _commit_first_forge_transaction():
					story_toast.show_message("Smith: Silver remembers heat. Your chosen form has an edge now.")
			elif not act0.first_forge_done:
				story_toast.show_message("The forge waits for a Covenant weapon and one piece of Silver.")
		"merchant":
			story_toast.show_message("Merchant: The shelves are nearly bare. Trade opens after the first descent.")
		"engraver":
			story_toast.show_message("The engraver's stones are dormant. Runes will answer later.")
		"catacombs":
			if act0_flow.enter_catacombs():
				checkpoint_position=Vector3(0,0.9,-117)
				shadow.global_position=checkpoint_position
				story_toast.show_message("The lower passage opens. The air below carries old bone-dust.")
				_save_progress()
			else:
				story_toast.show_message("The passage does not answer an unbound, unforged shadow.")

func choose_covenant_weapon(family:String) -> bool:
	var ok:=act0.choose_weapon(family)
	if ok:_save_progress()
	return ok

func enter_catacomb_room(room:int) -> void:
	if catacombs.complete or act0.stage=="act0_complete":
		return
	if room!=catacombs.room:
		return
	var enemies:=CatacombEncounterPlan.enemies(room)
	if room==5 and not catacombs.summon_unlocked:
		if catacombs.room5_solo_limit_seen:
			checkpoint_position=Vector3(0,0.9,-96)
			shadow.global_position=checkpoint_position
			shadow.velocity=Vector3.ZERO
			director.set_checkpoint("room5_return")
			_save_progress()
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
	var focus:=Vector3(0,1.0,-175.5)
	for v in visuals:
		v.visible=true
		v.scale=Vector3.ONE
		focus+=v.global_position
	if not visuals.is_empty():
		focus/=float(visuals.size()+1)
	shadow.global_position=Vector3(0,0.9,-171.5)
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
	room5_active=true
	room5_solo_attempt=true
	shadow.set_physics_process(false)
	_refresh_navigation()
	_stage_room5_scene()
	_set_room5_target_visual(0)
	room5_hud.open()
	room5_combat.start(enemies,false,true)

func _start_room5_rematch(enemies:Array) -> void:
	if room5_active:
		return
	room5_active=true
	room5_solo_attempt=false
	shadow.set_physics_process(false)
	_refresh_navigation()
	_stage_room5_scene()
	_set_room5_target_visual(0)
	room5_hud.open()
	room5_combat.start(enemies,true,false)

func room5_select_target(index:int) -> void:
	if room5_active and not _ui_modal_open():
		room5_combat.select_target(index)
		_set_room5_target_visual(index)

func room5_action(skill:String) -> void:
	if room5_active and not _ui_modal_open():
		room5_combat.shadow_action(skill)

func _on_room5_finished() -> void:
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
	story_toast.show_message("The seal yields. The Cradle of Shadows is behind you.",4.2)
	shadow.set_physics_process(true)
	_refresh_navigation()
	_save_progress()

func _on_room5_solo_limit()->void:
	await get_tree().create_timer(0.70).timeout
	_resolve_room5_solo_limit()

func _resolve_room5_solo_limit()->void:
	room5_hud.close()
	room5_active=false
	room5_solo_attempt=false
	camera_rig.exit_combat()
	_show_room5_visuals(true)
	if act0_flow.room5_first_contact():
		checkpoint_position=Vector3(0,0.9,-96)
		shadow.global_position=checkpoint_position
		shadow.velocity=Vector3.ZERO
		director.set_checkpoint("room5_return")
		story_toast.show_message("One shadow was not enough. Return to the Keeper.")
	shadow.set_physics_process(true)
	_refresh_navigation()
	_save_progress()

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
	_save_progress()


func _on_covenant_weapon_requested(family:String)->void:
	if choose_covenant_weapon(family):
		covenant_menu.close()


func _catacomb_room_for_encounter(id:String)->int:
	for room in range(1,5):
		var profiles:=CatacombEncounterPlan.enemies(room)
		if profiles.size()==1 and str(profiles[0].id)==id:return room
	return 0


func _on_companion_ready(profile:Dictionary)->void:
	team.unlock_story_slot()
	story_toast.show_message("%s answers the call. A second formation slot is now active."%str(profile.get("name","A forgotten guardian")))
	# Keep the player in the Temple after the story handoff instead of
	# teleporting straight back to the Catacombs.
	checkpoint_position=shadow.global_position
	director.set_checkpoint("room5_rematch")

func _restore_act0_position()->void:
	if act0.stage=="room5_return":
		checkpoint_position=Vector3(0,0.9,-96)
	elif act0.stage=="act0_complete":
		return
	shadow.global_position=checkpoint_position


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
	if shadow.has_method("set_input_enabled"):
		shadow.set_input_enabled(enabled)
	mobile_controls.set_enabled(enabled)

func _on_combat_skill_requested(skill:String)->void:
	if _ui_modal_open():
		return
	encounter.shadow_action(skill)


func _apply_identity_state(state:Dictionary)->void:
	shadow_proxy.set_identity(str(state.get("shadow_identity","male")))
