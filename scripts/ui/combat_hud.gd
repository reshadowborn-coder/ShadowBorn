class_name CombatHUD
extends CanvasLayer

signal skill_pressed(skill: String)
signal visual_state_updated(player_hp_text: String, enemy_hp_text: String, state_text: String, action_locked: bool, a2_cd: int)

@onready var panel: Control = $Panel
@onready var player_hp: Label = $Panel/PlayerHP
@onready var enemy_hp: Label = $Panel/EnemyHP
@onready var state_label: Label = $Panel/State
@onready var a1_button: Button = $Panel/A1
@onready var a2_button: Button = $Panel/A2

func _ready() -> void:
	$Panel/A1.pressed.connect(func(): skill_pressed.emit("A1"))
	$Panel/A2.pressed.connect(func(): skill_pressed.emit("A2"))
	panel.visible = false

func show_combat(id: String) -> void:
	panel.visible = true
	$Panel/Title.text = id.replace("_", " ").capitalize()

func hide_combat() -> void:
	panel.visible = false

func render_state(state: Dictionary) -> void:
	var s: Dictionary = state.get("shadow", {})
	var e: Dictionary = state.get("enemy", {})
	player_hp.text = "SHADOW  %.1f / %.1f" % [s.get("hp",0.0),s.get("max_hp",20.0)]
	enemy_hp.text = "ENEMY   %.1f / %.1f" % [maxf(e.get("hp",0.0),0.0),e.get("max_hp",0.0)]
	var loadout:Dictionary=state.get("loadout",{})
	var a1_name:=str(loadout.get("a1_name","Basic Attack"))
	var a2_name:=str(loadout.get("a2_name","Shadow Lunge"))
	var cd: int = s.get("a2_cd",0)
	var locked:=bool(state.get("action_locked",false))
	a1_button.disabled = locked
	a2_button.disabled = locked or cd > 0
	a1_button.text = "A1  "+a1_name.to_upper()
	a2_button.text = "A2  "+a2_name.to_upper() if cd <= 0 else "A2  %s  [CD %d]"%[a2_name.to_upper(),cd]
	var states: Array[String] = []
	if e.get("guard",false): states.append("GUARD")
	var intent := str(e.get("intent",""))
	if not intent.is_empty(): states.append(intent.to_upper())
	if s.get("veil",0.0) > 0.0: states.append("VEIL")
	if s.get("fray",false): states.append("FRAY")
	if int(s.get("poison_turns",0))>0:
		states.append("POISON %d"%int(s.get("poison_turns",0)))
	var timeline:Dictionary=state.get("turn_meter",{})
	if not timeline.is_empty():
		var actors:Dictionary=timeline.get("actors",{})
		var shadow_tm:Dictionary=actors.get("shadow",{})
		var enemy_tm:Dictionary=actors.get(str(state.get("encounter_id","")),{})
		var shadow_pct:=int(round(float(shadow_tm.get("gauge_bp",0))/100.0))
		var enemy_pct:=int(round(float(enemy_tm.get("gauge_bp",0))/100.0))
		states.append("TM %d%% / %d%%"%[shadow_pct,enemy_pct])
		var current:Dictionary=state.get("current_turn",{})
		if not current.is_empty():
			states.append("TURN "+str(current.get("actor_id","")).replace("_"," ").to_upper())
	state_label.text = "  •  ".join(states)
	emit_signal("visual_state_updated",player_hp.text,enemy_hp.text,state_label.text,locked,cd)
