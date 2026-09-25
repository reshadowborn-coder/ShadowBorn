class_name CombatFrameTrace
extends Node

signal row_completed(row: Dictionary)

var requested_fps := 60
var reduced_motion := false
var frame_index := 0
var frame_pre_us := 0
var _waiting_events: Array[Dictionary] = []
var _frame_events: Array[Dictionary] = []
var _last_state: Dictionary = {}
var _last_multi_state: Dictionary = {}
var _attached := false
var _multi_attached := false
var console_output := true

func set_console_output(value: bool) -> void:
	console_output = value

func _ready() -> void:
	if not RenderingServer.frame_pre_draw.is_connected(_on_frame_pre_draw):
		RenderingServer.frame_pre_draw.connect(_on_frame_pre_draw)
	if not RenderingServer.frame_post_draw.is_connected(_on_frame_post_draw):
		RenderingServer.frame_post_draw.connect(_on_frame_post_draw)

func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_on_frame_pre_draw):
		RenderingServer.frame_pre_draw.disconnect(_on_frame_pre_draw)
	if RenderingServer.frame_post_draw.is_connected(_on_frame_post_draw):
		RenderingServer.frame_post_draw.disconnect(_on_frame_post_draw)

func attach(controller: EncounterController, presenter: CombatPresenter, hud: CombatHUD) -> void:
	if _attached:
		return
	_attached = true
	controller.command_committed.connect(_on_command_committed)
	controller.shadow_attack_presented.connect(_on_shadow_attack_presented)
	controller.enemy_attack_presented.connect(_on_enemy_attack_presented)
	controller.enemy_beat_presented.connect(_on_enemy_beat_presented)
	controller.semantic_contact.connect(_on_semantic_contact)
	controller.combat_state_changed.connect(_on_combat_state_changed)
	presenter.impact_presented.connect(_on_impact_presented)
	hud.visual_state_updated.connect(_on_hud_updated)
	if console_output:
		print("SB_TRACE " + JSON.stringify({
			"event":"trace_capabilities",
			"ts_us":Time.get_ticks_usec(),
			"engine_frame":true,
			"hud":true,
			"vfx":true,
			"sfx":false,
			"actual_present":"external_surfaceflinger_or_perfetto"
		}))

func attach_multi(controller: MultiEnemyEncounter) -> void:
	if _multi_attached:
		return
	_multi_attached = true
	controller.command_committed.connect(_on_multi_command_committed)
	controller.shadow_attack_presented.connect(_on_multi_shadow_attack_presented)
	controller.enemy_attack_presented.connect(_on_multi_enemy_attack_presented)
	controller.companion_attack_presented.connect(_on_multi_companion_attack_presented)
	controller.semantic_contact.connect(_on_multi_semantic_contact)
	controller.state_changed.connect(_on_multi_state_changed)
	if console_output:
		print("SB_TRACE " + JSON.stringify({
			"event":"trace_capabilities_multi",
			"ts_us":Time.get_ticks_usec(),
			"multi_enemy":true,
			"target_index":true,
			"action_lock":true
		}))

func set_context(performance_mode: String, is_reduced_motion: bool) -> void:
	requested_fps = 30 if performance_mode == "battery30" else 60
	reduced_motion = is_reduced_motion
	_mark("trace_context", {
		"performance_mode":performance_mode,
		"requested_fps":requested_fps,
		"reduced_motion":reduced_motion
	})

func _mark(event_name: String, extra: Dictionary = {}) -> void:
	var row := {
		"event":event_name,
		"ts_us":Time.get_ticks_usec(),
		"requested_fps":requested_fps,
		"reduced_motion":reduced_motion
	}
	for key in extra:
		row[key] = extra[key]
	_waiting_events.append(row)

func _on_frame_pre_draw() -> void:
	frame_index += 1
	frame_pre_us = Time.get_ticks_usec()
	if not _waiting_events.is_empty():
		_frame_events.append_array(_waiting_events)
		_waiting_events.clear()
		for row in _frame_events:
			if not row.has("eligible_engine_frame"):
				row["eligible_engine_frame"] = frame_index
				row["frame_pre_draw_ts_us"] = frame_pre_us

func _on_frame_post_draw() -> void:
	if _frame_events.is_empty():
		return
	var post_us := Time.get_ticks_usec()
	for row in _frame_events:
		row["frame_post_draw_ts_us"] = post_us
		row["event_to_frame_pre_us"] = int(row["frame_pre_draw_ts_us"]) - int(row["ts_us"])
		var completed: Dictionary = row.duplicate(true)
		emit_signal("row_completed",completed)
		if console_output:
			print("SB_TRACE " + JSON.stringify(completed))
	_frame_events.clear()

func _on_command_committed(skill: String) -> void:
	_mark("command_committed", {"skill":skill})

func _on_shadow_attack_presented(skill: String, damage: float, guarded: bool) -> void:
	_mark("shadow_presentation_start", {"action":skill,"damage":damage,"guarded":guarded})

func _on_enemy_attack_presented(damage: float) -> void:
	_mark("enemy_presentation_start", {"action":"ATTACK","damage":damage})

func _on_enemy_beat_presented(action: String, damage: float) -> void:
	_mark("enemy_presentation_start", {"action":action,"damage":damage})

func _on_semantic_contact(actor: String, action: String) -> void:
	_mark("semantic_contact", {"actor":actor,"action":action})

func _on_impact_presented(target_side: String, guarded: bool) -> void:
	_mark("impact_vfx_created", {"target":target_side,"guarded":guarded})

func _on_hud_updated(player_hp_text: String, enemy_hp_text: String, state_text: String, action_locked: bool, a2_cd: int) -> void:
	_mark("hud_properties_updated", {
		"player_hp_text":player_hp_text,
		"enemy_hp_text":enemy_hp_text,
		"state_text":state_text,
		"action_locked":action_locked,
		"a2_cd":a2_cd
	})

func _on_multi_command_committed(skill:String)->void:
	_mark("multi_command_committed",{"skill":skill})

func _on_multi_shadow_attack_presented(target_index:int,skill:String,damage:float)->void:
	_mark("multi_shadow_presentation_start",{"target_index":target_index,"action":skill,"damage":damage})

func _on_multi_enemy_attack_presented(enemy_index:int,damage:float)->void:
	_mark("multi_enemy_presentation_start",{"enemy_index":enemy_index,"action":"ATTACK","damage":damage})

func _on_multi_companion_attack_presented(target_index:int,damage:float)->void:
	_mark("multi_companion_presentation_start",{"target_index":target_index,"action":"A1","damage":damage})

func _on_multi_semantic_contact(actor:String,index:int,action:String)->void:
	_mark("multi_semantic_contact",{"actor":actor,"index":index,"action":action})

func _on_multi_state_changed(state:Dictionary)->void:
	var current:=state.duplicate(true)
	if _last_multi_state.is_empty():
		_last_multi_state=current
		_mark("multi_state_initial",_multi_state_summary(current))
		return
	var before_summary:=_multi_state_summary(_last_multi_state)
	var after_summary:=_multi_state_summary(current)
	if before_summary!=after_summary:
		_mark("multi_state_projection",after_summary)
	if bool(_last_multi_state.get("action_locked",false)) and not bool(current.get("action_locked",false)):
		_mark("multi_recovery_unlock",after_summary)
	_last_multi_state=current

func _multi_state_summary(state:Dictionary)->Dictionary:
	var enemy_hps:Array[float]=[]
	for enemy_value in state.get("enemies",[]):
		var enemy:Dictionary=enemy_value
		enemy_hps.append(float(enemy.get("current_hp",enemy.get("hp",0.0))))
	return {
		"action_locked":bool(state.get("action_locked",false)),
		"shadow_hp":float(state.get("shadow_hp",0.0)),
		"enemy_hps":enemy_hps,
		"selected":int(state.get("selected",0)),
		"rounds":int(state.get("rounds",0)),
		"a2_cd":int(state.get("a2_cd",0)),
		"solo_limit_mode":bool(state.get("solo_limit_mode",false)),
		"limit_reached":bool(state.get("limit_reached",false)),
		"fray":bool(state.get("fray",false)),
		"veil":float(state.get("veil",0.0)),
		"phase":str(state.get("phase",""))
	}

func _on_combat_state_changed(state: Dictionary) -> void:
	var current := state.duplicate(true)
	if _last_state.is_empty():
		_last_state = current
		_mark("combat_state_initial", _state_summary(current))
		return

	var before_shadow: Dictionary = _last_state.get("shadow",{})
	var before_enemy: Dictionary = _last_state.get("enemy",{})
	var after_shadow: Dictionary = current.get("shadow",{})
	var after_enemy: Dictionary = current.get("enemy",{})
	var changed := (
		float(before_shadow.get("hp",0.0)) != float(after_shadow.get("hp",0.0))
		or float(before_enemy.get("hp",0.0)) != float(after_enemy.get("hp",0.0))
		or int(before_shadow.get("a2_cd",0)) != int(after_shadow.get("a2_cd",0))
		or bool(before_shadow.get("veil",0.0) > 0.0) != bool(after_shadow.get("veil",0.0) > 0.0)
		or bool(before_enemy.get("guard",false)) != bool(after_enemy.get("guard",false))
	)
	if changed:
		_mark("combat_state_projection", _state_summary(current))
	if bool(_last_state.get("action_locked",false)) and not bool(current.get("action_locked",false)):
		_mark("recovery_unlock", _state_summary(current))
	_last_state = current

func _state_summary(state: Dictionary) -> Dictionary:
	var shadow: Dictionary = state.get("shadow",{})
	var enemy: Dictionary = state.get("enemy",{})
	return {
		"encounter_id":str(state.get("encounter_id","")),
		"action_locked":bool(state.get("action_locked",false)),
		"shadow_hp":float(shadow.get("hp",0.0)),
		"enemy_hp":float(enemy.get("hp",0.0)),
		"a2_cd":int(shadow.get("a2_cd",0)),
		"veil":float(shadow.get("veil",0.0)),
		"fray":bool(shadow.get("fray",false)),
		"guard":bool(enemy.get("guard",false)),
		"intent":str(enemy.get("intent",""))
	}
