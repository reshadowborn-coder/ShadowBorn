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
var checkpoint_position := Vector3(0,0.9,8)
var active_enemy_visual: Node3D
var cleared_encounters: Array[String] = []
var performance_mode := "smooth60"
var act0 := Act0Progression.new()
var catacombs := CatacombProgression.new()
var team := TeamState.new()
var act0_flow := Act0Orchestrator.new()
@onready var room5_combat:MultiEnemyEncounter=$Room5Combat
@onready var room5_hud:MultiTargetHUD=$MultiTargetHUD
var room5_active := false

func _ready() -> void:
	add_to_group("chapter00_game")
	add_child(act0); add_child(catacombs); add_child(team); add_child(act0_flow)
	_restore_save()
	var persisted := SaveManager.load_state()
	act0_flow.setup(act0, catacombs, get_parent().get_node("SaveManager"))
	act0_flow.restore(persisted); team.restore(persisted)
	act0_flow.companion_ready.connect(func(_profile): team.unlock_story_slot())
	room5_combat.finished.connect(_on_room5_finished)
	room5_combat.failed.connect(_on_room5_failed)
	room5_combat.state_changed.connect(room5_hud.render)
	room5_hud.target_selected.connect(room5_select_target)
	room5_hud.skill_pressed.connect(room5_action)
	covenant_menu.weapon_requested.connect(_on_covenant_weapon_requested)
	encounter.reset_shadow()
	hud.skill_pressed.connect(encounter.shadow_action)
	encounter.encounter_started.connect(_on_started)
	encounter.combat_state_changed.connect(hud.render_state)
	encounter.combat_state_changed.connect(_on_combat_state)
	encounter.shadow_attack_presented.connect(presenter.play_shadow_attack)
	encounter.enemy_attack_presented.connect(presenter.play_enemy_attack)
	encounter.encounter_finished.connect(_on_finished)
	encounter.encounter_failed.connect(_on_failed)
	settings_button.pressed.connect(_open_settings)
	settings_menu.performance_mode_changed.connect(_on_performance_mode_changed)
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
	_apply_performance_mode()

func _apply_performance_mode() -> void:
	Engine.max_fps = 30 if performance_mode == "battery30" else 60

func _open_settings() -> void:
	settings_menu.open(performance_mode)

func _on_performance_mode_changed(mode: String) -> void:
	performance_mode = mode
	_apply_performance_mode()
	_save_progress()

func _save_progress() -> void:
	var state := SaveManager.load_state()
	state.merge({"version":SaveManager.SAVE_VERSION,"checkpoint":director.checkpoint,"route_index":director.route_index,"checkpoint_position":[checkpoint_position.x,checkpoint_position.y,checkpoint_position.z],"cleared_encounters":cleared_encounters,"performance_mode":performance_mode}, true)
	for k in act0.snapshot(): state[k]=act0.snapshot()[k]
	for k in catacombs.snapshot(): state[k]=catacombs.snapshot()[k]
	SaveManager.save_state(state)

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
	var center := enemy_visual.global_position
	shadow.global_position = center + Vector3(-2.8, 0.0, 1.1)
	enemy_visual.global_position = center + Vector3(2.4, 0.0, -0.6)
	shadow.look_at(Vector3(enemy_visual.global_position.x, shadow.global_position.y, enemy_visual.global_position.z), Vector3.UP)
	enemy_visual.look_at(Vector3(shadow.global_position.x, enemy_visual.global_position.y, shadow.global_position.z), Vector3.UP)

func _on_started(id: String) -> void: hud.show_combat(id)

func _on_combat_state(state: Dictionary) -> void:
	if not active_enemy_visual: return
	var e: Dictionary = state.get("enemy", {})
	var shield := active_enemy_visual.get_node_or_null("Shield") as Node3D
	if shield:
		var guarded := e.get("guard", false)
		shield.rotation_degrees.x = -18.0 if guarded else 8.0
		shield.position.z = -0.42 if guarded else -0.18

func _on_finished(id: String) -> void:
	presenter.play_enemy_death()
	await get_tree().create_timer(0.30).timeout
	hud.hide_combat()
	if active_enemy_visual: active_enemy_visual.visible = false
	active_enemy_visual = null; presenter.clear(); camera_rig.exit_combat(); shadow.set_physics_process(true)
	if id not in cleared_encounters: cleared_encounters.append(id)
	checkpoint_position = shadow.global_position
	director.set_checkpoint(id + "_cleared")
	director.advance()
	_save_progress()

func _on_failed(_id: String) -> void:
	hud.hide_combat(); active_enemy_visual = null; presenter.clear(); camera_rig.exit_combat(); encounter.reset_shadow()
	shadow.global_position = checkpoint_position; shadow.velocity = Vector3.ZERO; shadow.set_physics_process(true)

func play_world_reveal(id: String) -> void:
	if id != "temple" or encounter.active: return
	shadow.set_physics_process(false)
	camera_rig.enter_reveal(Vector3(0, 5.5, -70.0))
	await get_tree().create_timer(1.65).timeout
	camera_rig.exit_reveal()
	await get_tree().create_timer(0.35).timeout
	shadow.set_physics_process(true)


func enter_temple() -> void:
	if not is_encounter_cleared("shield_boss"): return
	act0.stage="temple_entry"; checkpoint_position=Vector3(0,0.9,-78); shadow.global_position=checkpoint_position
	director.set_checkpoint("temple_entry"); _save_progress()

func temple_interact(kind:String) -> void:
	match kind:
		"keeper":
			if act0.stage=="temple_entry": act0.join_covenant(); _save_progress()
			elif act0.stage=="room5_return": act0_flow.temple_story_handoff(); _save_progress()
		"covenant":
			if act0.covenant_joined and act0.weapon_family.is_empty(): covenant_menu.show()
		"smith":
			if act0.stage=="first_forge" and act0.commit_first_forge(): _save_progress()
		"catacombs":
			if act0_flow.enter_catacombs():
				checkpoint_position=Vector3(0,0.9,-117); shadow.global_position=checkpoint_position; _save_progress()

func choose_covenant_weapon(family:String) -> bool:
	var ok:=act0.choose_weapon(family)
	if ok:_save_progress()
	return ok

func enter_catacomb_room(room:int) -> void:
	if room!=catacombs.room:return
	if room==5 and not catacombs.summon_unlocked:
		if act0_flow.room5_first_contact():
			checkpoint_position=Vector3(0,0.9,-96); shadow.global_position=checkpoint_position
			director.set_checkpoint("room5_return"); _save_progress()
		return
	var enemies:=CatacombEncounterPlan.enemies(room)
	if enemies.size()==1: begin_encounter(str(enemies[0].id),enemies[0])
	elif room==5 and catacombs.summon_unlocked and catacombs.rematch_ready:
		_start_room5_rematch(enemies)


func _start_room5_rematch(enemies:Array) -> void:
	if room5_active:return
	room5_active=true
	shadow.set_physics_process(false)
	room5_hud.open()
	room5_combat.start(enemies,true)

func room5_select_target(index:int) -> void:
	if room5_active:room5_combat.select_target(index)

func room5_action(skill:String) -> void:
	if room5_active:room5_combat.shadow_action(skill)

func _on_room5_finished() -> void:
	room5_hud.close()
	room5_active=false
	act0_flow.room_cleared(5)
	director.set_checkpoint("act0_complete")
	checkpoint_position=shadow.global_position
	shadow.set_physics_process(true)
	_save_progress()

func _on_room5_failed() -> void:
	room5_hud.close()
	room5_active=false
	shadow.global_position=checkpoint_position
	shadow.velocity=Vector3.ZERO
	shadow.set_physics_process(true)
	_save_progress()


func _on_covenant_weapon_requested(family:String)->void:
	if choose_covenant_weapon(family):
		covenant_menu.hide()
